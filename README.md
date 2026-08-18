# Nœuds Volontaires — Guide de démarrage

Ce dépôt permet à un·e volontaire de mettre à disposition son PC comme nœud de calcul pour une expérience d'apprentissage distribué, via Docker. Un script d'installation unique s'occupe de tout : installation des outils nécessaires (Docker, Git, Tailscale), rattachement au réseau privé de l'expérience et démarrage du conteneur. Le calcul lui-même tourne entièrement dans un conteneur, rien n'est installé en dehors de Docker et des outils listés ci-dessous.

## Prérequis

- **Windows 10 version 22H2 (build 19045) ou supérieur**, en **64 bits**, avec les droits **administrateur**,
  OU **Linux** (distribution avec `apt`, `dnf`, `yum`, `pacman` ou `zypper`) avec les droits `sudo`.
- Une connexion Internet, pour le téléchargement de Docker/Tailscale.
- macOS n'est pas pris en charge par les scripts d'installation.

Docker, Git, Tailscale (et WSL2 sous Windows) sont installés **automatiquement** par le script de l'étape 3 — aucune installation manuelle préalable n'est nécessaire.

---

## Étape 1 — Récupérer le dépôt

```bash
git clone git@github.com:mbassi237/noeuds_volontaires.git
cd noeuds_volontaires
```

(Si vous n'avez pas de clé SSH configurée sur GitHub, utilisez plutôt `https://github.com/mbassi237/noeuds_volontaires.git`.)

Si Git n'est pas encore installé sur votre machine, téléchargez plutôt le dépôt en `.zip` depuis GitHub (bouton **Code → Download ZIP**) et extrayez-le : le script d'installation installera Git pour vous à l'étape 3.

---

## Étape 2 — Le fichier `.env`

Le fichier `.env` est déjà présent dans le dépôt et **pré-rempli avec les valeurs de l'expérience en cours** (serveur, clé du réseau privé, etc.). Dans la plupart des cas, vous n'avez rien à y modifier.

Si les organisateurs vous demandent explicitement d'y ajuster une valeur :

```bash
nano .env
```

| Variable | Description |
|---|---|
| `COORDINATOR_HOST` / `MANAGER_HOST` | Adresse du serveur de l'expérience (déjà renseignée) |
| `TAILSCALE_AUTHKEY` | Clé permettant à votre machine et au conteneur de rejoindre le réseau privé de l'expérience (déjà renseignée) |
| `VOLUNTEER_ID` / `N_VOLUNTEERS` | Optionnels — laissez vides pour une attribution automatique par le coordinateur |
| `CPU_CORES` / `RAM_GB` / `NETWORK_MBPS` | Optionnels — indications de ressources allouées, à ne renseigner que si demandé |

Ne modifiez les autres variables que si cela vous est explicitement demandé.

---

## Étape 3 — Lancer le nœud volontaire

### Windows

Le plus simple : **double-cliquez sur [`Lancer-volontaire.bat`](Lancer-volontaire.bat)**, dans le dossier du projet.

Ce lanceur, sans rien à taper :

1. demande automatiquement les droits administrateur (acceptez la fenêtre qui s'ouvre),
2. débloque le script PowerShell (Windows bloque par défaut les scripts téléchargés),
3. lance [`talinet_volunteer.ps1`](talinet_volunteer.ps1).

Alternative en ligne de commande : ouvrez un **Terminal/PowerShell en administrateur** (clic droit sur le menu Démarrer → « Terminal (admin) »), placez-vous dans le dossier du projet, puis :

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\talinet_volunteer.ps1
```

> N'utilisez pas WSL2 ni Git Bash pour lancer l'installation sur Windows : le script `.ps1` s'en charge lui-même, y compris l'activation de WSL2 si besoin. Si un redémarrage est demandé pour terminer l'activation de WSL2, relancez simplement le script après le redémarrage — il reprend où il s'était arrêté.

### Linux

```bash
chmod +x talinet_volunteer.sh
./talinet_volunteer.sh
```

Le mot de passe administrateur (`sudo`) vous sera demandé si nécessaire pour installer les paquets manquants.

### Ce que le script fait, dans l'ordre (Windows comme Linux)

1. **Vérifie le système** : version d'OS, architecture, espace disque, accès Internet.
2. **Installe les outils manquants** : Git, Docker (+ greffon `compose`), Tailscale — et WSL2 sous Windows. Rien n'est réinstallé si déjà présent : le script peut être relancé sans risque en cas d'interruption.
3. **Rattache la machine au réseau privé** de l'expérience via Tailscale, avec la clé `TAILSCALE_AUTHKEY`.
4. **Vérifie la liaison** avec le serveur de l'expérience (ping sur le réseau privé). Si le serveur ne répond pas encore, ce n'est pas bloquant : l'entraînement démarrera dès qu'il sera accessible.
5. **Démarre le conteneur** (`docker compose pull` puis `up -d`), qui rejoint lui-même, en plus, le tailnet de l'expérience à son démarrage.
6. **Affiche les logs** du conteneur en direct.

Laissez le terminal ouvert pour continuer à suivre les logs, ou fermez-le : le conteneur continue de tourner en arrière-plan et redémarre automatiquement si la machine est éteinte puis rallumée.

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

### Windows

```text
1. Cloner ou télécharger le dépôt (bouton Code → Download ZIP si Git n'est pas installé)
2. Double-cliquer sur Lancer-volontaire.bat
```

### Linux

```bash
git clone git@github.com:mbassi237/noeuds_volontaires.git
cd noeuds_volontaires
chmod +x talinet_volunteer.sh
./talinet_volunteer.sh
```
