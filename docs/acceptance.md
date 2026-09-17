# Matrice de validation

Chaque essai doit préciser version, appareil, date et preuve. Une compilation ne valide pas le fonctionnement natif.

| Test | Action | Résultat attendu | Statut | Version / appareil / date / preuve |
|---|---|---|---|---|
| T01 | Inventorier les pages internes accessibles. | Chaque page retenue est importée ou explicitement signalée comme indisponible ; décompte documenté. | réussi | Import du 17/09/2026 ; 114 pages, rapport content/import-report.json |
| T02 | Comparer les pages représentatives au site. | Texte, arabe, images, rubriques et identité conservés ; adaptations mobiles explicables. | non exécuté | — |
| T03 | Terminer la préparation des textes, couper Internet, rouvrir. | Toutes les pages importées et leurs ressources internes restent consultables. | non exécuté | — |
| T04 | Interrompre la première synchronisation. | Progression récupérable, aucune fausse indication de disponibilité complète. | non exécuté | — |
| T05 | Ouvrir Tafsir/Diaporama hors ligne. | Présentation locale visible ; besoin d’Internet pour la destination externe indiqué. | non exécuté | — |
| T06 | Télécharger une piste puis activer le mode avion. | Lecture complète et export possibles. | non exécuté | — |
| T07 | Télécharger une collection contenant des pistes déjà présentes. | Seulement les médias manquants sont transférés. | non exécuté | — |
| T08 | Demander tout le catalogue, puis renouveler la demande. | File bornée sans doublons ; progression et poids corrects. | non exécuté | — |
| T09 | Couper le réseau au milieu d’un gros téléchargement. | État compréhensible, reprise ou redémarrage propre, contrôle final réussi. | non exécuté | — |
| T10 | Fermer/reprendre l’application pendant un lot. | Réconciliation des tâches et des fichiers, aucun téléchargement fantôme. | non exécuté | — |
| T11 | Suspendre/reprendre/annuler un lot. | Actions réelles sur les transferts, fichiers complets conservés. | non exécuté | — |
| T12 | Réduire l’espace disponible pendant un lot. | Erreur explicite et aucune corruption des fichiers déjà présents. | non exécuté | — |
| T13 | Fournir taille ou empreinte erronée. | Fichier refusé, jamais déclaré disponible. | non exécuté | — |
| T14 | Vérifier le réglage Wi-Fi uniquement. | Aucun transfert audio sur données mobiles sans choix de l’utilisateur. | non exécuté | — |
| T15 | Écouter un MP3 local et un MP3 en ligne, écran verrouillé pendant 30 minutes. | Continuité de lecture sur Android ET iPhone, sans écran artificiellement maintenu allumé. | non exécuté | — |
| T16 | Utiliser commandes écran verrouillé et écouteurs. | Lecture/pause/précédent/suivant cohérents avec le lecteur affiché. | non exécuté | — |
| T17 | Recevoir un appel et déconnecter les écouteurs. | Gestion appropriée de l’interruption, absence de reprise intempestive. | non exécuté | — |
| T18 | Réouvrir après arrêt pendant une piste. | Position restaurée à environ cinq secondes près ; aucun son automatique. | non exécuté | — |
| T19 | Laisser une collection s’enchaîner hors ligne. | Ordre respecté ; erreurs de pistes indisponibles traitées sans boucle. | non exécuté | — |
| T20 | Modifier la vitesse, quitter le lecteur et revenir. | Vitesse conservée et utilisée réellement. | non exécuté | — |
| T21 | Activer la minuterie puis verrouiller l’écran. | Arrêt au terme choisi ou à la fin de piste, selon le mode ; temps mesuré. | non exécuté | — |
| T22 | Créer une liste, modifier son ordre, redémarrer. | Liste, favoris et ordre conservés. | non exécuté | — |
| T23 | Chercher un titre sans accent en mode avion et combiner les filtres. | Résultat correct, réactif, aucune requête de recherche externe. | non exécuté | — |
| T24 | Exporter un MP3 sur Android et iOS. | Fichier accessible dans la destination choisie, octets identiques à l’original. | non exécuté | — |
| T25 | Supprimer le MP3 de l’application après export. | Copie exportée intacte, favoris conservés, espace interne libéré. | non exécuté | — |
| T26 | Publier une nouvelle piste depuis l’administration. | Elle apparaît après actualisation sans nouvelle version du store. | non exécuté | — |
| T27 | Modifier un texte dans l’administration. | Modification visible dans l’application après synchro et ensuite hors ligne ; site inchangé. | non exécuté | — |
| T28 | Éditer une page contenant un bloc complexe puis enregistrer. | Les éléments non modifiés survivent à l’aller-retour dans l’éditeur. | non exécuté | — |
| T29 | Échouer une publication avant ou après mise à jour du pointeur public. | Ancienne version utilisable ou nouvelle version entièrement prête ; état serveur réconcilié. | non exécuté | — |
| T30 | Interrompre une mise à jour locale à plusieurs étapes. | Ancienne édition intacte ; bascule seulement vers une édition complète. | non exécuté | — |
| T31 | Archiver une piste puis synchroniser. | Catalogue actualisé ; listes/favoris et copies locales traités selon la politique documentée. | non exécuté | — |
| T32 | Remplacer un MP3 en cours de lecture/téléchargement. | Pas de mélange de versions ni suppression du fichier utilisé. | non exécuté | — |
| T33 | Appeler une mutation sans session ou avec utilisateur non administrateur. | Refus systématique côté serveur et par les règles de base. | non exécuté | — |
| T34 | Essayer contenu scripté, chemin `../` et fichier non MP3. | Nettoyage ou refus ; aucune exécution ni sortie du répertoire autorisé. | non exécuté | — |
| T35 | Restaurer une sauvegarde sur un environnement vide. | Textes, catalogue, médias et publication opérationnels. | non exécuté | — |
| T36 | Mettre à jour une ancienne application avec données locales. | Migrations réussies, favoris/listes/positions conservés. | non exécuté | — |
| T37 | Auditer le binaire et les requêtes réseau. | Aucun secret d’écriture, suivi d’écoute, paiement, inscription publique ou notification push. | non exécuté | — |
| T38 | Tester petit écran et agrandissement du texte. | Navigation et lecteur utilisables ; aucune commande essentielle masquée. | non exécuté | — |

