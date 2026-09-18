# Contexte de reprise

Travaille dans ce dépôt sans modifier le site source. Le produit cible est une application Flutter Android/iOS entièrement locale consacrée aux duʿā et ziyārāt.

Les textes arabes, traductions, translittérations, références et métadonnées audio sont préparés dans le dépôt, relus, puis embarqués. N'invente jamais un texte, un auteur, une traduction ou une référence à partir d'un nom de fichier. Conserve les outils d'import et d'inventaire nécessaires à la génération des assets.

Commence par lire `README.md`, `docs/specification.md`, `docs/progress.md` et les décisions. Utilise `apps/mobile/pubspec.yaml` pour toute dépendance Flutter. Après une modification, exécute les tests Node utiles, `flutter analyze` et `flutter test` depuis `apps/mobile`. Distingue toujours une preuve locale, un essai sur appareil et une livraison store.
