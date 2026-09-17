# Administration privée — état intermédiaire

Le code Next.js propose connexion, déconnexion, récupération d'accès et édition des textes en brouillon. Les routes vérifient la session Supabase avec `getUser`, puis l'appartenance active au rôle `owner`. Le navigateur ne reçoit aucune clé privilégiée. Sans paramètres, toutes les lectures/mutations privées restent fermées.

## Préparation locale

Depuis la racine, après `npm ci` et l'import initial :

```powershell
node tools/prepare-admin-seed.mjs
$env:NEXT_TELEMETRY_DISABLED='1'
npm run build --workspace=@perles/admin
npm run start --workspace=@perles/admin
```

L'interface écoute uniquement `http://127.0.0.1:4176`. Sans services configurés, elle indique que l'espace privé doit être préparé ; il n'existe aucun contournement d'authentification de développement.

`artifacts/admin-initial-content.sql` contient les 114 pages normalisées de la capture. Le générateur écrit uniquement un fichier local. Les insertions n'écrasent ni une page ni une révision existante. Le HTML canonique importé et les ressources sont conservés séparément des captures sources.

## Quand les paramètres Supabase seront fournis

1. Préparer un environnement distinct du site existant. Aucune offre ni compte n'a été créé pendant cette session.
2. Appliquer `supabase/migrations/202609170001_private_editor.sql`, puis le fichier d'initialisation préparé. Cette migration couvre les textes et l'accès privé ; le modèle complet des audios/publications reste à ajouter.
3. Désactiver l'inscription publique dans Supabase Auth. Créer/inviter le compte du propriétaire depuis l'administration privilégiée du service, puis insérer son **véritable UUID Auth** dans `admin_members`, avec `role='owner'` et `active=true`. Les clients ordinaires ne peuvent pas s'attribuer ce rôle.
4. Copier `apps/admin/.env.example` vers `.env.local` et fournir les paramètres. `ADMIN_ORIGIN` est l'origine exacte autorisée ; HTTPS pour toute origine non locale. La clé `SUPABASE_SERVICE_ROLE_KEY` reste uniquement dans le serveur/coffre de déploiement.
5. Monter le répertoire `normalized` de la capture en lecture seule et renseigner son chemin absolu dans `ADMIN_CONTENT_ROOT`. Les previews utilisent seulement ses images/CSS/polices ; aucun fichier HTML arbitraire n'est servi par cette route.
6. Autoriser l'URL de retour `<ADMIN_ORIGIN>/auth/callback` dans Supabase et vérifier l'envoi des liens de récupération, leurs expirations et les limites de tentatives. Aucun e-mail réel n'a été envoyé pendant les essais.
7. Refaire T33 avec un compte propriétaire, un compte authentifié sans rôle et aucune session, contre le service réel. Refaire le parcours navigateur de connexion/récupération et les écritures simultanées.

Les mécanismes de cookies SSR suivent la [documentation Supabase](https://supabase.com/docs/guides/auth/server-side/creating-a-client?queryGroups=framework&framework=nextjs). Les politiques suivent le [modèle RLS](https://supabase.com/docs/guides/database/postgres/row-level-security). L'administration utilise une [CSP avec nonce Next.js](https://nextjs.org/docs/app/guides/content-security-policy) et des pages dynamiques, sans cache de session partagé.

## Éditer les textes

Choisir une page, puis un passage. L'éditeur remplace uniquement le texte de ce fragment dans le HTML d'origine. Le texte saisi est échappé ; écrire une balise la montre comme texte et ne crée pas un script. Les attributs, tableaux, images, blocs conservés et autres fragments restent intacts. Aucune transcription arabe ni correction religieuse automatique n'est produite.

« Enregistrer en brouillon » crée une nouvelle révision immuable et un événement d'administration. Un onglet périmé reçoit un conflit : la saisie reste affichée pour être copiée/reprise. Ce bouton **ne publie pas**. L'aperçu correspond au brouillon enregistré.

Limites : l'édition actuelle porte sur les nœuds texte. L'édition visuelle d'images/liens, le classement, la restauration via interface, l'import multipart MP3, le récapitulatif de publication et le raccord au worker restent à réaliser. Le propriétaire n'a pas encore exécuté un ajout audio ou une modification de texte sur une administration configurée.

## Preuves disponibles

- Compilation production Next.js + vérification TypeScript réussies : `evidence/admin-build.txt`.
- Tests PostgreSQL via PGlite 0.5.8 : RLS, rôle actif, absence d'auto-attribution, révision immuable, verrou/conflit et audit. L'API Auth Supabase n'est pas intégrée à ce test ; `auth.uid()` et les rôles y sont préparés explicitement.
- Tests de modification en mémoire sur toutes les pages importées : conservation des autres textes et de toutes les balises ; aucune écriture dans les textes sources.
- Huit contrôles navigateur de l'état **non configuré**, à 390/1280 pixels : refus d'accès et formulaire fonctionnel sans erreur CSP. `evidence/admin-browser.json` et captures associées. Ces captures ne valident pas le parcours administrateur authentifié.
- Sept contrôles sur les routes Next réelles, avec configuration fictive et aucune session : lectures/écritures privées répondent 401, mutation inter-origines répond 403. `evidence/admin-unauthorized.json`. Aucun fournisseur Auth réel n'est contacté dans ce test.
