# Inventorier les fichiers audio sans les modifier

Le propriétaire a fourni `C:\Users\alyas\OneDrive\Bureau\Perlesdivines\audio`. Paramètre conservé localement dans `content/development/owner-source.json` (ignoré par Git). Ne pas redemander ce chemin ni rechercher ailleurs.

Lorsque le propriétaire annonce des fichiers, lancer depuis la racine :

```powershell
node tools/audio-inventory/cli.mjs --source "C:\Users\alyas\OneDrive\Bureau\Perlesdivines\audio"
node tools/prepare-embedded-audio.mjs
```

L'outil parcourt récursivement les MP3 et les fichiers audio MPEG-4/AAC (M4A/MP4 sans piste vidéo) en lecture seule, ignore les liens symboliques/jonctions, mesure taille/SHA-256/durée et extrait les tags textuels disponibles. Les tags sont des observations, pas des attributions éditoriales approuvées. Les titres de fichiers et dossiers apparaissent uniquement dans `suggestions`. Les champs éditoriaux auteur/titre restent vides et `editorialValidated` reste faux. Aucune description religieuse n'est produite. Un MP4 contenant de la vidéo est refusé.

Les pistes valides sont copiées dans `apps/mobile/assets/audio/` et listées dans `apps/mobile/assets/content/audio-catalog.json`. Une association n'est écrite dans `content/audio-associations.json` que lorsqu'un nom de fichier correspond de façon unique à un titre déjà présent dans le catalogue. Les autres pistes restent lisibles dans l'onglet Audios, sans texte inventé.

Résultats d'inventaire dans un nouveau sous-dossier de `artifacts/audio-inventory/` :

- `inventory.json` : chemins relatifs exacts, observations, erreurs et groupes de doublons binaires. Les doublons sont conservés ; rien n'est déplacé ou supprimé.
- `metadata-to-review.csv` : UTF-8 avec BOM, séparateur virgule, champs entre guillemets ; colonnes du cahier. Les titres issus des fichiers sont proposés pour relecture. Auteur, thème, collection et description restent à compléter. Les valeurs commençant par un caractère de formule sont précédées d'une apostrophe pour la consultation dans un tableur ; le JSON conserve les valeurs exactes. Ce CSV n'est pas importé automatiquement dans un catalogue publié.

Le processus de mesure est borné à 256 Mio et 30 secondes par fichier. L'inventaire inspecte chaque fichier avant son association au catalogue embarqué. Un fichier invalide ou modifié pendant la lecture est signalé, jamais déclaré prêt. Limites de sécurité indépendantes du nombre prévu : 100 000 fichiers, 500 000 entrées parcourues, 8 Gio par fichier.

Essai reproductible sans vrais contenus :

```powershell
node tools/prepare-fixtures.mjs
node tools/audio-inventory/cli.mjs --source content/fixtures --fixture
```

Résultat du 17/09/2026 : cinq fichiers, quatre mesurés (dont le doublon), un faux MP3 refusé, un groupe de doublons, 14 662 008 octets. Le test automatisé vérifie aussi l'empreinte source après lecture, les noms accentués et l'absence d'auteur inventé.

Le 22/09/2026, neuf fichiers audio AAC (conteneur M4A, extension `.m4a.mp4`, sans vidéo, 49 893 864 octets) ont été inventoriés puis embarqués. Cinq ont un titre de catalogue correspondant. Quatre restent dans l'onglet Audios sans texte inventé.
