# Édition initiale et outils locaux

La capture du 17 septembre 2026 comporte 114 pages et environ 21 Mio de pages/ressources normalisées. Ce poids permet d'embarquer une première édition dans l'APK d'essai, option explicitement permise par le cahier (§6). L'installation copie dans un répertoire privé temporaire, vérifie chaque taille/SHA-256 puis renomme le répertoire complet. Aucune disponibilité hors connexion n'est annoncée avant cette étape. Cette installation initiale ne remplace pas la future synchronisation versionnée depuis l'administration.

Flutter 3.47.2 / Dart 3.13.2 sont verrouillés sur le tag officiel, d'où le message `user-branch` de Flutter Doctor. Les dépendances résolues ensemble sont dans `apps/mobile/pubspec.lock`. Pas de changement d'architecture.

Sous Windows, le lancement des hooks Dart échoue lorsque le chemin du SDK contient des espaces. Le lanceur `tools/flutter.ps1` utilise le nom court Windows existant du même répertoire ; aucun déplacement du projet, changement de lecteur ou copie du SDK.

Versions minimales du prototype : Android API 24 (socle Flutter), iOS 15 (projet généré et intersection conservatrice des plugins). SDK compilation/cible Android 36. La compilation et la recette iOS ne sont pas exécutables sur ce PC Windows.

L'installation gratuite du SDK Android et l'acceptation de ses licences ont été explicitement autorisées par le propriétaire le 17 septembre 2026. Aucun compte store, abonnement, engagement de dépense ou publication n'a été créé.
