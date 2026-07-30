# frozen_string_literal: true

module Itsm
  # Maintient l'état SLA d'un ticket au fil de son cycle de vie :
  # - à la création : sélection de la politique et calcul des échéances ;
  # - prise en charge : horodatage de la première réponse ;
  # - statuts d'attente : pause des compteurs puis décalage des échéances ;
  # - résolution : arrêt des compteurs et constat de dépassement éventuel ;
  # - réouverture : reprise du compteur de résolution.
  class ApplySlaService
    def initialize(work_package)
      @work_package = work_package
    end

    def call
      state = @work_package.itsm_sla_state || initialize_state
      return unless state

      status_name = @work_package.status&.name
      now = Time.zone.now

      handle_pause(state, status_name, now)
      handle_response(state, status_name, now)
      handle_resolution(state, status_name, now)
      handle_policy_change(state)

      state.save!
    end

    private

    def config
      Itsm::Config
    end

    def initialize_state
      policy = Itsm::SlaPolicy.for(@work_package)
      started_at = @work_package.created_at || Time.zone.now

      state = Itsm::SlaState.new(work_package: @work_package,
                                 sla_policy: policy,
                                 started_at: started_at)
      assign_due_dates(state)
      state
    end

    def assign_due_dates(state)
      policy = state.sla_policy
      if policy
        calculator = BusinessTimeCalculator.new(policy)
        offset = state.paused_seconds.to_i
        state.response_due_at =
          calculator.add_seconds(state.started_at, (policy.response_minutes * 60) + offset)
        state.resolution_due_at =
          calculator.add_seconds(state.started_at, (policy.resolution_minutes * 60) + offset)
      else
        state.response_due_at = nil
        state.resolution_due_at = nil
      end
    end

    def handle_pause(state, status_name, now)
      paused_status = config.paused_status_names.include?(status_name)

      if paused_status && !state.paused?
        state.paused_at = now
      elsif !paused_status && state.paused?
        elapsed =
          if state.sla_policy
            BusinessTimeCalculator.new(state.sla_policy).seconds_between(state.paused_at, now)
          else
            (now - state.paused_at).to_i
          end
        state.paused_seconds += elapsed
        state.paused_at = nil
        assign_due_dates(state)
      end
    end

    def handle_response(state, status_name, now)
      return if state.responded?
      return unless config.response_status_names.include?(status_name) ||
                    config.resolved_status_names.include?(status_name)

      state.first_responded_at = now
      state.response_breached = state.response_due_at.present? && now > state.response_due_at
    end

    def handle_resolution(state, status_name, now)
      resolved_status = config.resolved_status_names.include?(status_name)

      if resolved_status && !state.resolved?
        state.resolved_at = now
        state.resolution_breached ||=
          state.resolution_due_at.present? && now > state.resolution_due_at
      elsif !resolved_status && state.resolved?
        # Réouverture : le compteur de résolution repart, l'historique de
        # dépassement déjà constaté est conservé.
        state.resolved_at = nil
      end
    end

    # Un changement de priorité peut faire basculer sur une autre politique.
    def handle_policy_change(state)
      return if state.resolved?

      policy = Itsm::SlaPolicy.for(@work_package)
      return if policy&.id == state.sla_policy_id

      state.sla_policy = policy
      assign_due_dates(state)
    end
  end
end
