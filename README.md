# Nœuds Volontaires — Guide de démarrage

Ce dépôt permet à un·e volontaire de mettre à disposition son PC comme nœud de calcul pour une expérience d'apprentissage distribué, via Docker. Aucune installation permanente n'est faite sur votre système : tout tourne dans un conteneur.

## Prérequis

- **Docker** installé et démarré sur votre machine (voir [Étape 1](#étape-1--installer-docker)).
- **Git** installé, pour cloner le dépôt.
- Sous **Windows** : un terminal capable d'exécuter un script `.sh`, par exemple **WSL2** (recommandé) ou **Git Bash**.

---

## Étape 1 — Installer Docker

#### Windows

1. Installez [WSL2](https://learn.microsoft.com/fr-fr/windows/wsl/install) si ce n'est pas déjà fait (`wsl --install` dans un PowerShell administrateur, puis redémarrez).
2. Installez [Docker Desktop](https://www.docker.com/products/docker-desktop/) et, lors de l'installation, activez l'intégration WSL2.
3. Lancez Docker Desktop et vérifiez qu'il tourne (icône dans la barre des tâches).
4. Ouvrez un terminal **WSL2** (ou Git Bash) pour la suite des étapes.

#### Linux

Suivez la documentation officielle pour votre distribution : [docs.docker.com/engine/install](https://docs.docker.com/engine/install/).

Vérifiez ensuite que Docker fonctionne sans `sudo` (facultatif mais pratique) :

```bash
sudo usermod -aG docker $USER
```

Puis déconnectez-vous/reconnectez-vous (ou redémarrez la session).

#### Vérification (Windows et Linux)

```bash
docker --version
docker compose version
```

Les deux commandes doivent afficher un numéro de version sans erreur.

---

## Étape 2 — Cloner le dépôt

```bash
git clone git@github.com:mbassi237/noeuds_volontaires.git
cd noeuds_volontaires
```

(Si vous n'avez pas de clé SSH configurée sur GitHub, utilisez plutôt `https://github.com/mbassi237/noeuds_volontaires.git`.)

---

## Étape 3 — Configurer le fichier `.env`

Le fichier `.env` est déjà présent dans le dépôt. **Avant de lancer quoi que ce soit**, ouvrez-le et renseignez les valeurs qui vous seront communiquées le jour de l'expérience :

```bash
nano .env
```

Valeurs à adapter :

| Variable | Description |
|---|---|
| `VOLUNTEER_ID` | Identifiant unique qui vous sera attribué pour l'expérience |
| `N_VOLUNTEERS` | Nombre total de volontaires participant à l'expérience |
| `CPU_CORES` | Nombre de cœurs CPU que vous acceptez d'allouer |
| `RAM_GB` | Quantité de RAM (en Go) que vous acceptez d'allouer |
| `NETWORK_MBPS` | Bande passante réseau estimée que vous acceptez d'allouer |

Les autres variables (`COORDINATOR_HOST`, `MANAGER_HOST`, `DATASET`, etc.) sont normalement déjà correctement pré-configurées — ne les modifiez que si on vous le demande explicitement.

La variable `TAILSCALE_AUTHKEY` doit également être renseignée : c'est la clé qui permet au **conteneur** de rejoindre automatiquement le tailnet de l'expérience (VPN reliant votre PC au serveur central). Elle vous sera communiquée avec les autres valeurs.

---

## Étape 4 — Lancer le nœud volontaire

Une fois le `.env` configuré, exécutez le script de lancement :

```bash
chmod +x talinet_volunteer.sh
./talinet_volunteer.sh
```

Ce script va, dans l'ordre :

1. Télécharger (ou construire) l'image Docker du volontaire.
2. Démarrer le conteneur (`docker compose up -d`), qui rejoint lui-même le tailnet de l'expérience au démarrage grâce à `TAILSCALE_AUTHKEY` — aucune installation ni configuration réseau sur votre machine n'est nécessaire, y compris sous Windows/macOS.
3. Afficher les logs du conteneur en direct.

Laissez ce terminal ouvert pour continuer à suivre les logs, ou fermez-le : le conteneur continue de tourner en arrière-plan.

> Le conteneur a besoin d'un accès `/dev/net/tun` et de la capacité `NET_ADMIN` (déjà déclarés dans `docker-compose.yml`) pour établir sa propre connexion Tailscale — c'est normal et attendu, aucune action de votre part n'est requise au-delà de démarrer Docker.

---

## Vérifier que tout fonctionne

```bash
docker compose ps
docker compose logs -f
```

Les résultats/statistiques de l'expérience sont sauvegardés localement dans le dossier `./results`.

---

## Arrêter le nœud

```bash
docker compose down
```

## Désinstaller complètement

Pour tout supprimer (conteneurs, images, résultats, `.env`) :

```bash
./uninstall_volunteer.sh
```

Voir [VOLUNTEER_README.md](VOLUNTEER_README.md) pour plus de détails sur ce que fait exactement ce script.

---

## Résumé rapide

```bash
# 1. Installer Docker (voir ci-dessus selon votre OS)

# 2. Cloner et se placer dans le dépôt
git clone git@github.com:mbassi237/noeuds_volontaires.git
cd noeuds_volontaires

# 3. Éditer .env avec les valeurs communiquées le jour de l'expérience
nano .env

# 4. Lancer le volontaire
chmod +x talinet_volunteer.sh
./talinet_volunteer.sh
```
