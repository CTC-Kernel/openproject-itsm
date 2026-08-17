# Image OpenProject incluant le plugin ITSM.
# Construire depuis la racine du dépôt :
#   docker build -t monorg/openproject-itsm:16 -f docker/Dockerfile .
ARG OPENPROJECT_VERSION=16
FROM openproject/openproject:${OPENPROJECT_VERSION}

# Les étapes de build s'exécutent en root (comme dans la doc officielle
# d'installation de plugins) ; l'entrypoint de l'image redescend ensuite
# les privilèges vers l'utilisateur applicatif au démarrage.
USER root
WORKDIR /app

# Le plugin est embarqué dans l'image et déclaré via Gemfile.plugins
# (mécanisme officiel OpenProject pour les plugins en Docker).
COPY . /app/vendor/openproject-itsm
COPY docker/Gemfile.plugins /app/Gemfile.plugins

RUN bundle config unset deployment \
 && bundle install \
 && bundle config set deployment true \
 && chown -R app:app /app/vendor/openproject-itsm /app/Gemfile.plugins \
 && chmod +x /app/vendor/openproject-itsm/docker/entrypoint-itsm.sh

# Recompilation des assets avec le plugin chargé (le script existe dans
# l'image officielle ; sans frontend Angular custom il reste rapide).
RUN ./docker/prod/setup/precompile-assets.sh || bundle exec rake assets:precompile

# L'entrypoint ITSM attend que les migrations (jouées par le démarrage
# officiel, plugin inclus) soient à jour, applique le seed idempotent en
# arrière-plan, puis délègue à l'entrypoint officiel : remplacer l'image
# suffit, aucune commande manuelle n'est requise sur une stack existante.
ENTRYPOINT ["/app/vendor/openproject-itsm/docker/entrypoint-itsm.sh"]
CMD ["./docker/prod/supervisord"]
