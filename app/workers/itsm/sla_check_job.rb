# frozen_string_literal: true

module Itsm
  # Vérification périodique des dépassements de SLA : marque les tickets en
  # dépassement et notifie une seule fois par échéance (réponse / résolution).
  # Planifié toutes les 10 minutes via GoodJob (voir engine.rb).
  class SlaCheckJob < ::ApplicationJob
    queue_with_priority :low

    def perform
      now = Time.zone.now

      check_response_breaches(now)
      check_resolution_breaches(now)
    end

    private

    def check_response_breaches(now)
      Itsm::SlaState.running
                    .where(first_responded_at: nil, response_notified_at: nil)
                    .where("response_due_at <= ?", now)
                    .includes(work_package: %i[project status assigned_to])
                    .find_each do |state|
        state.update_columns(response_breached: true, response_notified_at: now)
        notify(state, :response)
      end
    end

    def check_resolution_breaches(now)
      Itsm::SlaState.running
                    .where(resolution_notified_at: nil)
                    .where("resolution_due_at <= ?", now)
                    .includes(work_package: %i[project status assigned_to])
                    .find_each do |state|
        state.update_columns(resolution_breached: true, resolution_notified_at: now)
        notify(state, :resolution)
      end
    end

    def notify(state, kind)
      recipients(state).each do |user|
        Itsm::SlaMailer.breach_alert(user, state, kind).deliver_later
      end
    rescue StandardError => e
      Rails.logger.error "openproject-itsm: notification SLA en échec (state ##{state.id}): #{e.message}"
    end

    def recipients(state)
      wp = state.work_package
      users = [wp.assigned_to, wp.responsible].compact.uniq
      users.select { |u| u.is_a?(User) && u.active? && u.mail.present? }
    end
  end
end
