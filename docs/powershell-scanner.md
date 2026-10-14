# Scanner PowerShell

Le script `scripts/net-scan.ps1` est la **source de données** du workflow : il teste les équipements du réseau et envoie le résultat en JSON au webhook n8n.

## Prérequis

- Windows 10/11 ou Windows Server avec PowerShell 5.1 ou plus récent
- Accès réseau aux équipements surveillés
- Accès à l'URL du webhook n8n

## Configuration

### Webhook et token

Le script lit deux variables d'environnement (ou les paramètres `-Webhook` et `-Token`) :

```powershell
[Environment]::SetEnvironmentVariable("NET_MONITOR_WEBHOOK", "https://<ton-n8n>/webhook/net-monitor", "User")
[Environment]::SetEnvironmentVariable("NET_MONITOR_TOKEN", "<ton-token-secret>", "User")
```

Ferme puis rouvre PowerShell pour qu'elles soient prises en compte.

### Liste des équipements

Modifie le tableau `$Equipements` en haut du script :

| Champ | Rôle |
|---|---|
| `ip` | Adresse de l'équipement. C'est aussi la clé de correspondance avec la `serviceMap` du workflow |
| `name` | Nom affiché dans les alertes |
| `port` | Port TCP testé (`0` pour ne pas tester) |
| `httpUrl` | URL testée en HTTP (`$null` pour ne pas tester) |

Chaque IP ajoutée ici doit aussi être déclarée dans la `serviceMap` du nœud `Code - Analyse & Service Map`, sinon elle est classée `Inconnu` (jamais redémarrée automatiquement).

## Logique des statuts

| Ping | Test | Statut | `httpOK` |
|---|---|---|---|
| Échoue | n/a | `DOWN` | `false` |
| Répond | `httpUrl` défini, HTTP OK | `UP` | `true` |
| Répond | `httpUrl` défini, HTTP KO | `DEGRADED` | `false` |
| Répond | pas de `httpUrl`, port ouvert | `UP` | `null` |
| Répond | pas de `httpUrl`, port fermé | `DEGRADED` | `null` |

Le garde-fou du workflow ne redémarre un service que si `httpOK` vaut **exactement `false`**. Pour un équipement sans `httpUrl`, `httpOK` vaut `null` : le workflow le signale mais ne lance jamais de remédiation (voir [points d'attention](#points-dattention)).

## Exécution manuelle

```powershell
.\scripts\net-scan.ps1
```

Exemple de sortie :

```
===== NETWORK MONITOR =====
Routeur [192.168.1.1] -> UP
Serveur Linux [192.168.1.50] -> DEGRADED
Switch [192.168.1.2] -> UP

DOWN:0 DEG:1 => DEGRADED
Envoye a n8n OK
```

## Planification toutes les 5 minutes

Dans PowerShell (une seule fois) :

```powershell
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\net-monitor\net-scan.ps1"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
  -RepetitionInterval (New-TimeSpan -Minutes 5) `
  -RepetitionDuration (New-TimeSpan -Days 3650)
Register-ScheduledTask -TaskName "NetMonitor" -Action $action -Trigger $trigger `
  -Description "Scan réseau toutes les 5 minutes vers n8n"
```

La tâche s'exécute sous ton compte (les variables d'environnement `User` y sont disponibles) et seulement quand tu es connecté. Pour un fonctionnement permanent, configure la tâche pour "s'exécuter même si l'utilisateur n'est pas connecté".

Vérifier ou supprimer :

```powershell
Get-ScheduledTaskInfo -TaskName "NetMonitor"
Unregister-ScheduledTask -TaskName "NetMonitor" -Confirm:$false
```

## Protéger le webhook (recommandé)

1. Dans n8n, ouvre le nœud `Webhook - Réception PowerShell` > **Authentication** > **Header Auth**
2. Crée une credential : **Name** = `X-Monitor-Token`, **Value** = ton token secret
3. Utilise la même valeur dans `NET_MONITOR_TOKEN` côté Windows

Sans le bon header, n8n répond `403` et le script affiche l'erreur.

## Format envoyé

Voir [payload-format.md](payload-format.md). Le script ajoute `portOK` (résultat du test de port), champ informatif ignoré par le workflow.

## Points d'attention

- **Toute erreur HTTP compte comme KO** : un `401`, `403` ou `404` fait passer l'équipement en `DEGRADED`, comme un timeout. Choisis une `httpUrl` qui répond en `200`.
- **Équipements sans `httpUrl`** : s'ils sont `DEGRADED` (port fermé), `httpOK` vaut `null`. Le workflow envoie alors une alerte "anomalie cycle 1" à chaque scan, sans jamais la confirmer ni agir. Pour les équipements importants, donne-leur une `httpUrl`.
- **Équipement `DOWN`** : le garde-fou le considère éligible s'il a une commande SSH. Si la machine est éteinte, la connexion SSH échoue et l'alerte Telegram indique `ERREUR SSH`.
- **Durée d'un scan** : un équipement `DOWN` retarde le scan de quelques secondes (délai du ping). Prévois une marge sur 5 minutes si tu surveilles beaucoup d'équipements.

## Dépannage

| Symptôme | Cause probable |
|---|---|
| `Webhook manquant` | Variable `NET_MONITOR_WEBHOOK` non définie ou terminal non rouvert |
| `Erreur envoi n8n : 403` | Token absent ou différent de celui de la credential n8n |
| `Erreur envoi n8n : 404` | Workflow non activé (URL `/webhook/`) ou mauvaise URL de test |
| Tout est `DOWN` | ICMP bloqué par un pare-feu, ou mauvais réseau |
| Accents mal affichés | Anciennes versions du script : utilise celle du repo (envoi UTF-8) |
