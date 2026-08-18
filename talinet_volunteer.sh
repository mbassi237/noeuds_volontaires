#!/usr/bin/env bash
#
# Installation et demarrage d'un volontaire, sur Linux.
#
# Ce script prepare la machine puis la rattache a l'experimentation :
#   A. verification du systeme
#   B. installation de Git, Docker et Tailscale si absents
#   C. rattachement au reseau prive (etape 1 d'origine)
#   D. verification de la liaison avec le serveur (etape 2 d'origine)
#   E. demarrage du conteneur volontaire (etape 3 d'origine)
#
# Il ne reinstalle jamais ce qui est deja present et peut donc etre relance
# sans risque.
#
# Utilisation :
#     bash talinet_volunteer.sh
#
# Sous Windows, utiliser talinet_volunteer.ps1 dans PowerShell administrateur.

set -uo pipefail

CLE_TAILSCALE="${TAILSCALE_AUTHKEY:-tskey-auth-kPnnLcg5ne11CNTRL-SZaNHYCTcUKfM1KjEjYpUK69vtcTHUbDF}"
SERVEUR="${COORDINATOR_HOST:-100.91.21.29}"

etape()   { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()      { printf '    \033[0;32m[OK]\033[0m %s\n' "$*"; }
info()    { printf '    %s\n' "$*"; }
avert()   { printf '    \033[0;33m[ATTENTION]\033[0m %s\n' "$*"; }
echec()   { printf '\n\033[0;31m[ECHEC]\033[0m %s\n\n' "$*"; exit 1; }

# ── A. Verification du systeme ─────────────────────────────────────────────

etape "A. Verification du systeme"

case "$(uname -s)" in
    Linux)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            echec "Vous etes dans WSL (Linux sous Windows).
    Sur Windows, l'installation doit se faire depuis PowerShell en
    administrateur, avec le script talinet_volunteer.ps1.
    Fermez cette fenetre et suivez la procedure Windows."
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        echec "Vous etes sous Windows, dans un terminal de type Git Bash.
    Ce script ne convient pas. Ouvrez PowerShell EN ADMINISTRATEUR
    (clic droit sur le menu Demarrer, « Terminal (admin) ») puis lancez :
        .\\talinet_volunteer.ps1"
        ;;
    Darwin)
        echec "macOS n'est pas pris en charge par ce script."
        ;;
    *)
        echec "Systeme non reconnu : $(uname -s)"
        ;;
esac

if [ -r /etc/os-release ]; then
    . /etc/os-release
    info "Systeme : ${PRETTY_NAME:-Linux}"
else
    info "Systeme : Linux (distribution non identifiee)"
fi

if [ "$(uname -m)" != "x86_64" ]; then
    avert "Architecture $(uname -m). L'image du volontaire est prevue pour x86_64."
fi

# Gestionnaire de paquets
if   command -v apt-get >/dev/null 2>&1; then GEST=apt
elif command -v dnf     >/dev/null 2>&1; then GEST=dnf
elif command -v yum     >/dev/null 2>&1; then GEST=yum
elif command -v pacman  >/dev/null 2>&1; then GEST=pacman
elif command -v zypper  >/dev/null 2>&1; then GEST=zypper
else echec "Aucun gestionnaire de paquets reconnu (apt, dnf, yum, pacman, zypper)."
fi
info "Gestionnaire de paquets : $GEST"

# Droits d'administration
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
    info "Execution en tant que root"
else
    command -v sudo >/dev/null 2>&1 || echec "sudo est introuvable et vous n'etes pas root."
    SUDO="sudo"
    info "Le mot de passe administrateur vous sera demande"
    sudo -v || echec "Droits administrateur refuses. L'installation ne peut pas continuer."
fi

# Connexion Internet, indispensable a l'installation
if ! curl -fsS --max-time 10 https://tailscale.com >/dev/null 2>&1; then
    echec "Pas d'acces Internet. Il est necessaire pour telecharger Docker et Tailscale."
fi
ok "Systeme compatible"

installer_paquet() {
    case "$GEST" in
        apt)    $SUDO apt-get update -qq && $SUDO apt-get install -y -qq "$@" ;;
        dnf)    $SUDO dnf install -y -q "$@" ;;
        yum)    $SUDO yum install -y -q "$@" ;;
        pacman) $SUDO pacman -Sy --noconfirm --quiet "$@" ;;
        zypper) $SUDO zypper --non-interactive --quiet install "$@" ;;
    esac
}

# ── B. Installation des outils ─────────────────────────────────────────────

etape "B. Installation des outils requis"

# --- Git ---
if command -v git >/dev/null 2>&1; then
    ok "Git deja installe ($(git --version | awk '{print $3}'))"
else
    info "Installation de Git..."
    installer_paquet git || echec "L'installation de Git a echoue."
    ok "Git installe"
