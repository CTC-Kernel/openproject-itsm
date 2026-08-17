# Installation (Docker)

Les plugins OpenProject ne s'installent pas « à chaud » : ils sont déclarés dans un
`Gemfile.plugins` et embarqués dans une image Docker (mécanisme officiel OpenProject).
Une **image préconstruite** est publiée sur GHCR pour que l'intégration à une stack
existante se résume à un changement d'image.

## Option A — Stack Docker existante : image préconstruite (recommandé)

Aucun build, aucune commande manuelle. Depuis le dossier de votre stack existante :

1. Copiez [`docker-compose.override.example.yml`](../docker-compose.override.example.yml)
   à côté de votre `docker-compose.yml`, sous le nom `docker-compose.override.yml`
   (Compose fusionne les deux automatiquement) — ou remplacez directement l'image
   dans votre fichier :

   ```yaml
   services:
     openproject:                 # adaptez le nom du service (web, app…)
       image: ghcr.io/ctc-kernel/openproject-itsm:16
   ```

2. Relancez la stack :

   ```bash
   docker compose up -d
   ```

C'est tout. Les migrations (cœur **et** plugin) sont appliquées par le démarrage
normal d'OpenProject ; l'image attend ensuite qu'elles soient à jour et joue
`openproject_itsm:seed` (idempotent, en arrière-plan, sans retarder le boot) :
statuts ITIL, priorités P1…P4, types `Incident` / `Demande de service`, champs
personnalisés (`Impact`, `Urgence`, `Élément de configuration`, `Canal`) et
workflows. Vos données existantes sont conservées ; seules les deux tables du
plugin s'ajoutent.

Vérification que le provisionnement est passé :

```bash
docker compose logs openproject | grep openproject-itsm
```

→ doit afficher `provisionnement ITSM appliqué`. (Au premier démarrage d'une base
vierge, comptez 3 à 8 minutes : l'initialisation d'OpenProject précède le seed.)

Pour désactiver cette préparation automatique (et repasser aux commandes
manuelles ci-dessous) : `OPENPROJECT_ITSM_AUTOSETUP=false` dans l'environnement
du service.

Notes :

- l'image est **publique** : aucune authentification GHCR n'est nécessaire pour la puller ;
- l'image publiée est **linux/amd64** (hôte arm64 : construire localement, Option B) ;
- elle dérive de `openproject/openproject:16` (all-in-one) : mêmes volumes, mêmes
  variables d'environnement, base **PostgreSQL 17** requise ;
- si la stack tourne encore en OpenProject 14/15, changer d'image effectue aussi la
  montée de version d'OpenProject : testez en recette d'abord.

## Option B — Construire l'image soi-même

Depuis la racine du dépôt :

```bash
docker build -t monorg/openproject-itsm:16 -f docker/Dockerfile .
```

L'argument `OPENPROJECT_VERSION` (défaut `16`) permet de cibler une autre série :

```bash
docker build --build-arg OPENPROJECT_VERSION=16.4 -t monorg/openproject-itsm:16.4 -f docker/Dockerfile .
```

Déployez ensuite comme en Option A (remplacement d'image) ; la préparation
automatique au démarrage est identique. Si `OPENPROJECT_ITSM_AUTOSETUP=false`,
lancez manuellement :

```bash
docker compose exec openproject bundle exec rake db:migrate openproject_itsm:seed
```

`openproject_itsm:seed` est **idempotent** : il crée sans doublonner les données
listées en Option A.

## Vérifications

- Administration → Plugins : `openproject-itsm` doit apparaître, avec ses réglages
  (noms de types/statuts, seuil « à risque »).
- Dans un projet : Paramètres → Modules → cocher **ITSM** (ou utiliser
  `rake "openproject_itsm:setup_project[identifiant]"`).
- Le menu du projet affiche alors **Tableau de bord ITSM** et **Portail de demandes**.

## Emails entrants (intake)

Le plugin s'appuie sur le traitement d'emails natif d'OpenProject et y ajoute le routage
par balise de sujet : `[INC]` → Incident, `[DEM]` ou `[SR]` → Demande de service.

Configuration type (IMAP relevé par cron dans le conteneur ou un job externe) :

```bash
docker compose exec openproject bundle exec rake redmine:email:receive_imap \
  host=imap.exemple.fr username=support@exemple.fr password=*** ssl=1 \
  project=acme unknown_user=accept no_permission_check=1
```

Chaque client peut avoir son adresse dédiée (`support-acme@…` → `project=acme`).

## Vérification périodique des SLA

Le job `Itsm::SlaCheckJob` est enregistré dans le planificateur interne (toutes les
10 minutes). En cas d'indisponibilité du cron interne, planifiez côté système :

```bash
docker compose exec openproject bundle exec rake openproject_itsm:check_sla
```

## Mises à jour d'OpenProject

À chaque montée de version d'OpenProject, utilisez le tag GHCR correspondant (ou
reconstruisez l'image avec le nouveau tag) et testez en recette : les patches
(`WorkPackage`, `MailHandler`) sont défensifs mais les API internes peuvent évoluer
entre versions majeures.

## Retour arrière

Repointez l'image du service sur l'officielle (`openproject/openproject:16`) puis
`docker compose up -d`. Les tables du plugin (`itsm_sla_policies`, `itsm_sla_states`)
et ses données de référence restent en base mais sont simplement ignorées ; un
retour au plugin les retrouve intactes.

## Dépannage

Voir le tableau des pièges connus dans
[PROCEDURE_IMPLEMENTATION.md](PROCEDURE_IMPLEMENTATION.md) (§ Dépannage) — les plus
fréquents : base en PostgreSQL < 17 (`transaction_timeout`), SMTP absent (pas
d'alertes SLA), champs `Impact`/`Urgence` renommés (priorité non calculée).