## Exigences suivies

| ID | Exigence |
|---|---|
| E01 | Reprendre tout le site public, avec son apparence actuelle adaptée aux écrans mobiles. |
| E02 | Application publique, interface en français, distribution mondiale souhaitée. |
| E03 | Prévoir environ 300 utilisateurs au départ ; estimation incertaine, pas une limite technique. |
| E04 | Ajouter une rubrique « Audios », seule nouvelle rubrique éditoriale demandée à ce stade. |
| E05 | Environ 500 MP3 disponibles sur l’ordinateur du propriétaire ; droits de diffusion et d’export confirmés. |
| E06 | Téléchargement d’un audio, d’une collection ou de tout le catalogue, au choix de l’utilisateur. |
| E07 | Textes et pages disponibles automatiquement hors connexion après une première synchronisation réussie. |
| E08 | Autoriser l’export des fichiers audio téléchargés hors de l’application. |
| E09 | Lecture audio en arrière-plan et écran verrouillé. |
| E10 | Reprise de position, enchaînement, listes de lecture, favoris, vitesse et minuterie d’arrêt. |
| E11 | Commandes audio sur l’écran verrouillé et depuis les écouteurs. |
| E12 | Recherche rapide et filtres par auteur, thème et collection. |
| E13 | Administration simple pour ajouter les audios et modifier les textes de l’application. |
| E14 | Les nouvelles publications apparaissent à la prochaine synchronisation avec connexion. |
| E15 | Application entièrement gratuite ; aucun achat, don, abonnement ou publicité. |
| E16 | Aucun compte pour les utilisateurs de l’application. |
| E17 | Aucune notification de nouveau contenu et aucune statistique d’écoute demandée. |
| E18 | Aucun changement sur le site ; administration et contenus de l’application indépendants. |
| E19 | Publication sous l’identité de l’éditeur désigné par le propriétaire, établi à La Réunion. Les formalités de propriété sont considérées réglées. |
| E20 | Développement avec une IA et le propriétaire ; budget à définir, aucune échéance fixe. |
| E21 | Le propriétaire dispose d’un téléphone Android pour les essais. Pas d’iPhone confirmé. |

