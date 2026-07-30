# frozen_string_literal: true

module OpenProject
  module Itsm
    class Engine < ::Rails::Engine
      engine_name :openproject_itsm

      include OpenProject::Plugins::ActsAsOpEngine

      register "openproject-itsm",
               author_url: "https://cyber-threat-consulting.com",
               bundled: false,
               settings: {
                 default: {
                   # Noms des types de work packages considérés comme tickets ITSM
                   "itsm_type_names" => "Incident,Demande de service",
                   # Statuts marquant la prise en charge (arrête le compteur de réponse)
                   "response_status_names" => "En cours",
                   # Statuts mettant les compteurs SLA en pause
                   "paused_status_names" => "En attente client,En attente tiers",
                   # Statuts marquant la résolution (arrête le compteur de résolution)
                   "resolved_status_names" => "Résolu,Fermé",
                   # Seuil "SLA à risque" affiché dans les tableaux de bord (minutes)
                   "at_risk_threshold_minutes" => "240"
                 },
                 partial: "settings/itsm"
               } do
        project_module :itsm do
          permission :view_itsm_dashboard,
                     { "itsm/dashboards": %i[show] },
                     permissible_on: :project
          permission :manage_sla_policies,
                     { "itsm/sla_policies": %i[index new create edit update destroy] },
                     permissible_on: :project,
                     require: :member
          permission :use_itsm_portal,
                     { "itsm/portal": %i[index new create] },
                     permissible_on: :project
        end

        menu :project_menu,
             :itsm_dashboard,
             { controller: "/itsm/dashboards", action: "show" },
             caption: :"itsm.menu.dashboard",
             after: :work_packages,
             icon: "op-view-list"

        menu :project_menu,
             :itsm_portal,
             { controller: "/itsm/portal", action: "index" },
             caption: :"itsm.menu.portal",
             after: :itsm_dashboard,
             icon: "comment-discussion"

        menu :global_menu,
             :itsm_global_dashboard,
             { controller: "/itsm/global_dashboards", action: "show" },
             caption: :"itsm.menu.global_dashboard",
             after: :work_packages,
             icon: "op-view-list"
      end

      patches %i[WorkPackage]
      patch_with_namespace :IncomingEmails, :Handlers, :WorkPackage

      config.after_initialize do
        # Enregistre la vérification périodique des SLA (toutes les 10 minutes),
        # via le cron GoodJob comme le fait le cœur (config/initializers/cronjobs.rb).
        # Repli possible via `rake openproject_itsm:check_sla` si l'API change.
        begin
          Rails.application.config.good_job.cron.merge!(
            "Itsm::SlaCheckJob": {
              cron: "*/10 * * * *",
              class: "Itsm::SlaCheckJob"
            }
          )
        rescue StandardError => e
          Rails.logger.warn "openproject-itsm: enregistrement du cron SLA impossible (#{e.message}). " \
                            "Utilisez `rake openproject_itsm:check_sla` via un cron système."
        end
      end
    end
  end
end
