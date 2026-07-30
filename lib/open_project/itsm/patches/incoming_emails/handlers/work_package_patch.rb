# frozen_string_literal: true

module OpenProject
  module Itsm
    module Patches
      module IncomingEmails
        module Handlers
          # Routage des emails entrants vers les types ITSM à partir de balises
          # dans le sujet : "[INC]" => Incident, "[DEM]" ou "[SR]" => Demande de
          # service. Le mot-clé explicite "type:" du corps de l'email garde la
          # priorité ; sans balise ni mot-clé, le comportement standard
          # d'OpenProject (premier type du projet) est conservé.
          module WorkPackagePatch
            SUBJECT_TYPE_TAGS = {
              /\[INC\]/i => "Incident",
              /\[(DEM|SR)\]/i => "Demande de service"
            }.freeze

            def self.included(base)
              base.prepend InstanceMethods
            end

            module InstanceMethods
              def wp_type_from_keywords(work_package)
                explicit = lookup_case_insensitive_key(work_package.project.types, :type)
                return explicit if explicit.present?

                itsm_type_id_from_subject(work_package) || super
              end

              private

              def itsm_type_id_from_subject(work_package)
                subject = email&.subject.to_s

                WorkPackagePatch::SUBJECT_TYPE_TAGS.each do |pattern, type_name|
                  next unless subject.match?(pattern)

                  type = work_package.project.types.find_by(name: type_name)
                  return type.id if type
                end

                nil
              end
            end
          end
        end
      end
    end
  end
end
