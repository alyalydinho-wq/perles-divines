# Pilote gujarati — Ziyârat Âchourâ

Livre : « જન્નતની ચાવીઓ », compilation de Maulana Rizwanali Palsaniya.
Pages PDF 161 à 170 (numéro imprimé = page PDF − 1). La ziyârat suivante, Amînullâh, commence à la page PDF 171.

Ce pilote ne concerne que Ziyârat Âchourâ. Les autres textes ne sont pas remplis.

## Comment le texte est stocké

L’application est Flutter. Chaque ziyârat est un objet de `apps/mobile/assets/content/catalog.json`, lu par `DevotionalText`. L’arabe, la traduction française et la translittération sont trois chaînes, pas une liste de versets.

- L’arabe est découpé à l’écran par ligne (`\n`), parfois regroupé par paragraphe (`\n\n`).
- Le français est un ou quelques longs paragraphes, redécoupés à l’affichage après `.`, `!` ou `?`.
- Il n’y a pas de système d’i18n : les libellés `Arabic`, `Translation`, `Transliteration` sont écrits en dur.

Le PDF, lui, alterne un bloc d’arabe (plusieurs lignes) et un paragraphe gujarati. Le gujarati n’a donc pas été coupé pour coller à chaque ligne arabe de l’app. Chaque paragraphe du livre est conservé entier. Deux paragraphes coupés par un changement de page, et qui ne finissent pas par un point, ont été recollés. Les autres restent séparés par une ligne vide dans le champ `gujarati`.

L’onglet Gujarati affiche ces paragraphes tels quels, de gauche à droite, sans le découpage par phrase utilisé pour le français.

## Extraction

Le texte Unicode brut du PDF est inutilisable (la matra િ devient « દ » ou « ખ » et passe devant la consonne, ુ et ૂ disparaissent, ં devient « ું »). Il n’a servi qu’à repérer les lignes en gujarati (police Arial Unicode MS).

Chaque bloc a été rasterisé à 300 dpi avec MuPDF, puis lu par Tesseract LSTM (`guj`, tessdata_best). Le résultat OCR a été relu sur les images, mot par mot pour les signes ambigus. Les corrections sont dans `data/gujarati/ashura.edits.json`. Le champ `ocr` garde la sortie Tesseract ; `text` est le texte relu.

```text
node tools/extract-gujarati-pdf.mjs --pdf "<chemin.pdf>" --from 161 --to 170 --out data/gujarati/ashura.gu.json
node tools/apply-gujarati-ashura.mjs
```

Le second script recopie le gujarati relu dans la fiche Âchourâ du catalogue. Il ne touche pas à l’arabe, au français ni à la translittération.

## Comptes

| | Nombre |
| --- | ---: |
| Blocs gujarati du PDF, titre compris | 24 |
| Paragraphes de traduction (hors titre, hors consignes) | 16 |
| Consignes (« પઢે ») | 4 |
| Paragraphes dans l’app après recollement de deux coupures de page | 21 |
| Lignes arabes de l’app, consignes françaises comprises | 140 |
| Lignes arabes seules | 136 |

Les nombres ne coïncident pas. Rien n’a été forcé : un paragraphe gujarati couvre plusieurs lignes arabes.

Les deux coupures recollées :

- page 165, fin « …બસ ખુદા મને દુનિયા અને » + page 166, « આખેરતમાં… »
- page 168, fin « …તેના ઉપર પણ લાનત » + page 169, « થાય જેઓ… »

Le paragraphe de la page 166 qui finit par une virgule (« …પહોંચાડે, ») n’a pas été collé au suivant : un bloc arabe les sépare dans le livre.

## Correspondance

