#!/bin/bash
# Entrypoint du plugin ITSM : provisionne les données ITSM en arrière-plan puis
# rend immédiatement la main à l'entrypoint officiel d'OpenProject. Ainsi, sur
# une stack Docker existante, il suffit de remplacer l'image — aucune commande
# manuelle n'est nécessaire. Désactivable avec OPENPROJECT_ITSM_AUTOSETUP=false.
#
# Important : ne rien exécuter contre la base tant que le démarrage officiel
# n'a pas terminé son installation (structure.sql + migrations + seed cœur).
# Même une tâche rake « en lecture » crée ar_internal_metadata au boot Rails
# et fait échouer le chargement concurrent de structure.sql. Le signal fiable
# est donc l'endpoint de santé HTTP : quand l'application répond, la base est
# prête et le seed idempotent du plugin peut être joué.
set -u
cd /app

itsm_setup() {
  local log=/tmp/openproject-itsm-setup.log
  # 80 : all-in-one (Apache) ; 8080 : variante slim (Puma)
  for i in $(seq 1 180); do
    if curl -fsS -o /dev/null http://127.0.0.1:80/health_checks/default 2>/dev/null \
    || curl -fsS -o /dev/null http://127.0.0.1:8080/health_checks/default 2>/dev/null; then
      break
    fi
    if [ "$i" = 180 ]; then
      echo "[openproject-itsm] application injoignable après 30 min — provisionnement non joué."
      echo "[openproject-itsm] lancez manuellement : bundle exec rake openproject_itsm:seed"
      return 1
    fi
    sleep 10
  done
  for i in $(seq 1 5); do
    if bundle exec rake openproject_itsm:seed >"$log" 2>&1; then
      echo "[openproject-itsm] provisionnement ITSM appliqué (tentative $i)"
      return 0
    fi
    sleep 15
  done
  echo "[openproject-itsm] provisionnement automatique en échec :"
  tail -n 20 "$log"
  echo "[openproject-itsm] lancez manuellement : bundle exec rake openproject_itsm:seed"
  return 1
}

if [ "${OPENPROJECT_ITSM_AUTOSETUP:-true}" != "false" ]; then
  # En arrière-plan : attend que l'application soit prête sans retarder le
  # démarrage. Sous root (image all-in-one), exécute sous l'utilisateur
  # applicatif comme le fait l'entrypoint officiel.
  if [ "$(id -u)" = "0" ] && command -v gosu >/dev/null 2>&1; then
    gosu "${APP_USER:-app}" bash -c "cd /app; $(declare -f itsm_setup); itsm_setup" &
  else
    itsm_setup &
  fi
fi

if [ -x ./docker/prod/entrypoint.sh ]; then
  exec ./docker/prod/entrypoint.sh "$@"
else
  # Variante slim de l'image officielle
  exec ./docker/prod/entrypoint-slim.sh "$@"
fi
