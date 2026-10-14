# Description des nœuds

## Branche principale (surveillance)

| Nœud | Type | Rôle |
|---|---|---|
| Webhook - Réception PowerShell | Webhook (POST) | Reçoit le scan réseau |
| Code - Analyse & Service Map | Code | Enrichit chaque équipement (type, criticité, commande SSH) et calcule les compteurs UP/DOWN/DEGRADED/MASKED |
| Save Last State | Code | Sauvegarde le dernier état dans les static data (pour l'endpoint de statut) |
| IF - Des équipements DOWN ? | IF | Continue seulement s'il y a au moins un DOWN ou DEGRADED |
| Réseau 100% OK — Aucune action | NoOp | Fin du flux quand tout va bien |
| Wait 30s - Délai anti faux positif | Wait | Délai de 30 secondes avant l'évaluation |
| Code - Confirmation + Compteur ≥2 cycles | Code | Incrémente le compteur de pannes consécutives par IP, remet à 0 les équipements UP, liste les pannes confirmées |
| IF - Panne confirmée ≥2 cycles ? | IF | Oriente vers la remédiation ou l'alerte "cycle 1" |
| Telegram - Anomalie détectée (cycle 1) | Telegram | Prévient d'une anomalie non encore confirmée |

## Branche remédiation

| Nœud | Type | Rôle |
|---|---|---|
| Code - Garde-fou & commande SSH ciblée | Code | Applique les règles, construit la commande SSH, explique pourquoi un restart est évité |
| IF - SSH éligible ? | IF | Au moins une cible éligible ? |
| SSH - Auto-remédiation ciblée | SSH | Exécute la commande sur le serveur Linux |
| Pas de SSH - Type exclu ou httpOK | NoOp | Aucune remédiation possible ou nécessaire |
| Code - Préparer entrée log | Code | Construit la ligne de log (incident, équipements, résultat SSH) |
| Code - Écrire log fichier | Code | Écrit la ligne dans la console n8n (`console.log`) |
| Telegram - Alerte panne confirmée | Telegram | Rapport complet : bilan, pannes, remédiation, sortie SSH |

## Endpoint de statut

| Nœud | Type | Rôle |
|---|---|---|
| Webhook | Webhook (GET) | `/webhook/net-monitor-status` |
| Code in JavaScript | Code | Lit le dernier état enregistré |
| Respond to Webhook | Respond to Webhook | Renvoie l'état en JSON |

## Notes (sticky)

`Note - Architecture`, `Note - Garde-fou` et `Note - Compteur` documentent le flux directement dans l'éditeur n8n.
