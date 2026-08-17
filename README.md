# OpenProject ITSM

Plugin OpenProject apportant une gestion ITSM complète (inspirée ITIL) des **incidents** et
**demandes de service**, pensé pour l'infogérance multi-clients (un infogéreur / MSP et ses clients).

## Fonctionnalités

- **Types de tickets** : `Incident` et `Demande de service`, avec statuts ITIL
  (Nouveau → En cours → En attente client/tiers → Résolu → Fermé) et workflows provisionnés.
- **Matrice de priorité ITIL** : la priorité (P1…P4) est calculée automatiquement à partir
  des champs personnalisés `Impact` × `Urgence`.
- **SLA complets** : politiques par projet et par priorité (délai de prise en charge et de
  résolution), calcul en **heures ouvrées** (plage horaire, jours ouvrés, jours fériés) ou 24/7,
  **pause automatique** des compteurs sur les statuts d'attente, détection des dépassements
  toutes les 10 minutes avec **alerte email** à l'assigné et au responsable.
- **Tableaux de bord infogérance** : par projet client (tickets ouverts, SLA à risque/dépassés,
  MTTR 30 jours) et vue globale multi-clients.
- **Portail demandeur** : formulaire simplifié de déclaration et suivi « mes tickets » pour
  les utilisateurs côté client.
- **Intake email** : routage des emails entrants vers les types ITSM via balises de sujet
  `[INC]` / `[DEM]`, en complément du traitement d'emails natif d'OpenProject.

## Organisation multi-clients

Un projet OpenProject par client infogéré (ex. `acme`), module **ITSM** activé sur chacun.
Les droits, workflows et SLA restent ainsi isolés par client, et la vue globale agrège tout.

## Installation

**Stack Docker existante — intégration en une ligne** : remplacez l'image de votre
service OpenProject par l'image préconstruite (ou déposez
[docker-compose.override.example.yml](docker-compose.override.example.yml) renommé en
`docker-compose.override.yml` à côté de votre compose), puis `docker compose up -d` :

```yaml
services:
  openproject:
    image: ghcr.io/ctc-kernel/openproject-itsm:16
```

L'image est **publique** (aucune authentification GHCR nécessaire) et republiée à
chaque évolution du plugin. Rien d'autre ne change dans la stack : volumes, base,
variables d'environnement et reverse proxy sont conservés, ainsi que toutes les
données existantes.

**Prérequis** : OpenProject **16.x**, base **PostgreSQL 17**, hôte **amd64**
(hôte arm64 : build local — voir [docs/INSTALLATION.md](docs/INSTALLATION.md)).

### Ce qui se passe au démarrage

1. Le boot officiel d'OpenProject applique les migrations, **y compris celles du
   plugin** (tables `itsm_sla_policies`, `itsm_sla_states`).
2. L'entrypoint du plugin attend que l'application réponde, puis joue le
   provisionnement ITSM en arrière-plan — **idempotent**, rejouable à chaque
   redémarrage sans doublon : types `Incident` / `Demande de service`, statuts ITIL,
   priorités P1…P4, champs `Impact`, `Urgence`, `Élément de configuration`, `Canal`,
   et workflows. Désactivable avec `OPENPROJECT_ITSM_AUTOSETUP=false` (repli manuel :
   `rake openproject_itsm:seed`).

Vérification :

```bash
docker compose logs openproject | grep openproject-itsm
```

→ doit afficher `provisionnement ITSM appliqué`. Côté interface :
Administration → Plugins → `openproject-itsm` présent.

### Mise en place d'un client

Une commande crée le projet, active le module ITSM et pose 4 politiques SLA par défaut :

```bash
docker compose exec openproject bundle exec rake "openproject_itsm:setup_project[acme,Acme]"
```

Le menu du projet affiche alors **Tableau de bord ITSM** et **Portail de demandes**.
Ajustement des SLA au contrat et rôles : [docs/CONFIGURATION_CLIENT.md](docs/CONFIGURATION_CLIENT.md).

### Mise à jour / retour arrière

- **Mise à jour** : `docker compose pull && docker compose up -d` — migrations et
  seed suivent automatiquement.
- **Retour arrière** : repointer sur `openproject/openproject:16` puis `up -d` ;
  les tables du plugin restent en base mais sont ignorées.

### Pour aller plus loin

**Procédure complète pas-à-pas : [docs/PROCEDURE_IMPLEMENTATION.md](docs/PROCEDURE_IMPLEMENTATION.md)**
(prérequis, build, déploiement, initialisation, rôles, intake email, recette,
exploitation, dépannage).

Voir aussi [docs/INSTALLATION.md](docs/INSTALLATION.md) (détails Docker, build local,
emails entrants, SLA) et [docs/CONFIGURATION_CLIENT.md](docs/CONFIGURATION_CLIENT.md).

Démarrage rapide (dev) depuis la racine du dépôt :

```bash
docker compose up -d --build
docker compose exec openproject bundle exec rake "openproject_itsm:setup_project[acme]"
```

## Compatibilité

Développé pour OpenProject **≥ 14** (testé en ciblant la série 16.x, image officielle Docker).
Le plugin suit les conventions du [proto_plugin](https://github.com/opf/openproject-proto_plugin)
officiel (`ActsAsOpEngine`, `project_module`, patches, settings).

## Licence

GPL-3.0 — comme OpenProject.
