# Format des données et tests

## Payload attendu (POST sur `/webhook/net-monitor`)

```json
{
  "timestamp": "2026-10-14T10:00:00Z",
  "severity": "DEGRADED",
  "highRiskCount": 0,
  "devices": [
    { "ip": "192.168.1.50", "name": "Serveur Web", "status": "DEGRADED", "httpOK": false }
  ]
}
```

| Champ | Description |
|---|---|
| `timestamp` | Date du scan (ISO 8601) |
| `severity` | `OK`, `WARNING`, `DEGRADED`, `CRITICAL` ou `UNKNOWN` |
| `highRiskCount` | Nombre d'équipements à risque (informatif) |
| `devices[].ip` | Clé de correspondance avec la `serviceMap` |
| `devices[].name` | Nom affiché dans les alertes |
| `devices[].status` | `UP`, `DOWN`, `DEGRADED` ou `MASKED` |
| `devices[].httpOK` | `true` si le service HTTP répond, `false` sinon |

## Signification des statuts

| Statut | Sens | Action |
|---|---|---|
| `UP` | L'équipement répond | Compteur de pannes remis à 0 |
| `DOWN` | Ne répond pas | Compte comme panne |
| `DEGRADED` | La machine répond mais le service est KO (`httpOK=false`) | Compte comme panne, cas typique du restart de service |
| `MASKED` | Équipement masqué | Compté dans le bilan, aucune action |

## Tests

Utilise l'URL de production (workflow activé).

**1. Premier cycle : anomalie détectée, pas de remédiation**

```bash
curl -X POST https://<ton-n8n>/webhook/net-monitor \
  -H "Content-Type: application/json" \
  -d @examples/sample-payload.json
```

Attendu : message Telegram `ANOMALIE DÉTECTÉE (cycle 1)`.

**2. Second cycle : panne confirmée, restart SSH**

Prépare d'abord le test en arrêtant Apache sur la VM :

```bash
sudo systemctl stop apache2
```

Renvoie le même payload :

```bash
curl -X POST https://<ton-n8n>/webhook/net-monitor \
  -H "Content-Type: application/json" \
  -d @examples/sample-payload.json
```

Attendu : Apache redémarré sur la VM, message Telegram `INCIDENT RÉSEAU CONFIRMÉ` avec le résultat SSH.

**3. Retour à la normale**

Envoie un payload avec `"status": "UP"` et `"httpOK": true` : le compteur repasse à 0.

**4. Endpoint de statut**

```bash
curl https://<ton-n8n>/webhook/net-monitor-status
```

Attendu : le dernier état enrichi au format JSON.

**5. Équipement exclu**

Mets le routeur (`192.168.1.1`) en `DOWN` avec `httpOK: false` sur 2 cycles : alerte Telegram, mais aucun SSH (`type non redémarrable`).
