# Contexte de reprise

Travaille dans ce dépôt sans modifier le site source. Le produit cible est une application Flutter Android/iOS consacrée aux duʿā et ziyārāt.

Les textes arabes, traductions, translittérations, références et métadonnées audio sont préparés dans le dépôt, relus, puis embarqués. Les fichiers audio publics sont servis depuis Cloudflare R2 et se téléchargent à la demande pour l’écoute hors ligne. N'invente jamais un texte, un auteur, une traduction ou une référence à partir d'un nom de fichier. Conserve les outils d'import, d'inventaire et de publication R2 nécessaires à la génération des assets. Les secrets R2 restent dans `.env.r2`.

Commence par lire `README.md`, `docs/specification.md`, `docs/progress.md` et les décisions. Utilise `apps/mobile/pubspec.yaml` pour toute dépendance Flutter. Après une modification, exécute les tests Node utiles, `flutter analyze` et `flutter test` depuis `apps/mobile`. Distingue toujours une preuve locale, un essai sur appareil et une livraison store.
