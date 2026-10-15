# Audit des bornes gujarati

Lecture seule. Aucun lot autre que Nudba n’a été modifié.
`headings.json` repère toute ligne gujarati de corps au moins 18. Ce n’est pas toujours un titre de section : une citation en gros caractères y figure aussi.
« Page avant » = page PDF du prochain repère de `headings.json`, moins un. Le champ `to` du lot est comparé à cette page.

| Lot | from | to | Prochain repère | Page avant | Lecture |
| --- | --- | --- | --- | --- | --- |
| yasin | 7 | 15 | p. 16 દુઆએ પંજગાના | 15 | `to` égal à la page avant |
| ahad | 80 | 85 | p. 86 દુઆએ તવસ્સુલ | 85 | `to` égal à la page avant |
| tawassoul | 86 | 95 | p. 96 હદીસે કિસા | 95 | `to` égal à la page avant |
| kisa | 96 | 106 | p. 107 શબે જુમૂઆ, petite du‘â | 106 | `to` égal à la page avant |
| kumayl | 108 | 128 | p. 129 દુઆએ નુદબા | 128 | `to` égal à la page avant |
| nudba | 129 | 154 | p. 135, citation « મન કુન્તુ… » | 134 | écart voulu |
| waressa | 154 | 157 | p. 158 ઝિયારત જનાબે અલી અકબર | 157 | `to` égal à la page avant |
| aminullah | 171 | 175 | p. 176 ઝિયારતે આલે યાસીન | 175 | `to` égal à la page avant |
| rajab | 212 | 213 | p. 213 અમલે ઉમ્મે દાઉદ | 212 | `to` est la page du titre suivant |
| iftetah | 250 | 264 | p. 265 nuit de Ramadan | 264 | `to` égal à la page avant |
| munajat-ali | 272 | 280 | p. 281, trois lignes en corps 18 | 280 | `to` égal à la page avant, mais la prière continue |
| mujir | 282 | 297 | p. 298 દુઆએ તૌબા | 297 | `to` égal à la page avant |
| abu-hamza | 331 | 359 | p. 360 દુઆ ખત્મે કુરાન | 359 | `to` égal à la page avant |

Les libellés du tableau sont normalisés. `headings.json` garde, lui, les matras cassées du texte brut.

## Nudba

Les repères des pages 135 et 141 ne sont pas des titres de section. Ce sont des citations en gros caractères au milieu du du‘â (« મન કુન્તુ મૌલાહુ… », puis « અયનલ હસનો… »). Le prochain titre de section est ઝિયારતે વારેસા, au milieu de la page PDF 154. Le `to` 154 s’arrête avant ce titre. La page avant le faux repère de la page 135 serait 134, ce qui tronquait le texte.

## Mounajat de l’Imam Ali

Le lot s’arrête à la page PDF 280. La page 281 (imprimée 280) n’est pas une page étrangère.

En haut, le gujarati continue la prière : la traduction du dernier verset arabe, puis une salawât. Cette partie appartient à la Mounajat. Le lot actuel la laisse dehors.

Plus bas, un encadré cite Janabe Fatema Zahra (s.a.) et trois récompenses numérotées, en corps 18 : la récitation du Coran, la ziyârat du visage béni du Messager, l’aumône sur le chemin de Dieu, avec la mention (નહજુલ બલાગત). Ce cadre n’est pas le texte de la Mounajat. Le titre દુઆએ મોજીર commence à la page PDF 282.

La page 281 appartient donc à la Mounajat pour le haut de page seulement. L’encadré ne doit pas être repris dans la prière. Rien n’a été changé ici.