## Preuves partielles du 17 septembre 2026

Les statuts globaux restent `non exécuté` tant que le scénario demandé n'est pas terminé sur ses cibles. Les éléments ci-dessous sont des preuves intermédiaires, pas des substitutions à la recette Android **et** iPhone.

| Tests concernés | Vérification effectivement réussie | Limite restante |
|---|---|---|
| T02–T05, T38 | 114 textes/888 images conservés ; comparaison visuelle de cinq sources ; 24 contrôles Edge hors Internet sur huit pages à 320/390/430 px. `evidence/content-integrity.json`, `reader-browser.json`, captures. | Refaire préparation, relance hors ligne, interruptions et agrandissement sur téléphone. Positions de pages encore à intégrer dans Flutter. |
| T09, T13, T18, T24, T30 | Cinq tests Dart locaux : positions, noms d'export, persistance SQLite, rollback, intégrité refusant un fichier incomplet/corrompu. Tests HTTP Range/If-Range et reconstruction exacte d'une piste. | Aucun téléchargement, export système, redémarrage ou coupure réelle validé sur appareil. |
| T15–T21 | Service natif et commandes codés ; analyse Flutter et build APK réussis. `evidence/flutter-analyze.txt`, `flutter-tests.txt`, `android-artifact.json`. | **Aucune preuve de fonctionnement natif**. Le propriétaire essaiera l'APK plus tard. iOS ni compilé ni testé. |
| T28 | Éditeur de fragments : modification en mémoire sur chaque page réelle ; autres textes et toutes les balises identiques, script saisi échappé. Tests Node. | Parcours visuel authentifié et accord éditorial propriétaire à faire ; images/liens et restauration via interface à compléter. |
| T29 | Worker SQLite/fichiers local : erreur avant le pointeur, exception injectée après, reprise du bail, objets immuables et version croissante. Trois MP3 synthétiques publiés puis relus avec SHA identiques. `evidence/node-tests.txt`, `local-publication.json`. | R2/PostgreSQL réels, arrêt de processus, page ZIP et chaîne jusqu'au téléphone non testés. |
| T33 | Tests SQL PostgreSQL/PGlite : aucun droit d'écriture public, membre sans rôle refusé, rôle révoqué refusé. Sept contrôles sur routes Next réelles sans session : 401/403. Huit contrôles navigateur de l'état sans configuration. `evidence/admin-unauthorized.json`, `admin-browser.json`. | Auth, récupération, cookies et RLS à retester avec les comptes réels et le service Supabase configuré. |
| T34 | Import sans scripts, texte injecté échappé, chemins traversants refusés, faux MP3 refusé malgré taille/hash corrects. | Extraction des paquets ZIP à implémenter et éprouver ; audit complet des routes d'import futures. |

Commande de la suite Node : `node --test tools/tests/*.test.mjs` — **21 tests réussis**. Compilation administration : `npm run build --workspace=@perles/admin` — réussie, TypeScript inclus. Versions dans `dependencies.md`. Les captures navigateur ne sont pas des essais natifs.

E05 : outil d'inventaire local prêt ; test sur trois fichiers temporaires et exécution sur les cinq fixtures. Taille/SHA/durée/tags, doublons et invalides signalés ; empreinte source inchangée et aucun auteur inventé. Le propriétaire a fourni son dossier et ajoutera les MP3 ultérieurement ; l'import réel attend ces fichiers (`audio-inventory.md`).
