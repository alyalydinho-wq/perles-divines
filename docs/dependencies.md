# Versions vérifiées le 17 septembre 2026

| Composant | Version / preuve |
|---|---|
| Node / npm | 24.16.0 / 11.13.0 |
| Import HTML | Cheerio 1.1.2, iconv-lite 0.7.0, PostCSS 8.5.28, postcss-value-parser 4.2.0, srcset 5.0.2 |
| Tests navigateur | Playwright 1.63.0, Edge installé sur ce PC ; version dans `evidence/reader-browser.json` |
| Flutter / Dart | 3.47.2 / 3.13.2 ; tag `d3b14c876900e553bc736ca19295fc09e3853e8e` |
| just_audio / audio_service / audio_session | 0.10.6 / 0.18.19 / 0.2.4 |
| background_downloader | 9.6.2 |
| Drift / drift_flutter | 2.35.0 / 0.3.1 |
| WebView Flutter | 4.14.1 ; Android 4.14.1 / WKWebView 3.26.1 |
| Riverpod / go_router | 3.4.3 / 18.0.1 ; go_router résolu mais navigation structurée à intégrer au jalon catalogue |
| share_plus | 13.3.0 |
| Java | Temurin 17.0.20.1+1, archive vérifiée par SHA-256 officiel |
| Android | SDK cible/compilation 36, minimum 24 ; NDK 28.2.13676358 ; certains plugins demandent aussi la plateforme 35 |
| Gradle / AGP / Kotlin | 9.3.1 / 9.1.0 / 2.4.0, générés par Flutter stable |
| iOS | Cible minimale 15.0 ; Xcode absent, compilation et appareil non testés |

Les versions directes ont été interrogées via l'[API officielle pub.dev](https://pub.dev/) puis résolues ensemble par `flutter pub get`. Preuve détaillée : `evidence/pub-versions.json`. Dépendances transitives et empreintes : `apps/mobile/pubspec.lock`. Node : `package-lock.json`.

L'audit initial npm a détecté des vulnérabilités PostCSS dans 8.5.6. La version a été corrigée et verrouillée à 8.5.28 ; audit après installation : zéro vulnérabilité déclarée. Ce résultat ne vaut pas audit exhaustif de l'application.

Références vérifiées : [archive Flutter](https://docs.flutter.dev/install/archive), [audio_service](https://pub.dev/packages/audio_service), [background_downloader](https://pub.dev/packages/background_downloader), [outils Android](https://developer.android.com/studio), [Temurin](https://adoptium.net/temurin/releases/). Le code source des versions téléchargées a été consulté pour les API utilisées.

Administration résolue et compilée ensemble : Next.js 16.3.5, React/React DOM 19.3.0, TypeScript 7.0.2, `@supabase/ssr` 0.12.7 et `@supabase/supabase-js` 2.116.0. Validation : Ajv 8.20.0, parse5 8.0.1, music-metadata 11.15.0, ffmpeg-static 5.3.0. Tests PostgreSQL locaux : PGlite 0.5.8. Formatage : Prettier 3.9.7. Versions interrogées sur le registre npm et verrouillées dans le lockfile commun ; construction Next.js et 21 tests Node réussis. Audit npm final : zéro vulnérabilité déclarée (`evidence/npm-audit.json`). Le SDK R2 et les adaptateurs distants restent à intégrer et vérifier ; aucune compatibilité R2 réelle n'est annoncée.
