<#
    Installation et demarrage d'un volontaire, sur Windows 10 version 22H2
    ou superieure.

    Ce script prepare la machine puis la rattache a l'experimentation :
      A. verification du systeme
      B. activation de WSL2, installation de Git, Docker Desktop, Tailscale
      C. rattachement au reseau prive
      D. verification de la liaison avec le serveur
      E. demarrage du conteneur volontaire

    Il ne reinstalle jamais ce qui est deja present et peut donc etre
    relance sans risque.

    UTILISATION
      1. Clic droit sur le menu Demarrer, choisir « Terminal (admin) »
         ou « Windows PowerShell (admin) ».
      2. Se placer dans le dossier du projet :   cd C:\chemin\du\projet
      3. Autoriser l'execution une seule fois :
             Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
      4. Lancer :   .\talinet_volunteer.ps1

    Un redemarrage peut etre demande apres l'activation de WSL2. Relancer
    alors le script : il reprendra ou il s'etait arrete.
#>

$ErrorActionPreference = "Stop"

$CleTailscale = if ($env:TAILSCALE_AUTHKEY) { $env:TAILSCALE_AUTHKEY }
                else { "tskey-auth-kPnnLcg5ne11CNTRL-SZaNHYCTcUKfM1KjEjYpUK69vtcTHUbDF" }
$Serveur = if ($env:COORDINATOR_HOST) { $env:COORDINATOR_HOST } else { "100.91.21.29" }

function Etape($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)    { Write-Host "    [OK] $m" -ForegroundColor Green }
function Info($m)  { Write-Host "    $m" }
function Avert($m) { Write-Host "    [ATTENTION] $m" -ForegroundColor Yellow }
function Echec($m) { Write-Host "`n[ECHEC] $m`n" -ForegroundColor Red; exit 1 }

function Presente($cmd) {
    $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

# ── A. Verification du systeme ─────────────────────────────────────────────

Etape "A. Verification du systeme"

$identite = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identite)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Echec "Ce script doit etre lance en administrateur.
    Fermez cette fenetre, faites un clic droit sur le menu Demarrer,
    choisissez « Terminal (admin) », puis relancez."
}
Ok "Droits administrateur confirmes"

$os = Get-CimInstance Win32_OperatingSystem
$build = [int]$os.BuildNumber
Info "Systeme : $($os.Caption) (build $build)"

if ($build -lt 19041) {
    Echec "Windows build $build detecte. La version 2004 (build 19041) est le
    minimum requis pour WSL2 et Docker Desktop. Windows 10 22H2 correspond
    au build 19045. Mettez le systeme a jour avant de continuer."
}
Ok "Version de Windows compatible"

if ((Get-CimInstance Win32_ComputerSystem).SystemType -notmatch "x64") {
    Echec "Processeur non 64 bits. L'image du volontaire ne peut pas fonctionner."
}

# La virtualisation materielle conditionne WSL2
$virtu = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
if (-not $virtu) {
    Avert "La virtualisation ne semble pas active."
    Avert "Si l'installation echoue plus loin, activez VT-x (Intel) ou SVM (AMD)"
    Avert "dans le BIOS de la machine."
} else {
    Ok "Virtualisation active"
}

# Espace disque
$libre = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
Info "Espace libre sur C: : $libre Go"
if ($libre -lt 12) {
    Echec "Au moins 12 Go libres sont necessaires (Docker Desktop et l'image du volontaire)."
}

# Connexion Internet
try {
    Invoke-WebRequest -Uri "https://tailscale.com" -UseBasicParsing -TimeoutSec 10 | Out-Null
    Ok "Connexion Internet disponible"
} catch {
    Echec "Pas d'acces Internet. Il est necessaire pour telecharger les outils."
}

$winget = Presente "winget"
if ($winget) { Ok "winget disponible" }
else { Avert "winget absent : les installations passeront par telechargement direct." }

# ── B. Installation des outils ─────────────────────────────────────────────

Etape "B. Installation des outils requis"

# --- WSL2 ---
$wslPret = $false
if (Presente "wsl") {
    $sortie = (wsl --status) 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) { $wslPret = $true }
}

if ($wslPret) {
    Ok "WSL2 deja installe"
} else {
    Info "Activation de WSL2, cette etape peut demander un redemarrage..."
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
    try { wsl --install --no-distribution 2>&1 | Out-Null } catch { }
    try { wsl --set-default-version 2 2>&1 | Out-Null } catch { }

    Write-Host ""
    Avert "REDEMARRAGE NECESSAIRE pour terminer l'activation de WSL2."
    Avert "Redemarrez la machine, puis relancez ce script : il reprendra ici."
    Write-Host ""
    $rep = Read-Host "    Redemarrer maintenant ? (O/N)"
    if ($rep -match '^[OoYy]') { Restart-Computer -Force }
    exit 0
}

