# Perles Divines

Application Flutter Android/iOS de consultation hors connexion de duʿā et ziyārāt.

## Architecture retenue

Le produit distribue **un catalogue embarqué**. Les textes arabes, traductions, translittérations, références et associations audio sont relus et préparés directement dans ce dépôt, puis inclus dans les assets Flutter. Il n'existe ni interface privée, ni service éditorial, ni mise à jour distante du catalogue.

- `apps/mobile/` : application et source unique de ses dépendances (`pubspec.yaml`).
- `content/` et `tools/import-site/` : sources et import reproductible du contenu.
- `tools/audio-inventory/` : inventaire local, empreintes et inspection des MP3.
- `tools/prepare-mobile-content.mjs` : génération de l'édition embarquée.

## Développement

```sh
npm ci
npm test
node tools/extract-devotional-catalog.mjs
node tools/prepare-mobile-content.mjs
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

Les assets générés doivent être contrôlés avant compilation. Une modification du catalogue nécessite une nouvelle version de l'application.
