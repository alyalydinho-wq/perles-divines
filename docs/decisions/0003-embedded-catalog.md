# 0003 — Catalogue exclusivement embarqué

## Décision

Supprimer les composants serveur et conserver un produit mobile autonome. Les duʿā, ziyārāt, traductions, translittérations, références et associations audio sont préparés dans Git, générés comme assets Flutter et distribués avec chaque version de l'application.

## Conséquences

- fonctionnement et consultation hors connexion prévisibles ;
- surface de sécurité, exploitation et dépendances réduite ;
- aucune modification éditoriale à distance ;
- toute correction de contenu exige revue, régénération des assets, tests et nouvelle livraison mobile ;
- les outils d'import du site et d'inventaire MP3 sont conservés, mais ne font pas partie de l'application exécutée.
