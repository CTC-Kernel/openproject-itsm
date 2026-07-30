# frozen_string_literal: true

module Itsm
  class SlaPolicy < ApplicationRecord
    self.table_name = "itsm_sla_policies"

    belongs_to :project
    belongs_to :priority, class_name: "IssuePriority", optional: true
    has_many :sla_states, class_name: "Itsm::SlaState", foreign_key: :sla_policy_id,
                          dependent: :nullify

    validates :name, presence: true
    validates :response_minutes, :resolution_minutes,
              numericality: { only_integer: true, greater_than: 0 }
    validates :day_start, :day_end, format: { with: /\A\d{1,2}:\d{2}\z/ }
    validates :priority_id, uniqueness: { scope: :project_id }
    validate :validate_day_window

    scope :active, -> { where(active: true) }

    # Politique applicable à un ticket : priorité exacte, sinon politique
    # par défaut du projet (priority_id NULL).
    def self.for(work_package)
      scope = active.where(project_id: work_package.project_id)
      scope.find_by(priority_id: work_package.priority_id) || scope.find_by(priority_id: nil)
    end

    def working_day_numbers
      working_days.to_s.split(",").map(&:to_i).select { |d| (1..7).cover?(d) }
    end

    def holidays
      holiday_dates.to_s.split(/[\n,;]+/).filter_map do |raw|
        Date.iso8601(raw.strip)
      rescue Date::Error
        nil
      end
    end

    def day_start_minutes
      parse_hhmm(day_start)
    end

    def day_end_minutes
      parse_hhmm(day_end)
    end

    private

    def parse_hhmm(value)
      h, m = value.to_s.split(":").map(&:to_i)
      (h * 60) + m
    end

    def validate_day_window
      return if support_24_7?
      return if day_start.blank? || day_end.blank?

      errors.add(:day_end, :invalid) if day_end_minutes <= day_start_minutes
      errors.add(:working_days, :blank) if working_day_numbers.empty?
    end
  end
end
