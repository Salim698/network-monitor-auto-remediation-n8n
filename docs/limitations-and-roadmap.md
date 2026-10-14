# Limites connues et roadmap

## Limites actuelles

- **Le `Wait 30s` ne refait pas de mesure** : il ne fait que retarder le traitement. La vraie confirmation vient du **cycle de scan suivant** (PowerShell toutes les 5 minutes).
- **Compteurs non persistants en test manuel** : `$getWorkflowStaticData` ne sauvegarde qu'en exécution de production (workflow activé).
- **Logs dans la console n8n uniquement** : pas de fichier ni de base de données. Le compteur d'incidents est cumulé depuis l'activation.
- **Pas de re-test après restart** : le bilan SSH est affiché dans Telegram, mais n'est ni parsé ni vérifié par un nouveau test HTTP.
- **Remédiation limitée au serveur Linux** de la `serviceMap` (Apache2, Nginx, MySQL).
- **`sudo` sans mot de passe requis** pour les 3 commandes de restart.
- **Webhooks non authentifiés** : l'endpoint de statut expose l'inventaire réseau.
- **`serviceMap` codée en dur** dans le nœud.
- **Script PowerShell de scan** non inclus dans ce repo.

## Pistes d'amélioration

- Re-test HTTP après restart et alerte d'escalade si le service ne redémarre pas
- Vrai re-contrôle pendant le délai d'attente (ping et HTTP depuis n8n)
- Historique des incidents (base de données ou Google Sheets) et rapport hebdomadaire
- Tableau de bord (Grafana) alimenté par l'endpoint de statut
- Authentification des webhooks (Header Auth ou token secret) et authentification SSH par clé
- `serviceMap` externalisée (fichier, base ou variable n8n)
- Ajout de services à surveiller (SSH, FTP, DNS interne)
- Ajout du script PowerShell de scan, documenté
