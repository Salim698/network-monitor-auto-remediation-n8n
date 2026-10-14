<#
.SYNOPSIS
    Scanner réseau pour le workflow n8n "Network Monitor".

.DESCRIPTION
    Teste une liste d'équipements (ping, port TCP, HTTP) et envoie le résultat
    en JSON au webhook n8n.

    Statuts produits :
      DOWN     : l'équipement ne répond pas au ping
      DEGRADED : il répond au ping mais le service (HTTP ou port) est KO
      UP       : tout répond

.PARAMETER Webhook
    URL du webhook n8n. Par défaut : variable d'environnement NET_MONITOR_WEBHOOK.

.PARAMETER Token
    Token optionnel envoyé dans le header X-Monitor-Token (Header Auth n8n).
    Par défaut : variable d'environnement NET_MONITOR_TOKEN.

.EXAMPLE
    .\net-scan.ps1 -Webhook "https://n8n.example.com/webhook/net-monitor"
#>

param(
    [string]$Webhook = $env:NET_MONITOR_WEBHOOK,
    [string]$Token   = $env:NET_MONITOR_TOKEN
)

# ================= CONFIG =================
$PingCount     = 2
$PortTimeoutMs = 1500
$HttpTimeout   = 3

if (-not $Webhook) {
    Write-Host "Webhook manquant : definis NET_MONITOR_WEBHOOK ou utilise -Webhook" -ForegroundColor Red
    exit 1
}

# ================= DEVICES =================
# ip      : adresse de l'equipement (cle de correspondance avec la serviceMap n8n)
# name    : nom affiche dans les alertes
# port    : port TCP teste (0 pour ne pas tester)
# httpUrl : URL testee en HTTP ($null pour ne pas tester)
$Equipements = @(
    @{ ip="192.168.1.1";  name="Routeur";        port=80; httpUrl="http://192.168.1.1" },
    @{ ip="192.168.1.50"; name="Serveur Linux";  port=80; httpUrl="http://192.168.1.50" },
    @{ ip="192.168.1.2";  name="Switch";         port=80; httpUrl=$null },
    @{ ip="8.8.8.8";      name="Google DNS";     port=53; httpUrl=$null },
    @{ ip="1.1.1.1";      name="Cloudflare DNS"; port=53; httpUrl=$null }
)

# ================= FUNCTIONS =================

function Test-Port {
    param($ip, $port)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $res = $tcp.BeginConnect($ip, $port, $null, $null)
        $ok  = $res.AsyncWaitHandle.WaitOne($PortTimeoutMs, $false)
        $tcp.Close()
        return $ok
    } catch { return $false }
}

function Test-Http {
    param($url)
    try {
        Invoke-WebRequest -Uri $url -TimeoutSec $HttpTimeout -UseBasicParsing -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
}

function Test-Device {
    param($d)

    $ping = Test-Connection $d.ip -Count $PingCount -Quiet
    if (-not $ping) {
        return @{ status="DOWN"; httpOK=$false; portOK=$false }
    }

    $portOK = if ($d.port -gt 0) { Test-Port $d.ip $d.port } else { $true }
    $httpOK = if ($d.httpUrl) { Test-Http $d.httpUrl } else { $null }

    if ($d.httpUrl) {
        $status = if ($httpOK) { "UP" } else { "DEGRADED" }
    } else {
        $status = if ($portOK) { "UP" } else { "DEGRADED" }
    }

    return @{
        status = $status
        httpOK = $httpOK
        portOK = $portOK
    }
}

# ================= MAIN =================

$results = @()

Write-Host ""
Write-Host "===== NETWORK MONITOR =====" -ForegroundColor Cyan

foreach ($d in $Equipements) {

    $r = Test-Device $d

    $color = switch ($r.status) {
        "UP"       { "Green" }
        "DEGRADED" { "Yellow" }
        "DOWN"     { "Red" }
    }

    Write-Host "$($d.name) [$($d.ip)] -> $($r.status)" -ForegroundColor $color

    $results += @{
        ip     = $d.ip
        name   = $d.name
        status = $r.status
        httpOK = $r.httpOK
        portOK = $r.portOK
    }
}

# ================= SUMMARY =================

$downList = $results | Where-Object { $_["status"] -eq "DOWN" }
$down     = @($downList).Count
$degList  = $results | Where-Object { $_["status"] -eq "DEGRADED" }
$deg      = @($degList).Count

$severity = if ($down -gt 0) { "WARNING" }
            elseif ($deg -gt 0) { "DEGRADED" }
            else { "OK" }

Write-Host ""
Write-Host "DOWN:$down DEG:$deg => $severity" -ForegroundColor Cyan

# ================= SEND TO N8N =================

$body = @{
    timestamp     = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    severity      = $severity
    downCount     = $down
    degradedCount = $deg
    devices       = $results
} | ConvertTo-Json -Depth 5

$bytes   = [System.Text.Encoding]::UTF8.GetBytes($body)
$headers = @{}
if ($Token) { $headers["X-Monitor-Token"] = $Token }

try {
    Invoke-RestMethod -Method POST -Uri $Webhook -Body $bytes `
        -ContentType "application/json; charset=utf-8" `
        -Headers $headers -TimeoutSec 15 | Out-Null
    Write-Host "Envoye a n8n OK" -ForegroundColor Green
} catch {
    Write-Host "Erreur envoi n8n : $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
