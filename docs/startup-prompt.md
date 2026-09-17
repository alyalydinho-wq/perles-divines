# Consigne de démarrage — Perles Divines

Copier ce texte dans l’IA de développement après avoir ajouté `PERLES_DIVINES_CAHIER_TECHNIQUE_IA.md` au projet. Ce prompt est indépendant de l’éditeur : il convient à Codex, Cursor ou un autre agent capable de travailler sur le dépôt.

---

Tu es chargé de développer Perles Divines pour Android et iOS. Lis intégralement le fichier `PERLES_DIVINES_CAHIER_TECHNIQUE_IA.md` joint au projet, ainsi que les instructions locales applicables. Ce cahier technique est la référence du projet ; n’ignore pas ses critères d’acceptation.

Le propriétaire a déjà confirmé ses droits et ses accès. Le site de référence est `https://www.perlesdivines.fr/sommaire.html`. Récupère ses pages et ressources publiques directement en ligne, en lecture seule. N’impose pas d’archive ZIP et ne modifie absolument rien sur le site existant.

L’application doit reprendre tout le contenu et l’identité visuelle du site, adaptés au mobile, et ajouter une rubrique Audios. Elle sera gratuite, en français, sans inscription publique, achat, don, abonnement, publicité, statistiques d’écoute ni notifications éditoriales. Prévoir environ 500 MP3 et un premier public estimé à 300 personnes, sans limite codée à ces nombres.

Les fonctions obligatoires sont : textes et ressources locales après préparation initiale, catalogue audio consultable hors ligne, recherche et filtres, téléchargement individuel/par collection/de tout le catalogue, reprise des transferts interrompus, export des MP3, lecteur audio réellement utilisable en arrière-plan et écran verrouillé, commandes écouteurs et système, positions sauvegardées, enchaînement, favoris, listes personnelles, vitesse et minuterie. Les commandes système de lecture et de transfert ne sont pas des notifications de nouveau contenu.

Le propriétaire doit disposer d’une administration privée simple pour importer les MP3, classer les contenus, modifier les textes et publier. Les contenus de l’application évoluent séparément du site. Aucune modification éditoriale automatique de textes religieux ; conserve les passages arabes, images, traductions, translittérations et références. Les noms et dossiers MP3 peuvent suggérer des métadonnées, mais ne constituent pas une autorisation d’inventer des auteurs ou descriptions.

La base recommandée est Flutter/Dart pour Android et iOS, avec les composants audio natifs via just_audio/audio_service/audio_session, téléchargements persistants, SQLite/Drift et lecture HTML locale contrôlée. L’administration utilise Next.js/TypeScript, Supabase pour la base et le compte administrateur, R2 pour les fichiers et un worker durable pour la validation/publication. Les versions exactes doivent être vérifiées et verrouillées ensemble. Un changement de ce choix nécessite une raison concrète documentée ; ne recommence pas un débat technique général.

Commence par une réalisation progressive :

1. Inspecte le dépôt et l’environnement. Ne remplace pas un travail existant sans le comprendre. Crée un suivi concis dans `docs/progress.md` et une matrice de validation dans `docs/acceptance.md`.
2. Mets en place l’inventaire/import reproductible du site, les contrôles des liens et un prototype de lecture fidèle hors connexion.
3. Réalise rapidement une preuve du lecteur natif et du téléchargement persistant avec quelques médias de test : arrière-plan, verrouillage, interruption, reprise et export. Vérifie iOS tôt dès que l’environnement le permet.
4. Poursuis avec le catalogue, les fonctions de bibliothèque, l’administration, la publication versionnée et l’import du vrai catalogue selon les jalons du cahier technique.
5. Exécute les tests pertinents après chaque étape et corrige les échecs avant d’élargir le périmètre. Conserve des preuves des essais réels.

Ne t’arrête pas à une maquette ou à un plan si tu disposes des moyens d’implémenter le jalon. À chaque fin de session, indique précisément ce qui est réalisé, les tests passés, les limites et la prochaine action concrète. Maintiens ce suivi dans le dépôt pour que la session suivante puisse reprendre.

Le propriétaire possède un téléphone Android et n’a pas encore confirmé de moyen d’essai iPhone. Ne prétends jamais qu’iOS est validé après une simple compilation ou des essais Android. Le chemin des MP3, les paramètres des services et les comptes stores seront fournis lorsqu’ils deviennent nécessaires. Continue les tâches indépendantes en attendant, avec des fixtures clairement identifiées.

Ne demande pas à nouveau les choix déjà arrêtés. Utilise les valeurs par défaut réversibles du cahier technique pour les détails mineurs ; demande seulement les informations réellement manquantes à l’étape concernée. N’engage pas de dépense, ne crée pas d’abonnement et ne publie pas sur un store sans l’autorisation correspondante. La construction locale et la préparation des livrables doivent avancer avant cette étape.

Le projet est terminé uniquement lorsque l’application Android/iOS, l’administration, le catalogue réel, les procédures de mise à jour et les validations demandées sont livrés, ou lorsque les étapes restantes dépendant du propriétaire sont identifiées précisément. Une version Android intermédiaire ne remplace pas l’objectif Android et iOS.
