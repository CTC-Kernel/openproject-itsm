# Installation (Docker, image custom)

Les plugins OpenProject ne s'installent pas « à chaud » : ils sont déclarés dans un
`Gemfile.plugins` et embarqués dans une image Docker reconstruite. C'est le mécanisme
officiel documenté par OpenProject.

## 1. Construire l'image

Depuis la racine du dépôt :

```bash
docker build -t monorg/openproject-itsm:16 -f docker/Dockerfile .
```

L'argument `OPENPROJECT_VERSION` (défaut `16`) permet de cibler une autre série :

```bash
docker build --build-arg OPENPROJECT_VERSION=16.4 -t monorg/openproject-itsm:16.4 -f docker/Dockerfile .
```

## 2. Déployer

Remplacez l'image `openproject/openproject` de votre déploiement existant par
`monorg/openproject-itsm:16` (docker compose, Kubernetes, etc.). Un `docker-compose.yml`
de développement est fourni à la racine du dépôt.

Au démarrage, appliquez les migrations puis provisionnez les données ITSM :

```bash
docker compose exec openproject bundle exec rake db:migrate
docker compose exec openproject bundle exec rake openproject_itsm:seed
```

`openproject_itsm:seed` est **idempotent** : il crée (sans doublonner) les statuts ITIL,
les priorités P1…P4, les types `Incident` / `Demande de service`, les champs personnalisés
(`Impact`, `Urgence`, `Élément de configuration`, `Canal`) et les workflows associés.

## 3. Vérifications

- Administration → Plugins : `openproject-itsm` doit apparaître, avec ses réglages
  (noms de types/statuts, seuil « à risque »).
- Dans un projet : Paramètres → Modules → cocher **ITSM** (ou utiliser
  `rake "openproject_itsm:setup_project[identifiant]"`).
- Le menu du projet affiche alors **Tableau de bord ITSM** et **Portail de demandes**.

## 4. Emails entrants (intake)

Le plugin s'appuie sur le traitement d'emails natif d'OpenProject et y ajoute le routage
par balise de sujet : `[INC]` → Incident, `[DEM]` ou `[SR]` → Demande de service.

Configuration type (IMAP relevé par cron dans le conteneur ou un job externe) :

```bash
docker compose exec openproject bundle exec rake redmine:email:receive_imap \
  host=imap.exemple.fr username=support@exemple.fr password=*** ssl=1 \
  project=acme unknown_user=accept no_permission_check=1
```

Chaque client peut avoir son adresse dédiée (`support-acme@…` → `project=acme`).

## 5. Vérification périodique des SLA

Le job `Itsm::SlaCheckJob` est enregistré dans le planificateur interne (toutes les
10 minutes). En cas d'indisponibilité du cron interne, planifiez côté système :

```bash
docker compose exec openproject bundle exec rake openproject_itsm:check_sla
```

## Mises à jour d'OpenProject

À chaque montée de version d'OpenProject, reconstruisez l'image avec le nouveau tag et
testez en recette : les patches (`WorkPackage`, `MailHandler`) sont défensifs mais les
API internes peuvent évoluer entre versions majeures.
