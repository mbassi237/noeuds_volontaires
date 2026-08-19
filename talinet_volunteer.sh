#1. Rejoindre le tailnet (une fois par machine)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --authkey=tskey-auth-kPnnLcg5ne11CNTRL-SZaNHYCTcUKfM1KjEjYpUK69vtcTHUbDF

#2. Vérifier la connexion au VPS
tailscale ping 100.91.21.29

#3. Lancer
docker compose pull
docker compose up -d
docker compose logs -f volunteer
