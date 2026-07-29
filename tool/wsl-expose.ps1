#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Expone el servidor de desarrollo que corre en WSL2 a la red local, para
    poder abrir el portal desde el celular.

.DESCRIPTION
    WSL2 vive detras de NAT con una IP propia (172.28.x.x) que NO es alcanzable
    desde la LAN, asi que aunque `flutter run` escuche en 0.0.0.0 el celular no
    llega. Este script crea un portproxy en Windows que reenvia
    <IP-de-Windows>:PUERTO -> <IP-de-WSL>:PUERTO, y abre el puerto en el
    firewall.

    La IP de WSL CAMBIA en cada reinicio, por eso el script la detecta sola en
    lugar de recibirla como parametro: se vuelve a ejecutar y listo.

.PARAMETER Port
    Puerto a exponer. Default 5000 (el de tool/dev.sh).

.PARAMETER Remove
    Quita el portproxy y la regla de firewall.

.PARAMETER Status
    Solo muestra el estado actual, sin cambiar nada.

.EXAMPLE
    # PowerShell COMO ADMINISTRADOR:
    powershell -ExecutionPolicy Bypass -File \\wsl.localhost\archlinux\home\eddy\sozu\sozu-cliente-app\tool\wsl-expose.ps1

.EXAMPLE
    # Otro puerto
    .\wsl-expose.ps1 -Port 5100

.EXAMPLE
    # Limpiar al terminar
    .\wsl-expose.ps1 -Remove
#>
[CmdletBinding()]
param(
    [int]$Port = 5000,
    [switch]$Remove,
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
$RuleName = "SOZU dev $Port (WSL)"

function Get-WslIp {
    # `hostname -I` no sirve: en Arch WSL el binario `hostname` no viene
    # instalado. `ip` si esta siempre.
    $raw = (wsl.exe -- ip -4 -o addr show eth0) -join "`n"
    if ($raw -match 'inet\s+([\d.]+)/') { return $Matches[1] }
    throw "No pude leer la IP de WSL. Esta corriendo WSL? Proba: wsl -- ip -4 -o addr show eth0"
}

function Get-LanIps {
    Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.InterfaceAlias -notmatch 'WSL|vEthernet|Loopback'
        } |
        Select-Object -ExpandProperty IPAddress
}

function Show-Status {
    Write-Host ''
    Write-Host '--- portproxy activo ---' -ForegroundColor Cyan
    netsh interface portproxy show v4tov4
    Write-Host '--- regla de firewall ---' -ForegroundColor Cyan
    $rule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    if ($rule) {
        Write-Host "  OK: $RuleName ($($rule.Enabled))" -ForegroundColor Green
    } else {
        Write-Host "  no existe: $RuleName" -ForegroundColor DarkGray
    }
}

# --- Estado -----------------------------------------------------------------

if ($Status) {
    Show-Status
    exit 0
}

# --- Limpieza ---------------------------------------------------------------

if ($Remove) {
    Write-Host "Quitando portproxy del puerto $Port..." -ForegroundColor Yellow
    netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=0.0.0.0 2>&1 | Out-Null

    $rule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
    if ($rule) {
        Remove-NetFirewallRule -DisplayName $RuleName
        Write-Host "Regla de firewall eliminada." -ForegroundColor Yellow
    }
    Write-Host "Listo." -ForegroundColor Green
    exit 0
}

# --- Alta -------------------------------------------------------------------

# portproxy depende del servicio IP Helper. Si esta detenido, el reenvio se
# acepta pero no funciona (falla silencioso, dificil de diagnosticar).
$iphlp = Get-Service -Name iphlpsvc -ErrorAction SilentlyContinue
if ($iphlp -and $iphlp.Status -ne 'Running') {
    Write-Host "Iniciando servicio IP Helper (requerido por portproxy)..." -ForegroundColor Yellow
    Start-Service iphlpsvc
}

$wslIp = Get-WslIp
Write-Host "IP de WSL detectada: $wslIp" -ForegroundColor Cyan

# Idempotente: se borra la entrada previa (puede apuntar a una IP vieja) y se
# vuelve a crear. Sin esto, tras reiniciar WSL el portproxy queda apuntando a
# una IP muerta y el celular recibe timeouts.
netsh interface portproxy delete v4tov4 listenport=$Port listenaddress=0.0.0.0 2>&1 | Out-Null
netsh interface portproxy add v4tov4 `
    listenport=$Port listenaddress=0.0.0.0 `
    connectport=$Port connectaddress=$wslIp | Out-Null

if ($LASTEXITCODE -ne 0) { throw "netsh portproxy add fallo (codigo $LASTEXITCODE)" }
Write-Host "portproxy 0.0.0.0:$Port -> ${wslIp}:$Port" -ForegroundColor Green

if (-not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $RuleName `
        -Direction Inbound -Protocol TCP -LocalPort $Port `
        -Action Allow -Profile Private | Out-Null
    Write-Host "Regla de firewall creada (solo perfil Privado)." -ForegroundColor Green
} else {
    Write-Host "Regla de firewall ya existia." -ForegroundColor DarkGray
}

# --- Como abrirlo -----------------------------------------------------------

$lanIps = @(Get-LanIps)
Write-Host ''
Write-Host 'Abri esto en el celular (misma red Wi-Fi):' -ForegroundColor Cyan
if ($lanIps.Count -eq 0) {
    Write-Host '  No encontre una IP de LAN. Corre ipconfig y usa la IPv4 de tu Wi-Fi.' -ForegroundColor Yellow
} else {
    foreach ($ip in $lanIps) {
        Write-Host "  http://${ip}:$Port" -ForegroundColor White
    }
    if ($lanIps.Count -gt 1) {
        Write-Host '  (varias interfaces: proba la de tu Wi-Fi)' -ForegroundColor DarkGray
    }
}
Write-Host ''
Write-Host 'Recorda: ./tool/dev.sh debe estar corriendo en WSL.' -ForegroundColor DarkGray
Write-Host 'Si reinicias WSL o la PC, volve a correr este script (la IP cambia).' -ForegroundColor DarkGray
