# Inventorier les MP3 sans les modifier

Le propriétaire a fourni `C:\Users\alyas\OneDrive\Bureau\Perlesdivines\audio`. Il indique qu'aucun MP3 n'y est encore présent et qu'il ajoutera les fichiers plus tard. Paramètre conservé localement dans `content/development/owner-source.json` (ignoré par Git). Ne pas redemander ce chemin ni rechercher ailleurs. Aucun vrai catalogue n'a été lu à ce stade.

Lorsque le propriétaire annoncera les fichiers disponibles, lancer depuis la racine :

```powershell
node tools/audio-inventory/cli.mjs --source "C:\Users\alyas\OneDrive\Bureau\Perlesdivines\audio"
```

L'outil parcourt récursivement les MP3 en lecture seule, ignore les liens symboliques/jonctions, mesure taille/SHA-256/durée et extrait les tags textuels disponibles. Les tags sont des observations, pas des attributions éditoriales approuvées. Les titres de fichiers et dossiers apparaissent uniquement dans `suggestions`. Les champs éditoriaux auteur/titre restent vides et `editorialValidated` reste faux. Aucune description religieuse n'est produite.

Résultats dans un nouveau sous-dossier de `artifacts/audio-inventory/` :

- `inventory.json` : chemins relatifs exacts, observations, erreurs et groupes de doublons binaires. Les doublons sont conservés ; rien n'est déplacé ou supprimé.
- `metadata-to-review.csv` : UTF-8 avec BOM, séparateur virgule, champs entre guillemets ; colonnes du cahier. Les titres issus des fichiers sont proposés pour relecture. Auteur, thème, collection et description restent à compléter. Les valeurs commençant par un caractère de formule sont précédées d'une apostrophe pour la consultation dans un tableur ; le JSON conserve les valeurs exactes. Ce CSV n'est pas importé automatiquement dans un catalogue publié.

Le processus de mesure est borné à 256 Mio et 30 secondes par fichier. L'inventaire ne décode pas chaque MP3 intégralement ; le worker effectue ce contrôle avant publication. Un fichier invalide ou modifié pendant la lecture est signalé, jamais déclaré prêt. Limites de sécurité indépendantes du nombre prévu : 100 000 MP3, 500 000 entrées parcourues, 8 Gio par fichier.

Essai reproductible sans vrais contenus :

```powershell
node tools/prepare-fixtures.mjs
node tools/audio-inventory/cli.mjs --source content/fixtures --fixture
```

Résultat du 17/09/2026 : cinq fichiers, quatre mesurés (dont le doublon), un faux MP3 refusé, un groupe de doublons, 14 662 008 octets. Le test automatisé vérifie aussi l'empreinte source après lecture, les noms accentués et l'absence d'auteur inventé. Ce résultat ne décrit pas les fichiers du propriétaire.
