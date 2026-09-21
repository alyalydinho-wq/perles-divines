# Acceptation

| ID | Vérification | Résultat attendu |
|---|---|---|
| T01 | Installation sans réseau. | Les textes embarqués sont lisibles après vérification d'intégrité. |
| T02 | Recherche par titre, arabe, traduction, translittération ou référence. | Les entrées correspondantes sont retournées localement. |
| T03 | Filtrer duʿā, ziyārāt et les autres sections. | Les catégories restent distinctes. |
| T04 | Ajouter puis retirer un favori et redémarrer. | L'état local est conservé. |
| T05 | Lire une piste associée, interrompre puis reprendre. | La position valide est restaurée. |
| T06 | Corrompre ou tronquer un média. | Le fichier est refusé avant lecture/export. |
| T07 | Lancer l'inventaire MP3 sur doublon, lien et faux fichier. | Doublons signalés, lien ignoré, média invalide refusé, aucune attribution inventée. |
| T08 | Modifier le catalogue. | Une nouvelle compilation est nécessaire et les nouveaux assets sont embarqués. |
| T09 | Inspecter Android/iOS. | Seulement hôtes Flutter et intégrations natives indispensables. |
| T10 | Exécuter analyses et tests. | Suites Node et Flutter réussies. |

Les essais sur émulateur ne remplacent pas les essais audio, interruption, stockage et partage sur appareils physiques.
