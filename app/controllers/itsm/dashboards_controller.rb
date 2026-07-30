# frozen_string_literal: true

module Itsm
  # Tableau de bord ITSM d'un projet client.
  class DashboardsController < ::ApplicationController
    before_action :find_project_by_project_id
    before_action :authorize

    menu_item :itsm_dashboard

    def show
      open = open_scope

      @open_count = open.count
      @open_incidents = open.joins(:type).where(types: { name: "Incident" }).count
      @open_requests = @open_count - @open_incidents

      @open_by_priority = open.joins(:priority)
                              .group("enumerations.position", "enumerations.name")
                              .order(Arel.sql("enumerations.position"))
                              .count
                              .map { |(_, name), count| [name, count] }
      @open_by_type = open.joins(:type).group("types.name").count

      threshold = Itsm::Config.at_risk_threshold_minutes
      states = Itsm::SlaState.joins(:work_package)
                             .where(work_packages: { project_id: @project.id })
                             .includes(work_package: %i[type status priority assigned_to])

      @breached = states.where(resolved_at: nil)
                        .where("response_breached = TRUE OR resolution_breached = TRUE")
                        .to_a
      @at_risk = states.running
                       .where(response_breached: false, resolution_breached: false)
                       .select { |s| s.response_at_risk?(threshold) || s.resolution_at_risk?(threshold) }

      @recent_open = open.includes(:type, :status, :priority, :assigned_to, :itsm_sla_state)
                         .order(created_at: :desc)
                         .limit(10)

      @resolved_last_30d = states.where(resolved_at: 30.days.ago..).count
      @mttr_seconds = mean_time_to_resolution
    end

    private

    def itsm_types
      Type.where(name: Itsm::Config.itsm_type_names)
    end

    def base_scope
      WorkPackage.where(project: @project, type: itsm_types)
    end

    def open_scope
      base_scope.where.not(status: Status.where(is_closed: true))
    end

    def mean_time_to_resolution
      durations = Itsm::SlaState.joins(:work_package)
                                .where(work_packages: { project_id: @project.id })
                                .where(resolved_at: 30.days.ago..)
                                .pluck(:started_at, :resolved_at, :paused_seconds)
                                .map { |s, r, p| (r - s).to_i - p.to_i }
      return nil if durations.empty?

      durations.sum / durations.size
    end
  end
end
