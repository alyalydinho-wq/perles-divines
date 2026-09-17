# Suivi — Perles Divines

## Session du 17 septembre 2026

### Sauvegarde GitHub

Le dépôt [alyalydinho-wq/perles-divines](https://github.com/alyalydinho-wq/perles-divines), créé initialement en privé, a été rendu public à la demande explicite du propriétaire. Sa visibilité publique et son accès sans authentification ont été vérifiés via l'API GitHub. Premier commit local : `6fe3d77`, 208 fichiers source/documentation/fixtures courtes examinés (environ 3,2 Mo). La branche initiale existante `master` est conservée. SDK, builds, paramètres locaux, captures brutes et gros médias restent exclus ; les commandes de reconstruction figurent dans le README. Cette sauvegarde du code ne constitue aucune publication de l'application sur un store.

- Cahier technique intégral lu, copié sans changement dans `specification.md`.
- Dépôt initial vide, aucune consigne AGENTS.md trouvée dans le projet ou ses parents.
- Audit initial : Windows, Node 24.16.0 ; aucun Flutter, Android SDK, Java ou Xcode détecté. Les outils Android ont depuis été installés dans le projet.
- Lecture HTTPS du site confirmée. Encodage ISO-8859-1 déclaré ; scripts de statistiques hérités à retirer du rendu local.
- Architecture du cahier conservée. Aucun abonnement, compte ou déploiement créé.

## Réalisé et vérifié

- Import GET reproductible : 617 URL, 114 pages, 21 Mio environ ; 615 fichiers locaux avec la page explicite d'indisponibilité. Aucun lien vers une ressource interne manquante après correction de la classification SVG.
- `robots.txt` et `sitemap.xml` renvoient 404. Cinq ancres manquent déjà dans les pages sources : inventoriées, leurs destinations locales affichent une explication. Aucun texte religieux modifié.
- Contrôle automatique : 114 textes visibles identiques, 888 occurrences d'images conservées et 617 empreintes brutes vérifiées. Six tests de l'importeur réussis.
- Navigateur Edge avec destinations Internet bloquées : 24 contrôles sur huit pages à 320/390/430 pixels, sans image manquante, script hérité ni débordement général. Comparaison visuelle de cinq pages sources et copies locales ; page à tableau également contrôlée localement. Captures dans `docs/evidence/`.
- Flutter 3.47.2 / Dart 3.13.2, JDK 17, SDK Android 36, NDK et CMake installés. Licences Android autorisées explicitement par le propriétaire.
- Application Flutter Android/iOS : installation atomique de l'édition initiale embarquée, WebView locale sans JavaScript éditorial, lecteur/service audio unique, commandes système, file, positions SQLite, vitesse, minuterie, favoris ; prototype de téléchargements natifs avec fichiers temporaires, contrôle SHA-256 et export système.
- Cinq tests Flutter réussis : positions/nom d'export, persistance réelle SQLite, rollback et refus de médias incomplets/corrompus. Ce sont des tests locaux Windows, pas des essais audio sur téléphone.
- Serveur de fixtures local : HEAD/206/416/If-Range vérifiés ; assemblage après reprise identique à la piste synthétique d'une heure. Cela ne valide pas encore le plugin en interruption réelle ni R2/CDN.
- Analyse Flutter finale : aucune anomalie. APK debug reconstruit avec les dernières corrections et livré dans `artifacts/Perles-Divines-0.1.0-essai.apk` (223 746 260 octets). SHA-256 dans `evidence/android-artifact.json`. L'erreur temporaire de quota d'autorisation a été dépassée ; elle ne bloque plus cette session.
- Contrat JSON Schema v1 et types TypeScript, origines/versions/références contrôlées, test de 1 000 pistes. Validateur Dart encore absent.
- Worker local durable SQLite : instantanés, bail, idempotence, versions immuables et pointeur publié en dernier. Tests d'échec avant/après pointeur et de restauration sous nouveau numéro. Type/durée et décodage réel MP3 contrôlés. Trois fixtures publiées puis relues via HTTP avec SHA-256 identiques (`evidence/local-publication.json`).
- Administration Next.js compilée en production, TypeScript vérifié : connexion Supabase, contrôle propriétaire, édition de fragments en brouillons/révisions, aperçu protégé, refus de conflits. Migration SQL/RLS et fichier d'initialisation de 114 pages prêts. Aucun service distant configuré, aucun e-mail envoyé.
- 21 tests Node réussis : import, inventaire audio, éditeur, PostgreSQL local PGlite, contrôles d'accès, contrats, publication et HTTP. Huit contrôles navigateur de l'état non configuré et sept refus sur les routes réelles sans session réussis. Erreur CSP de l'écran de récupération corrigée puis testée. Audit npm : zéro vulnérabilité déclarée.
- Outil d'inventaire audio prêt et testé en lecture seule : taille/SHA/durée/tags observés, doublons conservés, faux MP3 signalés, auteurs/descriptions non inventés. Exécution sur cinq fixtures : quatre médias mesurés, un invalide, un groupe de doublons. Le propriétaire a fourni `C:\Users\alyas\OneDrive\Bureau\Perlesdivines\audio` et précisera quand il y aura ajouté ses MP3. Paramètre conservé dans `content/development/owner-source.json` ; aucun import automatique.

## Prochaine action concrète

Fabriquer et valider les paquets HTML par révision, avec inventaires et liens internes, puis implémenter le même contrat en Dart et l'installation atomique du catalogue/pages dans SQLite. Le worker refuse encore les manifestes contenant des pages, plutôt que publier des paquets non contrôlés. Les audios de test sont publiés localement mais la synchronisation mobile n'est pas encore raccordée.

Commandes et limites : `administration.md`, `publication.md`, `device-test-protocol.md`. Les sources brutes, SDK, base locale et livrables volumineux sont exclus de Git et restent sur ce PC ; les scripts permettent leur reconstruction. Aucune modification du site d'origine.

## Limites et reprise

- Le propriétaire fera les essais avec l'APK plus tard ; aucun Android physique ni émulateur testé pour l'instant. Suivre `device-test-protocol.md` et renseigner `acceptance.md`.
- Pas de Mac/Xcode ni d'iPhone : iOS préparé, ni compilé ni validé.
- Aucun vrai MP3 inventorié ; trois fixtures synthétiques, un doublon et un fichier invalide explicitement identifiés. Le dossier réel est fourni mais encore sans MP3 d'après le propriétaire, qui les ajoutera plus tard. Ne pas redemander son chemin. Lancer l'inventaire décrit dans `audio-inventory.md` lorsqu'il annoncera les fichiers disponibles, puis présenter les incertitudes éditoriales.
- Restent côté mobile : catalogue SQLite/recherche accentuée/filtres, listes personnelles, gestion fine des lots/suppressions/espace, minuterie personnalisée, positions de lecture des pages et synchronisation versionnée. Les fonctions natives déjà codées attendent la recette sur appareil.
- Restent côté administration : import MP3 multipart, classement, édition complète images/liens, historique restaurable depuis l'interface, récapitulatif/publication, adaptateurs Supabase/R2, sauvegardes/restauration et raccord application. Les tests SQL PGlite et routes sans session ne remplacent pas un parcours propriétaire sur Supabase réel.
- Paramètres nécessaires plus tard : fichiers MP3 dans le dossier déjà fourni et métadonnées à compléter ; URL/clés des services et adresse du compte privé ; accès Mac/Xcode et testeur iPhone ; identité technique définitive/signatures et comptes stores. Ne pas redemander les droits ni la licence SDK déjà autorisés.
- Services et comptes stores non configurés ; aucune dépense, abonnement ou publication distante/store. Le projet complet Android/iOS n'est pas terminé.
