# Installation et configuration

## Prérequis

- n8n (self-hosted, Docker recommandé)
- Un serveur Linux (VM VMware, Ubuntu/Debian) avec Apache2, Nginx et/ou MySQL
- Un poste Windows avec PowerShell pour le script de scan
- Un compte Telegram
- Connectivité réseau entre n8n et la VM (mode bridged ou NAT avec redirection selon ta config VMware)

## 1. Préparer la VM Linux

**Installer le serveur SSH**

```bash
sudo apt update && sudo apt install -y openssh-server
sudo systemctl enable --now ssh
```

**Créer un utilisateur dédié** (ne pas utiliser root)

```bash
sudo adduser n8n-monitor
```

**Limiter ses droits `sudo`** aux seuls redémarrages nécessaires :

```bash
sudo visudo -f /etc/sudoers.d/n8n-monitor
```

```
n8n-monitor ALL=(root) NOPASSWD: /usr/bin/systemctl restart apache2, /usr/bin/systemctl restart nginx, /usr/bin/systemctl restart mysql
```

Vérifie le chemin de `systemctl` avec `which systemctl`.

**Tester depuis la machine qui héberge n8n**

```bash
ssh n8n-monitor@192.168.1.50 "sudo systemctl restart apache2 && echo OK"
```

## 2. Bot Telegram

1. Ouvre Telegram, cherche **@BotFather**, envoie `/newbot` et suis les étapes
2. Note le **token** du bot (ne le publie jamais)
3. Envoie un message à ton bot, puis ouvre `https://api.telegram.org/bot<TOKEN>/getUpdates`
4. Récupère `chat.id` dans la réponse : c'est ton `chat_id`

## 3. Credentials n8n

| Credential | Utilisation |
|---|---|
| SSH (mot de passe ou clé privée) | Nœud `SSH - Auto-remédiation ciblée` : hôte, port, utilisateur `n8n-monitor` |
| Telegram API | Nœuds `Telegram - Alerte panne confirmée` et `Telegram - Anomalie détectée (cycle 1)` |

Préfère l'authentification par **clé SSH** au mot de passe.

## 4. Import et configuration

1. n8n > **Workflows > Import from file** > `workflow.json`
2. Dans les 2 nœuds Telegram : remplace `YOUR_TELEGRAM_CHAT_ID` et sélectionne le credential
3. Dans le nœud SSH : sélectionne le credential
4. Dans `Code - Analyse & Service Map` : adapte la `serviceMap`
   - Clés : adresses IP des équipements surveillés
   - `type` : doit correspondre à la liste `TYPES_EXCLUS` du garde-fou si l'équipement ne doit jamais être redémarré
   - `sshCmd` : `null` pour les équipements sans remédiation

## 5. Activer le workflow

Active le workflow (interrupteur en haut à droite). C'est **obligatoire** : le compteur de pannes consécutives utilise `$getWorkflowStaticData`, qui ne persiste qu'en exécution de production, pas en test manuel.

## 6. Brancher le script PowerShell

Le script de scan doit envoyer un `POST` JSON toutes les 5 minutes (Planificateur de tâches Windows) vers :

- Production : `https://<ton-n8n>/webhook/net-monitor`
- Test : `https://<ton-n8n>/webhook-test/net-monitor`

Format attendu : [payload-format.md](payload-format.md).

Si PowerShell et n8n sont sur le même réseau local, aucun tunnel n'est nécessaire. N'expose jamais le webhook sur Internet sans authentification.

## Dépannage

| Symptôme | Cause probable |
|---|---|
| Aucune alerte de panne confirmée | Workflow non activé, ou un seul cycle reçu |
| SSH : connexion refusée | Service SSH arrêté, mauvais port ou pare-feu |
| `sudo: a password is required` | Règle `sudoers` absente ou chemin de `systemctl` incorrect |
| Pas de message Telegram | `chatId` incorrect ou bot jamais contacté |
| Endpoint de statut vide | Aucun payload reçu depuis l'activation |
