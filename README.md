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
flutter build apk --release --split-per-abi
```

Installer `app-arm64-v8a-release.apk` sur les téléphones récents et `app-armeabi-v7a-release.apk` sur les anciens. `app-x86_64-release.apk` ne sert qu'aux émulateurs.