fi

# --- Docker ---
if command -v docker >/dev/null 2>&1; then
    ok "Docker deja installe ($(docker --version | awk '{print $3}' | tr -d ,))"
else
    info "Installation de Docker, cette etape prend quelques minutes..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh || echec "Telechargement de Docker impossible."
    $SUDO sh /tmp/get-docker.sh >/dev/null 2>&1 || echec "L'installation de Docker a echoue."
    rm -f /tmp/get-docker.sh
    ok "Docker installe"
fi

# Greffon compose, absent de certaines distributions
if ! docker compose version >/dev/null 2>&1; then
    info "Installation du greffon docker compose..."
    case "$GEST" in
        apt) installer_paquet docker-compose-plugin ;;
        *)   installer_paquet docker-compose-plugin || avert "Greffon compose non installe automatiquement." ;;
    esac
fi
docker compose version >/dev/null 2>&1 \
    && ok "docker compose disponible" \
    || echec "docker compose reste indisponible. Installez le greffon manuellement."

# --- Service Docker : demarre et actif au prochain allumage ---
if command -v systemctl >/dev/null 2>&1; then
    $SUDO systemctl enable docker >/dev/null 2>&1
    $SUDO systemctl start  docker >/dev/null 2>&1
    if systemctl is-active --quiet docker; then
        ok "Service Docker demarre et active au demarrage de la machine"
    else
        echec "Le service Docker refuse de demarrer. Verifiez : systemctl status docker"
    fi
else
    $SUDO service docker start >/dev/null 2>&1 || true
fi

# --- Utilisateur dans le groupe docker : evite d'avoir a taper sudo ---
BESOIN_RECONNEXION=0
if [ "$(id -u)" -ne 0 ] && ! id -nG "$USER" | grep -qw docker; then
    $SUDO usermod -aG docker "$USER" && BESOIN_RECONNEXION=1
    ok "Utilisateur $USER ajoute au groupe docker"
fi

# --- Tailscale ---
if command -v tailscale >/dev/null 2>&1; then
    ok "Tailscale deja installe"
else
    info "Installation de Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | $SUDO sh >/dev/null 2>&1 \
        || echec "L'installation de Tailscale a echoue."
    ok "Tailscale installe"
fi

# ── C. Rattachement au reseau prive (etape 1 d'origine) ────────────────────

etape "C. Rattachement au reseau prive"

if tailscale status >/dev/null 2>&1; then
    ok "Machine deja rattachee au reseau"
else
    $SUDO tailscale up --authkey="$CLE_TAILSCALE" \
        || echec "Le rattachement au reseau a echoue. La cle est peut-etre expiree."
    ok "Machine rattachee"
fi
info "Adresse sur le reseau prive : $(tailscale ip -4 2>/dev/null | head -1)"

# ── D. Verification de la liaison (etape 2 d'origine) ──────────────────────

etape "D. Verification de la liaison avec le serveur"

if $SUDO tailscale ping -c 3 "$SERVEUR" >/dev/null 2>&1; then
    ok "Serveur $SERVEUR joignable"
else
    avert "Le serveur $SERVEUR ne repond pas encore."
    avert "L'entrainement demarrera des qu'il sera de nouveau accessible."
fi

# ── E. Demarrage du volontaire (etape 3 d'origine) ─────────────────────────

etape "E. Demarrage du volontaire"

[ -f docker-compose.yml ] || echec "Fichier docker-compose.yml introuvable.
    Placez-vous dans le dossier du projet avant de lancer ce script."

# Le groupe docker n'est pris en compte qu'a la prochaine session : on
# contourne pour cette execution afin d'eviter une deconnexion inutile.
if [ "$BESOIN_RECONNEXION" -eq 1 ]; then
    LANCEUR="sg docker -c"
else
    LANCEUR="bash -c"
fi

info "Telechargement de l'image, plusieurs minutes selon la connexion..."
$LANCEUR "docker compose pull" || echec "Le telechargement de l'image a echoue."

info "Demarrage du conteneur..."
$LANCEUR "docker compose up -d" || echec "Le demarrage du conteneur a echoue."
ok "Volontaire demarre"

printf '\n\033[1;32m%s\033[0m\n' "Installation terminee."
info "Cette machine participera automatiquement a la prochaine experience."
info "Le conteneur redemarre seul si la machine est eteinte puis rallumee."
if [ "$BESOIN_RECONNEXION" -eq 1 ]; then
    avert "Deconnectez puis reconnectez votre session pour utiliser docker sans sudo."
fi
printf '\n'
info "Pour suivre l'activite :   docker compose logs -f volunteer"
info "Pour arreter :             docker compose down"
printf '\n'

# Affichage des journaux, interruption par Ctrl+C sans consequence
$LANCEUR "docker compose logs -f volunteer"
