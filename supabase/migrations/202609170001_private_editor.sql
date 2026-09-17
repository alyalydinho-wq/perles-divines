begin;
create schema if not exists private;
revoke all on schema private from public;

create table public.admin_members (
  user_id uuid primary key references auth.users(id),
  role text not null check (role = 'owner'),
  active boolean not null default true
);
alter table public.admin_members enable row level security;
revoke all on public.admin_members from public,anon,authenticated;
grant select on public.admin_members to authenticated;
create policy member_self on public.admin_members for select to authenticated using (user_id = (select auth.uid()));

create function private.is_admin(actor uuid) returns boolean language sql stable security definer
set search_path = '' as $$
 select exists(select 1 from public.admin_members where user_id=actor and active and role='owner');
$$;
revoke all on function private.is_admin(uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.is_admin(uuid) to authenticated;

create table public.pages (
  id uuid primary key,
  title text not null check (length(btrim(title)) between 1 and 500),
  source_url text,
  slug text unique not null,
  current_revision integer not null default 1 check(current_revision>0),
  updated_at timestamptz not null default now()
);
create table public.page_revisions (
  page_id uuid not null references public.pages(id),
  revision integer not null check(revision>0),
  html text not null check(octet_length(html)<=5242880),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  primary key(page_id,revision)
);
alter table public.pages add constraint current_revision_exists
 foreign key(id,current_revision) references public.page_revisions(page_id,revision)
 deferrable initially deferred;

create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id),
  action text not null,
  entity_id uuid,
  revision integer,
  created_at timestamptz not null default now()
);

alter table public.pages enable row level security;
alter table public.page_revisions enable row level security;
alter table public.audit_events enable row level security;
revoke all on public.pages,public.page_revisions,public.audit_events from public,anon,authenticated;
grant select on public.pages,public.page_revisions,public.audit_events to authenticated;
create policy pages_admin_read on public.pages for select to authenticated using ((select private.is_admin(auth.uid())));
create policy revisions_admin_read on public.page_revisions for select to authenticated using ((select private.is_admin(auth.uid())));
create policy audit_admin_read on public.audit_events for select to authenticated using ((select private.is_admin(auth.uid())));

-- No ordinary client may insert/update/delete a draft or change membership directly.
-- The Next server revalidates the session/role and constructs the escaped fragment.
create function public.save_page_revision(actor uuid, target uuid, expected_revision integer, new_html text)
returns integer language plpgsql security definer set search_path = '' as $$
declare current_value integer; next_value integer;
begin
 if not private.is_admin(actor) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select current_revision into current_value from public.pages where id=target for update;
 if not found then raise exception 'NOT_FOUND'; end if;
 if current_value<>expected_revision then raise exception 'REVISION_CONFLICT' using errcode='40001'; end if;
 if new_html is null or octet_length(new_html)>5242880 then raise exception 'INVALID_DOCUMENT'; end if;
 next_value:=current_value+1;
 insert into public.page_revisions(page_id,revision,html,created_by) values(target,next_value,new_html,actor);
 update public.pages set current_revision=next_value,updated_at=now() where id=target;
 insert into public.audit_events(actor_id,action,entity_id,revision) values(actor,'page.draft.saved',target,next_value);
 return next_value;
end; $$;
revoke all on function public.save_page_revision(uuid,uuid,integer,text) from public,anon,authenticated;
grant execute on function public.save_page_revision(uuid,uuid,integer,text) to service_role;

-- Even privileged routines cannot rewrite history accidentally.
create function private.immutable_revision() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'IMMUTABLE_REVISION'; end; $$;
create trigger revisions_immutable before update or delete on public.page_revisions
for each row execute function private.immutable_revision();
commit;
