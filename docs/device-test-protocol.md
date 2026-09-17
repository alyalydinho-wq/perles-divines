# Essais de la preuve technique 0.1.0

Statut initial : aucun essai sur téléphone. Le propriétaire fera les essais Android avec l'APK ultérieurement. iOS nécessite toujours un Mac/Xcode et un iPhone physique. Ne cocher aucun test natif à partir de ce document seul.

## Préparer Android

1. Installer l'APK d'essai fourni dans `artifacts/`. Autoriser l'installation depuis la source choisie si Android le demande. Il s'agit d'une signature de développement, pas d'une version store.
2. Ouvrir l'application et attendre la préparation des textes. Fermer, passer en mode avion, rouvrir : visiter Sommaire, Qur'an, une page longue et À propos. Les liens externes nécessitent Internet.
3. Ouvrir Audios. La bannière doit annoncer des audios synthétiques. « Essai audio local » lit les deux courts fichiers embarqués sans serveur. Vérifier lecture/pause, déplacement, vitesse et changement d'écran.

## Transferts et piste longue

Les essais réseau utilisent un serveur de fixtures sur ce PC ; les URL de diffusion réelles R2 ne sont pas encore configurées.

```powershell
node tools/fixture-server.mjs
# Dans un autre terminal, téléphone relié en USB, débogage USB autorisé :
.\.tooling\android-sdk\platform-tools\adb.exe reverse tcp:4174 tcp:4174
```

La redirection USB donne accès au serveur sur `127.0.0.1:4174` depuis le téléphone. Pour l'émulateur, construire avec `--dart-define=PERLES_MEDIA_BASE=http://10.0.2.2:4174`. Le HTTP est limité aux destinations locales dans la configuration Android de débogage. Ne pas ouvrir de port public ni exposer ces fichiers de test sur le site.

- Demander un fichier, la collection, puis « Tout télécharger » deux fois. Vérifier l'absence de doublons, la limite de trois transferts et les états affichés.
- Suspendre/reprendre le fichier long ; retirer/rebrancher l'USB pendant le transfert, puis fermer/rouvrir l'application. Le fichier doit soit reprendre, soit recommencer proprement. Une simple interruption USB ne valide pas à elle seule une coupure Wi-Fi réelle.
- Une fois la piste longue validée, couper le réseau et la lire écran verrouillé pendant 30 minutes. Refaire le test en ligne avec un hébergement HTTPS de préproduction avant validation finale.
- Vérifier les commandes écran verrouillé, écouteurs filaires/Bluetooth, réception d'un appel et déconnexion des écouteurs. Aucune reprise intempestive après une pause volontaire.
- Mettre en pause au milieu de la piste, fermer/rouvrir : position retrouvée sans son automatique. Tester séparément retrait des applications récentes et arrêt forcé. Aucun fonctionnement après arrêt forcé n'est promis.
- Activer la minuterie puis verrouiller. Noter l'heure choisie et l'heure d'arrêt observée. Tester aussi la fin de piste.
- Exporter une piste téléchargée via le partage système. Comparer son SHA-256 avec `content/fixtures/catalog.json`.
- Vérifier le Wi-Fi uniquement sur un vrai réseau Wi-Fi puis sur données mobiles. La redirection USB ne valide pas ce critère.

## Preuves à enregistrer

Pour chaque essai : modèle du téléphone, version Android/iOS, version et SHA-256 de l'application, date, étapes, résultat attendu/observé, durée, fichier utilisé et éventuelles captures/journaux. Mettre à jour `acceptance.md` sans confondre tests du serveur, tests Dart et tests du système mobile.

## Limites actuelles du prototype

Le catalogue est un jeu de trois fixtures. Les listes personnelles, filtres complets, suppression locale, lots nommés avec progression pondérée, synchronisation distante, administration et publication ne sont pas livrés dans ce jalon. La minuterie personnalisée et les essais de reprise sur fichiers représentatifs du propriétaire restent à faire. Les tests R2/CDN devront utiliser les URL finales, avec vérification 206/416 et ETag.
