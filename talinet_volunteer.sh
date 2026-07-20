#!/bin/bash
set -euo pipefail

# Le conteneur volontaire rejoint désormais le tailnet lui-même
# (TAILSCALE_AUTHKEY dans .env), donc plus besoin d'installer/joindre
# Tailscale sur l'hôte ici : fonctionne identiquement sur Linux/Windows/macOS.

if ! grep -q '^TAILSCALE_AUTHKEY=.\+' .env 2>/dev/null; then
    echo "Erreur : TAILSCALE_AUTHKEY manquant dans .env" >&2
    exit 1
fi

docker compose pull
docker compose up -d
docker compose logs -f volunteer
