# Spécification fonctionnelle

## Périmètre

Perles Divines est une application Flutter pour Android et iOS consacrée aux duʿā et ziyārāt. Elle doit fonctionner hors connexion après installation. Aucun compte utilisateur et aucun service serveur ne sont requis.

## Contenu embarqué

Chaque entrée possède un identifiant stable, un type (`dua`, `ziyarat`, `quran`, `namaz` ou `aamal`), un titre, le texte arabe Unicode lorsqu’il est présent dans la page source, sa traduction, sa translittération, ses références vérifiées et zéro ou plusieurs identifiants audio. Les textes et métadonnées sont extraits des pages importées puis relus dans le dépôt. La chaîne d'import ne doit jamais inventer une attribution, un arabe Unicode ou altérer un passage religieux. Lorsque l’arabe n’existe que sous forme d’images, l’application affiche la page originale embarquée.

Le catalogue est généré dans `apps/mobile/assets/content/`. L'édition du site normalisée et vérifiée par SHA-256 demeure embarquée dans `apps/mobile/assets/site/`. Les MP3 retenus sont inventoriés avant leur association au catalogue. Toute évolution éditoriale est livrée par une nouvelle compilation mobile.

## Fonctions

- parcourir séparément duʿā, ziyārāt et les autres sections importées ;
- rechercher dans titres, arabe, traductions, translittérations, introductions et références ;
- conserver favoris et positions uniquement sur l'appareil ;
- lire les textes sans réseau ;
- ouvrir la page originale pour l’arabe calligraphié ;
- associer une ou plusieurs pistes vérifiées à une entrée ;
- lire, interrompre et reprendre l'audio, et contrôler son intégrité ;
- exporter un MP3 sans recompression lorsque cette action est proposée.

## Contraintes

`apps/mobile/pubspec.yaml` est l'unique manifeste de dépendances de l'application. Android et iOS restent des hôtes Flutter minimaux : démarrage, audio, stockage, partage, ouverture de liens et tâches de transfert uniquement. Le site source est lu par requêtes GET et n'est jamais modifié.
