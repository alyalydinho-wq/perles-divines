# Perles Divines

Dépôt privé : [alyalydinho-wq/perles-divines](https://github.com/alyalydinho-wq/perles-divines). L'accès nécessite un compte GitHub autorisé.

Développement progressif Android et iOS selon [le cahier technique](docs/specification.md). Le site original est consulté en lecture seule. Aucune modification éditoriale automatique des textes religieux.

État et reprise : [docs/progress.md](docs/progress.md). Recette complète E01–E21 / T01–T38 : [docs/acceptance.md](docs/acceptance.md). Ce dépôt contient l'import initial, une preuve mobile, le socle privé d'édition et un worker de publication local. Le projet complet n'est pas terminé.

## Import et lecture locale

Node 24.16.0, npm 11.13.0 ; dépendances exactes dans `package-lock.json`.

```powershell
npm ci
npm run import:site
node tools/check-content.mjs
npm test
npm run preview
```

Ouvrir `http://127.0.0.1:4173`. L'import lit les hôtes `www.perlesdivines.fr` et `perlesdivines.fr` uniquement, avec deux requêtes simultanées, trois essais maximum, bornes de taille et rapports explicites. Chaque capture possède son répertoire. `--normalize` régénère uniquement les dérivés depuis les octets capturés, sans accès au site. `content/current-import.json` désigne la capture locale actuelle, jamais une publication publique.

Les gros fichiers bruts/normalisés et SDK sont exclus de Git ; les outils, inventaires et preuves sont conservés. Une nouvelle machine doit reproduire l'import avant de préparer les assets Flutter.

## Mobile Windows

SDK Flutter officiel 3.47.2 / Dart 3.13.2, installé localement dans `.tooling/flutter`. JDK Temurin 17, SDK Android 36 et NDK 28.2.13676358. Les résolutions exactes sont dans `apps/mobile/pubspec.lock` et `docs/evidence/`.

```powershell
git -c core.longpaths=true clone --depth 1 --branch 3.47.2 https://github.com/flutter/flutter.git .tooling/flutter
# Installer le JDK et le SDK uniquement après autorisation de leurs conditions.
.\tools\bootstrap-java.ps1
.\tools\bootstrap-android.ps1
node tools/prepare-fixtures.mjs
node tools/prepare-mobile-content.mjs
cd apps/mobile
..\..\tools\flutter.ps1 pub get
..\..\tools\flutter.ps1 pub run build_runner build
..\..\tools\flutter.ps1 analyze
..\..\tools\flutter.ps1 test
..\..\tools\flutter.ps1 build apk --debug --dart-define=PERLES_FIXTURES=true
```

`tools/flutter.ps1` utilise le nom court Windows du même dossier pour éviter une erreur connue des hooks Dart avec les espaces. Aucun SDK n'est installé globalement par ces scripts. Aucun abonnement ni store n'est nécessaire.

Le mode de test est activé explicitement par `PERLES_FIXTURES=true`. Les deux petits MP3 synthétiques sont versionnés ; la piste d'une heure, le doublon et le fichier invalide sont reproductibles avec FFmpeg. Le serveur local de fixtures est distinct du site et n'écoute que sur localhost.

Consulter [le protocole appareil](docs/device-test-protocol.md) pour l'APK et les transferts. Une compilation Android ne constitue aucune preuve de fonctionnement iOS.

## iOS

Les fichiers iOS, la session audio et le mode audio en arrière-plan sont préparés. Minimum provisoire iOS 15. Sur Mac avec Flutter 3.47.2 et Xcode compatible, générer les assets puis exécuter `flutter pub get` et `flutter build ios --no-codesign`. Vérifier les intégrations natives et dépendances sur ce Mac avant une archive signée. Un iPhone reste indispensable pour verrouillage, écouteurs, interruptions, export et transferts.

## Prochaines étapes

Le socle [d'administration](docs/administration.md) compile et refuse l'accès sans configuration. Le [worker local](docs/publication.md) valide et publie les fixtures versionnées ; il n'est pas encore raccordé au téléphone ni à R2. Ces deux guides précisent les commandes, preuves et limites.

L'[inventaire MP3 en lecture seule](docs/audio-inventory.md) est prêt ; le dossier réel est connu et le propriétaire y ajoutera ses fichiers plus tard. Aucun titre/auteur suggéré n'est publié automatiquement.

Après la preuve native : catalogue SQLite et synchronisation atomique, bibliothèque complète, administration Next.js privée avec Supabase/R2 et worker durable, vrai catalogue MP3, sauvegarde/restauration et distribution. Les accès services, MP3 et signatures seront nécessaires à leurs étapes respectives. Identifiant technique actuel de développement : `fr.perlesdivines.perles_divines`, à fixer avec les paramètres stores avant distribution signée.
