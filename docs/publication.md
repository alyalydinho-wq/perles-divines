# Publication versionnée — preuve locale

`packages/content-schema` définit le JSON Schema v1 et les types TypeScript du pointeur public et du manifeste. Le validateur JavaScript vérifie schéma, dates UTC, origines, empreintes, chemins immuables, doublons, références, cycles et retraits. Il accepte 1 000 pistes en test ; 500 n'est pas une limite codée. Limites de sécurité : 100 000 éléments par liste, 8 Gio par référence et 7 jours par durée. Les fixtures et domaines fictifs sont refusés en mode production.

## Exécuter la preuve

```powershell
node tools/prepare-fixtures.mjs
node tools/prepare-publication-demo.mjs
node services/publisher/worker.mjs --once
node tools/serve-publication.mjs
# Autre terminal :
node tools/check-local-publication.mjs
```

Sans `--once`, le worker traite les tâches successives jusqu'à son arrêt. SQLite conserve instantanés, clés d'idempotence, numéros croissants, états/essais et bail de publication dans `content/development/jobs.sqlite`. Ce répertoire est ignoré par Git. Les fichiers publiés restent dans son sous-répertoire `public` ; aucun accès au site existant, à Supabase ou R2.

Le worker contrôle taille et SHA-256 en flux, vérifie le type MPEG Layer 3 et la durée dans un processus mémoire limité (256 Mio / 30 s), puis exige le décodage complet par FFmpeg (120 s maximum). Un gros fichier réel dépassant ces limites doit produire une erreur visible et faire réévaluer les limites, sans publication partielle. Il n'attribue ni auteur ni description depuis les tags.

Les ressources et le manifeste sont écrits à des chemins immuables. `latest.json` est remplacé en dernier sous le verrou de publication. Une reprise après publication du pointeur réconcilie l'état de la tâche. Restaurer un ancien contenu signifie créer une nouvelle tâche/version, jamais diminuer le numéro public. Les écritures concurrentes identiques d'un objet sont idempotentes ; un contenu différent à la même clé est refusé.

Le serveur de démonstration écoute seulement `127.0.0.1:4175`. Il sert GET/HEAD, ETag/304, Range/206/416 et If-Range. Les objets ont un cache long ; `latest.json` doit être revalidé. Aucun accès aux fichiers SQLite et aucune mutation HTTP ne sont exposés.

## Périmètre prouvé et travail restant

Tests locaux : erreur avant le pointeur, exception injectée après son écriture, reprise après expiration forcée du bail, absence de régression, faux MP3, intégrité et téléchargements HTTP. Trois vrais MP3 **synthétiques** ont aussi été publiés sur disque puis relus via HTTP avec empreintes identiques : `evidence/local-publication.json`.

Ces essais ne sont pas des tests R2 ni un arrêt électrique du serveur. Le pilote SQLite/fichiers sert à éprouver le protocole ; la base de production reste Supabase/PostgreSQL et le stockage R2, conformément au cahier. Restent les adaptateurs de production, le déploiement durable/supervision, uploads signés/multipart, sauvegardes et restauration sur environnement vide.

Les paquets HTML ne sont pas encore validés/extraits : **le worker refuse donc actuellement tout manifeste contenant des pages**. Le validateur Dart et l'installation atomique de publications distantes dans le téléphone restent à réaliser. L'application Android d'essai lit l'édition initiale embarquée et n'utilise pas ce serveur de publication.

Prochaine unité de travail : fabriquer les paquets de pages avec inventaire interne et références locales, tester traversée de chemins/liens symboliques/bombes ZIP/ressources absentes, puis porter le contrat en Dart et connecter l'activation SQLite sans toucher aux données personnelles.