# --- Git ---
if (Presente "git") {
    Ok "Git deja installe"
} elseif ($winget) {
    Info "Installation de Git..."
    winget install --id Git.Git -e --source winget `
        --accept-package-agreements --accept-source-agreements --silent | Out-Null
    Ok "Git installe"
} else {
    Avert "Git absent et winget indisponible."
    Avert "Installez Git manuellement depuis https://git-scm.com/download/win"
}

# --- Docker Desktop ---
$dockerInstalle = Presente "docker"
if (-not $dockerInstalle) {
    $chemin = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    $dockerInstalle = Test-Path $chemin
}

if ($dockerInstalle) {
    Ok "Docker Desktop deja installe"
} else {
    Info "Installation de Docker Desktop, comptez plusieurs minutes..."
    if ($winget) {
        winget install --id Docker.DockerDesktop -e --source winget `
            --accept-package-agreements --accept-source-agreements --silent | Out-Null
    } else {
        $inst = "$env:TEMP\DockerDesktopInstaller.exe"
        Invoke-WebRequest -Uri "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" `
            -OutFile $inst -UseBasicParsing
        Start-Process -FilePath $inst -ArgumentList "install","--quiet","--accept-license" -Wait
        Remove-Item $inst -ErrorAction SilentlyContinue
    }
    Ok "Docker Desktop installe"
    Avert "Une session Windows doit parfois etre rouverte pour que la commande"
    Avert "docker soit reconnue. Si l'etape suivante echoue, deconnectez-vous"
    Avert "puis reconnectez-vous et relancez ce script."
}

# --- Demarrage de Docker Desktop et attente du moteur ---
Info "Demarrage du moteur Docker..."
$exe = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
if ((Test-Path $exe) -and -not (Get-Process "Docker Desktop" -ErrorAction SilentlyContinue)) {
    Start-Process $exe | Out-Null
}

$pret = $false
foreach ($i in 1..60) {
    Start-Sleep -Seconds 5
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $pret = $true; break }
    if ($i % 6 -eq 0) { Info "  toujours en cours de demarrage... ($($i*5) s)" }
}
if ($pret) { Ok "Moteur Docker operationnel" }
else {
    Echec "Le moteur Docker n'a pas demarre en 5 minutes.
    Ouvrez Docker Desktop manuellement, attendez que la baleine cesse de
    s'animer, choisissez « Continue without signing in » si la connexion
    est proposee, puis relancez ce script."
}

# --- Docker Desktop au demarrage de Windows ---
$cle = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
if (-not (Get-ItemProperty -Path $cle -Name "Docker Desktop" -ErrorAction SilentlyContinue)) {
    if (Test-Path $exe) {
        Set-ItemProperty -Path $cle -Name "Docker Desktop" -Value "`"$exe`""
        Ok "Docker Desktop demarrera automatiquement avec Windows"
    }
}

# --- Tailscale ---
if (Presente "tailscale") {
    Ok "Tailscale deja installe"
} elseif ($winget) {
    Info "Installation de Tailscale..."
    winget install --id tailscale.tailscale -e --source winget `
        --accept-package-agreements --accept-source-agreements --silent | Out-Null
    $env:Path += ";$env:ProgramFiles\Tailscale"
    Ok "Tailscale installe"
} else {
    $inst = "$env:TEMP\tailscale-setup.exe"
    Invoke-WebRequest -Uri "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe" `
        -OutFile $inst -UseBasicParsing
    Start-Process -FilePath $inst -ArgumentList "/S" -Wait
    Remove-Item $inst -ErrorAction SilentlyContinue
    $env:Path += ";$env:ProgramFiles\Tailscale"
    Ok "Tailscale installe"
}

# ── C. Rattachement au reseau prive ────────────────────────────────────────

Etape "C. Rattachement au reseau prive"

$ts = "$env:ProgramFiles\Tailscale\tailscale.exe"
if (-not (Test-Path $ts)) { $ts = "tailscale" }

& $ts status 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Ok "Machine deja rattachee au reseau"
} else {
    & $ts up --authkey=$CleTailscale
    if ($LASTEXITCODE -ne 0) {
        Echec "Le rattachement au reseau a echoue. La cle est peut-etre expiree."
    }
    Ok "Machine rattachee"
}
$adresse = (& $ts ip -4 2>$null | Select-Object -First 1)
Info "Adresse sur le reseau prive : $adresse"

# ── D. Verification de la liaison ──────────────────────────────────────────

Etape "D. Verification de la liaison avec le serveur"

& $ts ping -c 3 $Serveur 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Ok "Serveur $Serveur joignable"
} else {
    Avert "Le serveur $Serveur ne repond pas encore."
    Avert "L'entrainement demarrera des qu'il sera de nouveau accessible."
}

# ── E. Demarrage du volontaire ─────────────────────────────────────────────

Etape "E. Demarrage du volontaire"

if (-not (Test-Path "docker-compose.yml")) {
    Echec "Fichier docker-compose.yml introuvable dans $PWD.
    Placez-vous dans le dossier du projet avant de lancer ce script :
        cd C:\chemin\du\projet"
}

Info "Telechargement de l'image, plusieurs minutes selon la connexion..."
docker compose pull
if ($LASTEXITCODE -ne 0) { Echec "Le telechargement de l'image a echoue." }

Info "Demarrage du conteneur..."
docker compose up -d
if ($LASTEXITCODE -ne 0) { Echec "Le demarrage du conteneur a echoue." }
Ok "Volontaire demarre"

Write-Host "`nInstallation terminee." -ForegroundColor Green
Info "Cette machine participera automatiquement a la prochaine experience."
Info "Le conteneur redemarre seul si la machine est eteinte puis rallumee."
Write-Host ""
Info "Pour suivre l'activite :   docker compose logs -f volunteer"
Info "Pour arreter :             docker compose down"
Write-Host ""

docker compose logs -f volunteer
