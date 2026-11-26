# Perles Divines

Application Flutter Android/iOS de consultation hors connexion de duʿā et ziyārāt.

## Architecture retenue

Le produit distribue **un catalogue embarqué**. Les textes arabes, traductions, translittérations, références et associations audio sont relus et préparés directement dans ce dépôt, puis inclus dans les assets Flutter. Les fichiers audio publics sont hébergés sur Cloudflare R2 et se téléchargent à la demande pour l’écoute hors ligne. Il n'existe ni interface privée, ni service éditorial, ni mise à jour distante du catalogue texte.

- `apps/mobile/` : application et source unique de ses dépendances (`pubspec.yaml`).
- `content/` et `tools/import-site/` : sources et import reproductible du contenu.
- `tools/audio-inventory/` : inventaire local, empreintes et inspection des MP3.
- `tools/prepare-mobile-content.mjs` : génération de l'édition embarquée.

## Développement

```sh
npm ci
npm test
node tools/extract-devotional-catalog.mjs
node tools/prepare-mobile-pages.mjs
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

Les assets générés doivent être contrôlés avant compilation. Une modification du catalogue nécessite une nouvelle version de l'application.

Les pages d'origine du site (textes dont l'arabe n'existe qu'en images) s'affichent en natif, sans WebView. `node tools/prepare-mobile-pages.mjs` les prépare depuis l'import du site, sans toucher au catalogue : il écarte les pages que l'application ne peut pas ouvrir (`tools/prune-mobile-site.mjs`), puis les convertit en blocs (`assets/content/pages.json`) et en images (`assets/pages/`, hors Git, à régénérer après un clonage). Le relancer après qu'une lecture native a remplacé une ancienne page.

`tools/prepare-mobile-content.mjs` régénère aussi `catalog.json` depuis l'import brut : il écrase les retouches faites depuis dans le catalogue.

## Compiler pour un téléphone

```sh
cd apps/mobile
flutter build apk --release --target-platform=android-arm,android-arm64
```

Un seul fichier, `app-release.apk` (environ 46 Mo), pour tous les téléphones Android à partir d'Android 7.0 (API 24) : il contient l'ARM 32 et 64 bits. Le x86_64 n'est pas inclus (22 Mo de plus) : il ne sert qu'aux émulateurs, et un Chromebook lit la version ARM. Pour l'émulateur, compiler à part avec `--target-platform=android-x64`. Certains téléphones récents d'entrée de gamme (Samsung Galaxy A13 par exemple) tournent sous un Android 32 bits malgré Android 14 et refusent un APK 64 bits seul comme « pas compatible ».

Ne plus compiler avec `--split-per-abi`. Les APK séparés ajoutent 1000 ou 2000 au numéro de version interne : la 0.2.30 séparée valait 2032. Le numéro dans `pubspec.yaml` est donc reparti de 2033 avec la 0.2.31, pour que l'APK unique remplace les anciennes versions sans désinstaller. Il doit toujours augmenter d'une version à l'autre.
