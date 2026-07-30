# frozen_string_literal: true

module OpenProject
  module Itsm
    module Patches
      module WorkPackagePatch
        def self.included(base)
          base.class_eval do
            has_one :itsm_sla_state,
                    class_name: "Itsm::SlaState",
                    dependent: :destroy

            before_save :itsm_apply_priority_matrix
            after_save :itsm_apply_sla
          end

          base.include InstanceMethods
        end

        module InstanceMethods
          def itsm_ticket?
            type.present? &&
              ::Itsm::Config.itsm_type_names.include?(type.name) &&
              project.present? &&
              project.module_enabled?(:itsm)
          end

          private

          # Priorité dérivée de la matrice ITIL Impact × Urgence quand les deux
          # champs personnalisés sont renseignés.
          def itsm_apply_priority_matrix
            return unless itsm_ticket?

            priority = ::Itsm::PriorityMatrix.compute(self)
            self.priority = priority if priority
          rescue StandardError => e
            Rails.logger.error "openproject-itsm: matrice de priorité en échec pour WP##{id}: #{e.message}"
          end

          def itsm_apply_sla
            return unless itsm_ticket?
            return unless saved_change_to_id? || saved_change_to_status_id? || saved_change_to_priority_id?

            ::Itsm::ApplySlaService.new(self).call
          rescue StandardError => e
            Rails.logger.error "openproject-itsm: application SLA en échec pour WP##{id}: #{e.message}"
          end
        end
      end
    end
  end
end
