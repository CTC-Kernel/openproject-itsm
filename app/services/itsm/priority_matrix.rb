# frozen_string_literal: true

module Itsm
  # Matrice ITIL Impact × Urgence → priorité P1..P4.
  # Les champs personnalisés "Impact" et "Urgence" sont des listes dont les
  # valeurs sont ordonnées de la plus critique (position 1) à la plus faible.
  module PriorityMatrix
    IMPACT_FIELD_NAME = "Impact"
    URGENCY_FIELD_NAME = "Urgence"

    # [impact, urgence] (1 = Critique … 4 = Faible) => niveau de priorité
    MATRIX = {
      [1, 1] => 1, [1, 2] => 1, [1, 3] => 2, [1, 4] => 3,
      [2, 1] => 1, [2, 2] => 2, [2, 3] => 3, [2, 4] => 3,
      [3, 1] => 2, [3, 2] => 3, [3, 3] => 3, [3, 4] => 4,
      [4, 1] => 3, [4, 2] => 3, [4, 3] => 4, [4, 4] => 4
    }.freeze

    PRIORITY_NAMES = {
      1 => "P1 - Critique",
      2 => "P2 - Élevée",
      3 => "P3 - Moyenne",
      4 => "P4 - Faible"
    }.freeze

    module_function

    # Retourne l'IssuePriority à appliquer, ou nil si la matrice ne s'applique
    # pas (champs absents ou non renseignés, priorité introuvable).
    def compute(work_package)
      impact = list_position(work_package, IMPACT_FIELD_NAME)
      urgency = list_position(work_package, URGENCY_FIELD_NAME)
      return nil unless impact && urgency

      level = MATRIX[[impact, urgency]]
      return nil unless level

      IssuePriority.find_by(name: PRIORITY_NAMES[level])
    end

    # Position (1..n) de la valeur sélectionnée dans le champ liste, par ordre
    # des options du champ.
    def list_position(work_package, field_name)
      field = work_package.available_custom_fields.detect do |cf|
        cf.name == field_name && cf.field_format == "list"
      end
      return nil unless field

      value = work_package.custom_value_for(field)&.value
      return nil if value.blank?

      option = field.custom_options.detect { |o| o.id.to_s == value.to_s }
      return nil unless option

      field.custom_options.sort_by(&:position).index(option)&.+ 1
    end
  end
end
