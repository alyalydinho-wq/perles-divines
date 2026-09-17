# Import initial isolé

Le site existant est consulté exclusivement par GET. Chaque capture est écrite dans un nouveau répertoire horodaté ; les octets bruts ne sont jamais remplacés. Les ressources normalisées et les rapports sont reconstruits séparément. Aucun import ne touche des brouillons administrés.

Les URL externes sont inventoriées, jamais parcourues automatiquement. Les erreurs du site restent visibles. Le prototype web local sert à vérifier le contenu et ne remplace pas l'application Flutter ni les essais natifs.

Les SDK téléchargés pour le développement restent dans `.tooling/`, exclus de Git. Aucun changement d'architecture n'est décidé.