| Gujarati | Sens, d’après le français de l’app |
| --- | --- |
| Titre ઝિયારતે આશૂરા | Titre de section. L’app affiche déjà le sien. Non recopié dans le corps. |
| Salâm à Abâ Abdillâh, au fils du Messager, au fils d’Ali et au fils de Fâtima | Début de la ziyârat, sans la basmala |
| Salâm « vengeance d’Allâh » et salâm aux âmes du seuil, tant que durent la nuit et le jour | Suite immédiate |
| L’épreuve est immense pour nous, les musulmans et les habitants des cieux | « le malheur de ta perte est immense… » |
| Malédiction sur ceux qui ont fondé l’oppression, écarté les Ahl al-Bayt, tué, préparé le combat ; désaveu | Jusqu’à « je les désapprouve » |
| Paix et guerre jusqu’au Jour dernier ; malédiction sur Ziyâd, Marwân, les Banû Umayya, Ibn Marjâna, Umar ibn Sa‘d, Shimr ; demande de vengeance avec l’imam secouru | Jusqu’à « descendant des Gens de la Maison de Mohammad » |
| Qu’Allâh rende honorable par al-Hussayn ; rapprochement par l’amour et le désaveu | « fais que par al-Hussain je mérite Ta considération » puis le désaveu |
| Je me rapproche d’Allâh puis de vous, contre les ennemis et leurs partisans | « je cherche à me rapprocher d’Allàh puis de vous » |
| Paix, guerre, amitié, inimitié ; être avec vous ici-bas et dans l’au-delà ; atteindre le rang | jusqu’à « le rang méritoire » |
| Vengeance avec l’imam Mahdî, récompense du deuil dans les cieux et sur la terre | « un Imâm de guidance… » |
| Que ma station reçoive miséricorde ; vie et mort comme Mohammad | « Fais que je sois… » et « fais-moi vivre et mourir » |
| Le jour dont se félicitent les Banû Umayya et le fils de la mangeuse de foies | « c’est un jour dont se sont félicités » |
| Malédiction sur Abû Sufyân, Mu‘âwiya, Yazîd ; joie des Âl Ziyâd et Âl Marwân | « maudis Abâ Sufyân… » |
| Rapprochement en ce jour par le désaveu et l’amour du Prophète | « je recherche Ta proximité en ce jour » |
| ત્યાર પછી 100 વખત આ રીતે પઢે | « Réciter 100 fois » (la malédiction) |
| Malédiction sur le premier oppresseur et sur la bande qui a tué al-Hussayn | le texte récité cent fois |
| 100 વખત આ રીતે પઢે | second « Réciter 100 fois » |
| Salâm à Abâ Abdillâh, aux âmes, à al-Hussayn, à Ali ibn al-Hussayn, aux enfants et aux compagnons | le salâm récité cent fois |
| ત્યાર પછી આ રીતે પઢે | « Réciter une fois » n’est pas écrit tel quel : le livre dit seulement « ensuite, réciter ainsi » |
| Malédiction du premier au cinquième (Yazîd), puis Ubayd Allâh, Shimr, les descendants d’Abû Sufyân, de Ziyâd et de Marwân | le passage récité une fois |
| સજદામાં જઈને આ રીતે પઢે | « Se prosterner (sujûd) et réciter » |
| Louange et demande d’intercession d’al-Hussayn | la prosternation finale |

## Présent dans l’app, absent du PDF

Le gujarati est laissé vide. Rien n’a été inventé.

- L’encadré « Selon un hadith de l’Imâm Sâdiq (as) » et la mention du Du‘â’ Alqamah.
- « Accomplir enfin une prière de 2 rak‘ats. » La page 170 finit sur la prosternation. Amînullâh commence à la page 171.
- La basmala. Le livre ouvre la section directement par le salâm. Le français de l’app, lui, commence par « Par la grâce du nom d’Allàh… ».
- Les parenthèses et variantes de l’arabe de l’app (par exemple le passage entre parenthèses autour de « ceux qui t’ont combattu ») ne forment pas un paragraphe gujarati séparé. Le livre donne une seule traduction suivie.

L’onglet Gujarati n’affiche pas l’encadré français. Cet encadré reste sur les trois autres onglets.

## Doutes à faire relire

Le sens suit le français. L’orthographe est celle du livre, pas une forme « corrigée ».

- રસુલ / રસુલે est imprimé avec un ુ bref, pas રસૂલ.
- અબુ અબ્દિલ્લાહ (pages 162 à 164) et અબા અબ્દિલ્લાહ (page 161) sont tous deux imprimés ainsi. Page 169 : અબા અબ્દીલ્લાહ, avec દી long.
- « ખુદા લાનત કે તે લોકો » : le livre écrit કે, pas કરે, à cet endroit seulement. Les autres formules ont કરે.
- બહુજ, en fin de paragraphe de la page 162, est collé. Plus haut sur la même page, c’est « બહુ જ ».
- મોહંમદ : le point au-dessus peut se lire anusvāra (મોહંમદ) ou conjonction મ્મ (મોહમ્મદ). L’OCR et une partie des agrandissements donnent મોહંમદ. À confirmer.
- તૌફ્ક (page 166) à côté de તૌફીક (page 165). Les deux sont laissés comme imprimés.
- દુરી (page 164, ુ bref) et દૂરી (page 162, ૂ). Les deux sont imprimés.
- ક્યા (pages 162 et 163) est bien la forme imprimée, là où on attendrait plutôt કર્યા.
- અલય્હીમુસ્સલામ : l’OCR a peut-être séparé ou soudé le mot. À relire sur la page 167.
- વિરૂધ (page 164) : forme imprimée, à confirmer face à વિરુદ્ધ.

La revue phrase par phrase est dans `docs/gujarati-ashura-review.md`.
