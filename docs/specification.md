# Spécification fonctionnelle

## Périmètre

Perles Divines est une application Flutter pour Android et iOS consacrée aux duʿā et ziyārāt. Elle doit fonctionner hors connexion après installation. Aucun compte utilisateur et aucun service serveur ne sont requis.

## Contenu embarqué

Chaque entrée possède un identifiant stable, un type (`dua` ou `ziyarat`), un titre, le texte arabe, sa traduction, sa translittération, ses références vérifiées et zéro ou plusieurs identifiants audio. Les textes et métadonnées sont préparés et relus dans le dépôt. La chaîne d'import ne doit jamais inventer une attribution ou altérer un passage religieux.

Le catalogue est généré dans `apps/mobile/assets/content/`. L'édition du site normalisée et vérifiée par SHA-256 demeure embarquée dans `apps/mobile/assets/site/`. Les MP3 retenus sont inventoriés avant leur association au catalogue. Toute évolution éditoriale est livrée par une nouvelle compilation mobile.

## Fonctions

- parcourir séparément duʿā et ziyārāt ;
- rechercher dans titres, arabe, traductions, translittérations et références ;
- conserver favoris et positions uniquement sur l'appareil ;
- lire les textes sans réseau ;
- associer une ou plusieurs pistes vérifiées à une entrée ;
- lire, interrompre et reprendre l'audio, et contrôler son intégrité ;
- exporter un MP3 sans recompression lorsque cette action est proposée ;
- afficher clairement l'état vide tant que le catalogue religieux relu n'est pas intégré.

## Contraintes

`apps/mobile/pubspec.yaml` est l'unique manifeste de dépendances de l'application. Android et iOS restent des hôtes Flutter minimaux : démarrage, audio, stockage, partage, ouverture de liens et tâches de transfert uniquement. Le site source est lu par requêtes GET et n'est jamais modifié.
