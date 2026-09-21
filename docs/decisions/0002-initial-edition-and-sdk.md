# 0002 — Embarquer l'édition initiale

La capture normalisée est suffisamment compacte pour être incluse dans l'application. Au premier lancement, l'installation copie les fichiers dans un répertoire privé temporaire, vérifie taille et SHA-256, puis rend l'ensemble disponible atomiquement. Cette édition permet la lecture hors connexion.

Le SDK Android local sert aux compilations et essais. Les comptes stores, certificats, contrats et frais restent sous le contrôle explicite du propriétaire.
