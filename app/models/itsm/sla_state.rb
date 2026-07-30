# frozen_string_literal: true

module Itsm
  # Suivi SLA d'un ticket : échéances calculées, pauses, prise en charge,
  # résolution et dépassements constatés.
  class SlaState < ApplicationRecord
    self.table_name = "itsm_sla_states"

    belongs_to :work_package
    belongs_to :sla_policy, class_name: "Itsm::SlaPolicy", optional: true

    scope :running, -> { where(resolved_at: nil, paused_at: nil) }

    def paused?
      paused_at.present?
    end

    def resolved?
      resolved_at.present?
    end

    def responded?
      first_responded_at.present?
    end

    def response_pending?
      !responded? && !resolved?
    end

    def resolution_pending?
      !resolved?
    end

    def response_at_risk?(threshold_minutes)
      response_pending? && !paused? && response_due_at.present? &&
        response_due_at <= threshold_minutes.minutes.from_now
    end

    def resolution_at_risk?(threshold_minutes)
      resolution_pending? && !paused? && resolution_due_at.present? &&
        resolution_due_at <= threshold_minutes.minutes.from_now
    end
  end
end
