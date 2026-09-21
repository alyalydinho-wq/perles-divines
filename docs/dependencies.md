# Dépendances

## Node

Le `package-lock.json` racine verrouille uniquement les outils d'import, de prévisualisation et d'inventaire : parsing HTML/CSS, Playwright, FFmpeg, inspection audio, formatage et validation des scripts. Le dépôt ne contient aucun workspace applicatif JavaScript.

Installation reproductible : `npm ci`. Audit : `npm audit`.

## Flutter

`apps/mobile/pubspec.yaml` est la source unique des dépendances de l'application. Il couvre l'interface Flutter, la lecture audio, le stockage SQLite local, les tâches de transfert, l'intégrité SHA-256, la WebView locale, le partage et l'ouverture de liens. `apps/mobile/pubspec.lock` verrouille les résolutions.

Commandes :

```sh
cd apps/mobile
flutter pub get
flutter pub outdated
flutter analyze
flutter test
```

Les projets Android/iOS ne doivent pas déclarer de bibliothèque fonctionnelle contournant ce manifeste, hors plugins Flutter générés et composants natifs indispensables à leur exécution.
