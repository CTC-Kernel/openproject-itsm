# frozen_string_literal: true

module Itsm
  # Vue infogérance transverse : synthèse par projet client de tous les
  # projets où le module ITSM est activé et visibles par l'utilisateur.
  class GlobalDashboardsController < ::ApplicationController
    before_action :require_login

    # L'autorisation est portée par le filtrage per-projet ci-dessous
    # (Project.allowed_to view_itsm_dashboard).
    authorization_checked! :show

    menu_item :itsm_global_dashboard

    def show
      projects = Project.active
                        .has_module(:itsm)
                        .allowed_to(current_user, :view_itsm_dashboard)
                        .order(:name)

      types = Type.where(name: Itsm::Config.itsm_type_names)
      threshold = Itsm::Config.at_risk_threshold_minutes

      @rows = projects.map do |project|
        tickets = WorkPackage.where(project: project, type: types)
        open = tickets.where.not(status: Status.where(is_closed: true))
        states = Itsm::SlaState.joins(:work_package)
                               .where(work_packages: { project_id: project.id })

        breached = states.where(resolved_at: nil)
                         .where("response_breached = TRUE OR resolution_breached = TRUE")
                         .count
        at_risk = states.running.count do |s|
          s.response_at_risk?(threshold) || s.resolution_at_risk?(threshold)
        end

        {
          project: project,
          open: open.count,
          incidents: open.joins(:type).where(types: { name: "Incident" }).count,
          breached: breached,
          at_risk: at_risk,
          resolved_30d: states.where(resolved_at: 30.days.ago..).count
        }
      end
    end
  end
end
