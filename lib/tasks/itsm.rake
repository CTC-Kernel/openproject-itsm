# frozen_string_literal: true

# Provisionnement des données ITSM (idempotent) :
#   bundle exec rake openproject_itsm:seed
#   bundle exec rake "openproject_itsm:setup_project[acme]"
#   bundle exec rake openproject_itsm:check_sla
namespace :openproject_itsm do
  STATUSES = [
    { name: "Nouveau", is_closed: false },
    { name: "En cours", is_closed: false },
    { name: "En attente client", is_closed: false },
    { name: "En attente tiers", is_closed: false },
    { name: "Résolu", is_closed: false },
    { name: "Fermé", is_closed: true }
  ].freeze

  PRIORITIES = ["P1 - Critique", "P2 - Élevée", "P3 - Moyenne", "P4 - Faible"].freeze

  TYPES = ["Incident", "Demande de service"].freeze

  LIST_LEVELS = ["Critique", "Élevé", "Moyen", "Faible"].freeze

  desc "Crée les statuts, priorités, types, champs personnalisés et workflows ITSM"
  task seed: :environment do
    statuses = STATUSES.map do |attrs|
      Status.find_by(name: attrs[:name]) ||
        Status.create!(name: attrs[:name], is_closed: attrs[:is_closed])
    end
    puts "Statuts : #{statuses.map(&:name).join(', ')}"

    PRIORITIES.each_with_index do |name, index|
      IssuePriority.find_by(name: name) ||
        IssuePriority.create!(name: name, position: index + 1)
    end
    puts "Priorités : #{PRIORITIES.join(', ')}"

    types = TYPES.map do |name|
      Type.find_by(name: name) || Type.create!(name: name, is_in_roadmap: false)
    end
    puts "Types : #{types.map(&:name).join(', ')}"

    custom_fields = %w[Impact Urgence].map do |name|
      WorkPackageCustomField.find_by(name: name) ||
        WorkPackageCustomField.create!(name: name,
                                       field_format: "list",
                                       possible_values: LIST_LEVELS,
                                       is_required: false,
                                       is_for_all: true)
    end

    ci_field = WorkPackageCustomField.find_by(name: "Élément de configuration") ||
               WorkPackageCustomField.create!(name: "Élément de configuration",
                                              field_format: "string",
                                              is_required: false,
                                              is_for_all: true)
    custom_fields << ci_field

    channel_field = WorkPackageCustomField.find_by(name: "Canal") ||
                    WorkPackageCustomField.create!(name: "Canal",
                                                   field_format: "list",
                                                   possible_values: %w[Portail Email Téléphone Supervision],
                                                   is_required: false,
                                                   is_for_all: true)
    custom_fields << channel_field

    types.each do |type|
      type.custom_field_ids |= custom_fields.map(&:id)
      type.save!
    end
    puts "Champs personnalisés : #{custom_fields.map(&:name).join(', ')}"

    # Workflows : toutes les transitions entre statuts ITSM, pour chaque rôle
    # attribuable et chaque type ITSM.
    status_ids = statuses.map(&:id)
    created = 0
    Role.givable.find_each do |role|
      types.each do |type|
        status_ids.product(status_ids).each do |old_id, new_id|
          next if old_id == new_id
          next if Workflow.exists?(role_id: role.id, type_id: type.id,
                                   old_status_id: old_id, new_status_id: new_id)

          Workflow.create!(role_id: role.id, type_id: type.id,
                           old_status_id: old_id, new_status_id: new_id)
          created += 1
        end
      end
    end
    puts "Workflows : #{created} transitions créées"
    puts "Terminé. Pensez à activer le module ITSM dans chaque projet client."
  end

  desc "Active le module ITSM sur un projet et crée les SLA par défaut (infogérance)"
  task :setup_project, [:identifier, :name] => :environment do |_t, args|
    project = Project.find_by(identifier: args[:identifier])
    if project.nil?
      attrs = { identifier: args[:identifier],
                name: args[:name].presence || args[:identifier].capitalize,
                public: false }
      # OpenProject >= 16 distingue projet / programme / portefeuille.
      attrs[:workspace_type] = "project" if Project.new.respond_to?(:workspace_type)
      project = Project.create!(attrs)
    end

    project.enabled_module_names |= %w[itsm work_package_tracking]
    project.types |= Type.where(name: TYPES)
    project.save!

    # SLA par défaut heures ouvrées 8h30-18h, lun-ven (à ajuster selon contrat).
    defaults = {
      "P1 - Critique" => [30, 240],
      "P2 - Élevée" => [60, 480],
      "P3 - Moyenne" => [240, 1200],
      "P4 - Faible" => [480, 2400]
    }

    defaults.each do |priority_name, (response, resolution)|
      priority = IssuePriority.find_by(name: priority_name)
      next unless priority
      next if Itsm::SlaPolicy.exists?(project: project, priority: priority)

      Itsm::SlaPolicy.create!(project: project,
                              priority: priority,
                              name: "SLA #{priority_name}",
                              response_minutes: response,
                              resolution_minutes: resolution)
    end

    puts "Projet #{project.name} : module ITSM activé, types et SLA par défaut en place."
  end

  desc "Vérifie les dépassements de SLA (repli si le cron interne est indisponible)"
  task check_sla: :environment do
    Itsm::SlaCheckJob.perform_now
    puts "Vérification SLA effectuée."
  end
end
