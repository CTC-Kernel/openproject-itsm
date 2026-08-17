# Procédure d'implémentation du plugin OpenProject ITSM

Procédure pas-à-pas pour déployer le plugin `openproject-itsm` sur une instance
OpenProject auto-hébergée (Docker) et mettre en service l'ITSM d'infogérance
(un infogéreur / MSP et ses projets clients — « Acme » sert d'exemple).

**Durée indicative** : 1 h à 2 h pour une première installation complète.

---

## 1. Prérequis

| Élément | Exigence |
|---|---|
| OpenProject | Série **16.x** auto-hébergée (image officielle `openproject/openproject:16`). Le plugin ne s'installe pas sur le SaaS openproject.org. |
| Base de données | **PostgreSQL 17** obligatoire (le schéma d'OP16 utilise des paramètres PG17). |
| Docker | Docker Engine + Compose v2 sur la machine de build et le serveur cible. |
| Réseau | Un port HTTP libre pour OpenProject (80/443 derrière un reverse proxy en production). |
| Emails (optionnel) | Une boîte IMAP dédiée au support (ex. `support@exemple.fr`) pour l'intake email. |
| SMTP | Un relais SMTP pour les notifications et alertes SLA. |

Le dépôt contient :

```
openproject-itsm/                 # le plugin (gem Rails)
├── docker-compose.yml            # environnement de dev/recette
├── docker/Dockerfile             # image OpenProject + plugin
├── docker/Gemfile.plugins        # déclaration officielle du plugin
└── docs/                         # documentation
```

---

## 2. Obtenir l'image

**Le plus simple** : utiliser l'image préconstruite publiée sur GHCR — aucun
build nécessaire, la suite de la procédure s'applique telle quelle :

```
ghcr.io/ctc-kernel/openproject-itsm:16
```

(Image linux/amd64 ; sur un hôte arm64, construire localement comme ci-dessous.)

Sinon, construire soi-même depuis la racine du dépôt :

```bash
docker build -t monorg/openproject-itsm:16 -f docker/Dockerfile .
```

Pour figer une version précise d'OpenProject (recommandé en production) :

```bash
docker build --build-arg OPENPROJECT_VERSION=16.5 -t monorg/openproject-itsm:16.5 -f docker/Dockerfile .
```

Poussez ensuite l'image vers votre registre privé si le serveur de production
est distinct de la machine de build :

```bash
docker tag monorg/openproject-itsm:16 registre.exemple.fr/openproject-itsm:16
docker push registre.exemple.fr/openproject-itsm:16
```

> ⚠️ Les étapes du Dockerfile s'exécutent en root (mécanisme officiel
> OpenProject) ; l'entrypoint redescend les privilèges au démarrage.

---

## 3. Déployer

### 3.a Nouvelle instance

Adaptez le `docker-compose.yml` fourni (il sert de modèle) :

- remplacez l'image par la vôtre (`monorg/openproject-itsm:16`) ;
- **`postgres:17`** pour la base (impératif) ;
- renseignez `OPENPROJECT_HOST__NAME` (FQDN réel), `OPENPROJECT_HTTPS=true`
  derrière un reverse proxy TLS, et un `OPENPROJECT_SECRET_KEY_BASE` fort
  (`openssl rand -hex 64`) ;
- configurez le SMTP :

```yaml
      OPENPROJECT_EMAIL__DELIVERY__METHOD: "smtp"
      OPENPROJECT_SMTP__ADDRESS: "smtp.exemple.fr"
      OPENPROJECT_SMTP__PORT: "587"
      OPENPROJECT_SMTP__DOMAIN: "exemple.fr"
      OPENPROJECT_SMTP__USER__NAME: "openproject@exemple.fr"
      OPENPROJECT_SMTP__PASSWORD: "********"
      OPENPROJECT_SMTP__ENABLE__STARTTLS__AUTO: "true"
```

Puis :

```bash
docker compose up -d
```

Au premier démarrage, OpenProject migre et initialise sa base (3 à 8 min),
**y compris les deux tables du plugin** (`itsm_sla_policies`, `itsm_sla_states`).

### 3.b Instance OpenProject existante

Remplacez simplement l'image `openproject/openproject:16` de votre déploiement
par `ghcr.io/ctc-kernel/openproject-itsm:16` (mêmes volumes, même base) — soit
dans votre compose, soit via un `docker-compose.override.yml` (modèle fourni :
`docker-compose.override.example.yml` à la racine du dépôt) — puis :

```bash
docker compose up -d
```

Rien d'autre : les migrations (plugin inclus) sont jouées par le démarrage
normal d'OpenProject, puis l'image applique le provisionnement ITSM (voir §4).
Vos données existantes sont conservées ; seules les tables du plugin s'ajoutent.

---

## 4. Initialiser les données ITSM

**Automatique** : au démarrage du conteneur, l'entrypoint du plugin attend que
les migrations (jouées par le boot officiel) soient à jour puis exécute
`openproject_itsm:seed` en arrière-plan (idempotent, rejouable sans risque).
Pour désactiver ce comportement, définir `OPENPROJECT_ITSM_AUTOSETUP=false` et
lancer alors manuellement :

```bash
docker compose exec openproject bundle exec rake db:migrate openproject_itsm:seed
```

Elle crée :

- **Statuts** : Nouveau, En cours, En attente client, En attente tiers, Résolu, Fermé ;
- **Priorités** : P1 - Critique, P2 - Élevée, P3 - Moyenne, P4 - Faible ;
- **Types** : Incident, Demande de service ;
- **Champs personnalisés** : Impact, Urgence (listes pilotant la matrice de
  priorité), Élément de configuration, Canal ;
- **Workflows** : toutes les transitions entre statuts ITSM pour chaque rôle.

---

## 5. Créer un projet client (ex. Acme)

```bash
docker compose exec openproject bundle exec rake "openproject_itsm:setup_project[acme,Acme]"
```

La tâche crée le projet s'il n'existe pas, active les modules **ITSM** et
**Work packages**, associe les types Incident / Demande de service et crée les
politiques SLA par défaut (heures ouvrées 8h30–18h, lundi–vendredi) :

| Priorité | Prise en charge | Résolution |
|---|---|---|
| P1 - Critique | 30 min | 4 h |
| P2 - Élevée | 1 h | 8 h |
| P3 - Moyenne | 4 h | 20 h |
| P4 - Faible | 8 h | 40 h |

**Ajustez ensuite selon le contrat réel** : projet → *Tableau de bord ITSM* →
*Politiques SLA* (délais, plage horaire, jours fériés, 24/7, politique par défaut).

Répétez cette étape pour chaque client infogéré (`[clientx,ClientX]`).

---

## 6. Configurer les rôles et les membres

Administration → **Rôles et permissions**. Les permissions du plugin
apparaissent dans la section **ITSM** :

| Permission | Équipe infogéreur | Demandeur client |
|---|---|---|
| Voir le tableau de bord ITSM | ✔ | selon contrat |
| Gérer les politiques SLA | ✔ (resp. de compte) | ✘ |
| Utiliser le portail de demandes | ✔ | ✔ |

1. Créez un rôle **« Demandeur »** : portail + consultation des work packages.
2. Ajoutez les techniciens de l'infogéreur et les utilisateurs du client comme membres du
   projet avec le rôle adapté (projet → Paramètres → Membres).
3. Pour que l'assignation automatique des priorités opère, les demandeurs
   doivent pouvoir renseigner Impact et Urgence (le portail le fait pour eux).

---

## 7. Réglages globaux du plugin

Administration → **Plugins** → OpenProject ITSM → *Réglages* :

- noms des types ITSM et des statuts (prise en charge, pause SLA, résolution) —
  à ne modifier que si vous renommez les statuts ;
- seuil « SLA à risque » des tableaux de bord (minutes avant échéance, défaut 240).

Les alertes de dépassement partent automatiquement par email (job toutes les
10 minutes) vers l'assigné et le responsable du ticket. Vérifiez que le SMTP
fonctionne : Administration → Emails et notifications → tester l'envoi.

---

## 8. Intake email (optionnel)

Une adresse par client, relevée périodiquement (cron système ou conteneur) :

```bash
docker compose exec openproject bundle exec rake redmine:email:receive_imap \
  host=imap.exemple.fr username=support-acme@exemple.fr password='***' ssl=1 \
  project=acme unknown_user=accept no_permission_check=1
```

Routage automatique par balise dans le **sujet** de l'email :

- `[INC]` → Incident
- `[DEM]` ou `[SR]` → Demande de service
- sans balise → type par défaut du projet (mot-clé `type:` dans le corps toujours prioritaire)

Planifiez la relève toutes les 5 min (crontab du serveur hôte) :

```
*/5 * * * * cd /opt/openproject && docker compose exec -T openproject bundle exec rake redmine:email:receive_imap host=... >> /var/log/op-mail.log 2>&1
```

---

## 9. Vérifications de mise en service

Cochez chaque point :

- [ ] `https://<votre-instance>/projects/acme/itsm` : tableau de bord ITSM affiché ;
- [ ] *Politiques SLA* : 4 politiques listées, création/édition OK ;
- [ ] Portail (`…/itsm/portal`) : déclaration d'un ticket de test avec
      Impact = Critique et Urgence = Critique ;
- [ ] le ticket créé a la priorité **P1 - Critique** (matrice automatique) ;
- [ ] passage « En cours » → « En attente client » → « En cours » → « Résolu »
      sans erreur (le SLA se met en pause pendant l'attente) ;
- [ ] `https://<votre-instance>/itsm` : vue globale infogérance avec la ligne Acme ;
- [ ] email de test : envoi à l'adresse support avec `[INC]` dans le sujet →
      un Incident apparaît dans le projet ;
- [ ] logs propres : `docker compose logs openproject | grep -i error`.

Supprimez le ticket de test après recette.

---

## 10. Exploitation et mises à jour

**Sauvegardes** : la base PostgreSQL (`pg_dump`) + le volume des assets
(`/var/openproject/assets`). Les données SLA vivent dans les tables
`itsm_sla_policies` et `itsm_sla_states`.

**Mise à jour du plugin** (les migrations sont appliquées automatiquement au
redémarrage) :

```bash
docker compose pull           # image GHCR — ou : docker build -t … -f docker/Dockerfile .
docker compose up -d          # recrée le conteneur, les données persistent
```

**Montée de version OpenProject** : reconstruire avec le nouveau
`--build-arg OPENPROJECT_VERSION=…` et **tester en recette d'abord** — les
patches du plugin touchent des API internes qui peuvent évoluer entre versions
majeures (voir §11).

**Repli si le cron interne des SLA est indisponible** :

```bash
docker compose exec openproject bundle exec rake openproject_itsm:check_sla
```

---

## 11. Dépannage — pièges connus

| Symptôme | Cause | Remède |
|---|---|---|
| `unrecognized configuration parameter "transaction_timeout"` au boot | Base en PostgreSQL < 17 | Utiliser `postgres:17` |
| `Bind for 0.0.0.0:XX failed: port is already allocated` | Port déjà pris sur l'hôte | Changer le port publié dans le compose |
| Erreur `uninitialized constant MailHandler` | Version du plugin antérieure au portage OP16 | Le patch cible `IncomingEmails::Handlers::WorkPackage` depuis la v1.0 |
| Erreur 500 `undefined method 'toolbar'` | Idem (vues legacy) | Corrigé en v1.0 (composants Primer) |
| Pas d'alertes SLA | SMTP non configuré ou job GoodJob arrêté | Tester le SMTP ; vérifier `docker compose logs` ; repli `rake openproject_itsm:check_sla` |
| La priorité ne se calcule pas | Impact/Urgence non renseignés, ou noms de champs modifiés | Renseigner les deux champs ; les noms `Impact`/`Urgence` doivent être exacts |
| Tickets email dans le mauvais projet | Paramètre `project=` absent de la relève IMAP | Une adresse/commande de relève par client |

---

## 12. Récapitulatif express (copier-coller)

```bash
# 1. Pointer l'image du service OpenProject sur ghcr.io/ctc-kernel/openproject-itsm:16
#    (docker-compose.override.example.yml fourni ; ou build local via docker/Dockerfile)

# 2. Démarrage — migrations + initialisation ITSM appliquées automatiquement
docker compose up -d

# 3. Un projet par client
docker compose exec openproject bundle exec rake "openproject_itsm:setup_project[acme,Acme]"
```

Puis configuration des rôles (§6), ajustement des SLA au contrat (§5),
intake email (§8) et recette (§9).
