# Logique du garde-fou

La décision de redémarrer un service est prise par des **règles déterministes**, sans IA, pour rester prévisible et auditable.

## Les 3 conditions (toutes obligatoires)

1. `status` vaut `DOWN` ou `DEGRADED`
2. `httpOK` vaut `false` (le service est réellement injoignable en HTTP)
3. Le type d'équipement n'est **pas** dans la liste exclue

À cela s'ajoute la **confirmation sur 2 cycles consécutifs** (nœud `Code - Confirmation + Compteur ≥2 cycles`).

## Types jamais redémarrés automatiquement

`Routeur`, `Routeur WiFi`, `Mikrotik`, `Access Point`, `Switch`, `DNS Google`, `DNS Cloudflare`, `Imprimante`, `Telephone`, `Inconnu`

Un équipement absent de la `serviceMap` reçoit le type `Inconnu` : il n'est donc jamais redémarré.

## Table de décision

| Cas | Cycles | Résultat |
|---|---|---|
| Équipement UP | n/a | Compteur remis à 0, rien |
| Panne détectée, 1er cycle | 1 | Telegram "anomalie cycle 1" |
| Panne confirmée, type exclu (routeur, switch...) | ≥ 2 | Telegram, pas de SSH |
| Panne confirmée, HTTP encore OK | ≥ 2 | Telegram, pas de SSH |
| Panne confirmée, serveur Linux, `httpOK=false` | ≥ 2 | **SSH restart ciblé** + Telegram |

## Remédiation sur le serveur Linux

Le script exécuté par SSH suit cet ordre :

1. **Diagnostic** : occupation disque et RAM (alerte si disque > 85 %)
2. **Pour chacun de Apache2, Nginx, MySQL** : si le service existe et n'est pas actif, `restart`, puis vérification de l'état
3. **Bilan** sur une ligne : `BILAN_APACHE:...|BILAN_NGINX:...|BILAN_MYSQL:...`

Un service déjà actif n'est jamais redémarré.
