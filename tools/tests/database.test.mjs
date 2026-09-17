import { PGlite } from "@electric-sql/pglite";
import fs from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

test("PostgreSQL : RLS, rôle propriétaire, historique immuable et conflits de révision", async () => {
  const db = new PGlite();
  try {
    await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
      create schema auth; create table auth.users(id uuid primary key);
      create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth to anon,authenticated,service_role; grant execute on function auth.uid() to authenticated;`);
    await db.exec(
      await fs.readFile(
        "supabase/migrations/202609170001_private_editor.sql",
        "utf8",
      ),
    );
    const owner = "11111111-1111-4111-8111-111111111111",
      other = "22222222-2222-4222-8222-222222222222",
      page = "33333333-3333-4333-8333-333333333333";
    await db.query("insert into auth.users values ($1),($2)", [owner, other]);
    await db.query(
      "insert into public.admin_members values ($1,'owner',true)",
      [owner],
    );
    await db.exec("begin");
    await db.query(
      "insert into public.pages(id,title,slug) values ($1,'Page conservée','page.html')",
      [page],
    );
    await db.query(
      "insert into public.page_revisions(page_id,revision,html) values ($1,1,$2)",
      [page, "<p>Texte العربية</p>"],
    );
    await db.exec("commit");
    await db.exec("set role anon");
    await assert.rejects(
      db.query("select * from public.pages"),
      /permission denied/,
    );
    await assert.rejects(
      db.query("insert into public.admin_members values ($1,'owner',true)", [
        other,
      ]),
      /permission denied/,
    );
    await db.exec("reset role; set role authenticated");
    await db.query("select set_config('request.jwt.claim.sub',$1,false)", [
      other,
    ]);
    assert.equal((await db.query("select * from public.pages")).rows.length, 0);
    await assert.rejects(
      db.query("select public.save_page_revision($1,$2,1,$3)", [
        other,
        page,
        "evil",
      ]),
      /permission denied/,
    );
    await db.query("select set_config('request.jwt.claim.sub',$1,false)", [
      owner,
    ]);
    assert.equal((await db.query("select * from public.pages")).rows.length, 1);
    await assert.rejects(
      db.query("update public.pages set title='bypass'"),
      /permission denied/,
    );
    await assert.rejects(
      db.query("select public.save_page_revision($1,$2,1,$3)", [
        owner,
        page,
        "bypass",
      ]),
      /permission denied/,
    );
    await db.exec("reset role; set role service_role");
    await assert.rejects(
      db.query("select public.save_page_revision($1,$2,1,$3)", [
        other,
        page,
        "bad",
      ]),
      /FORBIDDEN/,
    );
    assert.equal(
      (
        await db.query(
          "select public.save_page_revision($1,$2,1,$3) as revision",
          [owner, page, "<p>Modification choisie العربية</p>"],
        )
      ).rows[0].revision,
      2,
    );
    await assert.rejects(
      db.query("select public.save_page_revision($1,$2,1,$3)", [
        owner,
        page,
        "stale",
      ]),
      /REVISION_CONFLICT/,
    );
    await db.exec("reset role");
    assert.equal(
      (
        await db.query(
          "select html from public.page_revisions where revision=1",
        )
      ).rows[0].html,
      "<p>Texte العربية</p>",
    );
    assert.equal(
      (await db.query("select count(*)::int as n from public.audit_events"))
        .rows[0].n,
      1,
    );
    await assert.rejects(
      db.query("update public.page_revisions set html='changed'"),
      /IMMUTABLE_REVISION/,
    );
    await db.query(
      "update public.admin_members set active=false where user_id=$1",
      [owner],
    );
    await db.exec("set role service_role");
    await assert.rejects(
      db.query("select public.save_page_revision($1,$2,2,$3)", [
        owner,
        page,
        "revoked",
      ]),
      /FORBIDDEN/,
    );
  } finally {
    await db.close();
  }
});
