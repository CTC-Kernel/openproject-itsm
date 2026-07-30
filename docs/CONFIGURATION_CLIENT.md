# Mise en place d'un client infogéré — exemple Acme

## 1. Créer le projet client

Administration ou interface : créer le projet **Acme** (identifiant `acme`).
Puis provisionner en une commande :

```bash
docker compose exec openproject bundle exec rake "openproject_itsm:setup_project[acme]"
```

Cette tâche :
- active les modules **ITSM** et **Work packages** sur le projet ;
- associe les types `Incident` et `Demande de service` ;
- crée les politiques SLA par défaut (heures ouvrées 8h30–18h, lundi–vendredi) :

| Priorité | Prise en charge | Résolution |
|---|---|---|
| P1 - Critique | 30 min | 4 h |
| P2 - Élevée | 1 h | 8 h |
| P3 - Moyenne | 4 h | 20 h (~2 j ouvrés) |
| P4 - Faible | 8 h | 40 h (~1 sem. ouvrée) |

Ajustez ensuite ces valeurs selon le contrat d'infogérance réel :
**Projet Acme → Tableau de bord ITSM → Politiques SLA** (délais, plage horaire,
jours fériés, mode 24/7 pour la P1 si le contrat le prévoit).

## 2. Rôles et membres

- **Équipe infogéreur** : rôle interne avec les permissions *Voir le tableau de bord ITSM*,
  *Gérer les politiques SLA* et les permissions work packages habituelles.
- **Utilisateurs Acme** : rôle « Demandeur » avec *Utiliser le portail de demandes*,
  *Voir le tableau de bord ITSM* (optionnel) et la création/consultation de work packages.

Les permissions du plugin apparaissent dans Administration → Rôles, section **ITSM**.

## 3. Cycle de vie d'un ticket

1. **Déclaration** : portail (formulaire simplifié), email (`[INC]`/`[DEM]` dans le sujet)
   ou saisie directe. Impact et Urgence renseignés → la priorité P1…P4 est calculée
   automatiquement (matrice ITIL) et la politique SLA correspondante s'applique.
2. **Prise en charge** : passage à `En cours` → horodatage de la première réponse ;
   dépassement du délai signalé sinon.
3. **Attente** : `En attente client` / `En attente tiers` → compteurs SLA en pause,
   échéances décalées à la reprise.
4. **Résolution** : `Résolu` puis `Fermé` → compteurs arrêtés, dépassement éventuel
   constaté. Une réouverture relance le compteur de résolution.

## 4. Pilotage

- **Par client** : menu projet → *Tableau de bord ITSM* (ouverts par type/priorité,
  SLA à risque et dépassés, résolus et MTTR sur 30 jours).
- **Vue transverse infogéreur** : menu global → *ITSM — Infogérance* : une ligne par client,
  cliquable vers le tableau de bord du projet. Idéal pour le comité de pilotage.
- Les alertes de dépassement partent par email à l'assigné et au responsable du ticket.

## 5. Reporting contractuel

Pour les rapports mensuels Acme, combinez le tableau de bord ITSM avec les vues
work packages natives (filtres par type/priorité/statut, export XLS/CSV/PDF) — les
échéances et dépassements SLA sont dans les tables `itsm_sla_states` si un reporting
BI externe est branché sur la base.
