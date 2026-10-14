# Limites connues et roadmap

## Limites actuelles

- **Le `Wait 30s` ne refait pas de mesure** : il ne fait que retarder le traitement. La vraie confirmation vient du **cycle de scan suivant** (scanner PowerShell toutes les 5 minutes).
- **Compteurs non persistants en test manuel** : `$getWorkflowStaticData` ne sauvegarde qu'en exécution de production (workflow activé).
- **Logs dans la console n8n uniquement** : pas de fichier ni de base de données. Le compteur d'incidents est cumulé depuis l'activation.
- **Pas de re-test après restart** : le bilan SSH est affiché dans Telegram, mais n'est ni parsé ni vérifié par un nouveau test HTTP.
- **Machine éteinte** : si le serveur ne répond plus au ping, aucun redémarrage de service n'est possible. Le workflow envoie l'alerte avec `ERREUR SSH`.
- **Remédiation limitée au serveur Linux** de la `serviceMap` (Apache2, Nginx, MySQL).
- **`sudo` sans mot de passe requis** pour les 3 commandes de restart.
- **Webhooks** : le webhook de réception peut être protégé par Header Auth (recommandé), l'endpoint de statut est ouvert par défaut et expose l'inventaire réseau.
- **`serviceMap` codée en dur** dans le nœud, à tenir synchronisée avec le scanner.
- **Scanner** : toute erreur HTTP (401, 403, 404...) compte comme un service KO. Un équipement `DEGRADED` sans `httpUrl` déclenche une alerte "cycle 1" à chaque scan sans jamais être confirmé.

## Pistes d'amélioration

- Re-test HTTP après restart et alerte d'escalade si le service ne redémarre pas
- Vrai re-contrôle pendant le délai d'attente (ping et HTTP depuis n8n)
- Historique des incidents (base de données ou Google Sheets) et rapport hebdomadaire
- Tableau de bord (Grafana) alimenté par l'endpoint de statut
- Authentification de l'endpoint de statut et authentification SSH par clé
- `serviceMap` externalisée (fichier, base ou variable n8n) et générée à partir de la configuration du scanner
- Tolérance configurable des codes HTTP dans le scanner (considérer un 401 comme "service vivant")
- Ajout de services à surveiller (SSH, FTP, DNS interne)
