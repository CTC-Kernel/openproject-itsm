# frozen_string_literal: true

module Itsm
  # Accès typé aux réglages globaux du plugin (Administration → Plugins → ITSM).
  module Config
    module_function

    def settings
      Setting.plugin_openproject_itsm || {}
    end

    def itsm_type_names
      name_list("itsm_type_names", "Incident,Demande de service")
    end

    def response_status_names
      name_list("response_status_names", "En cours")
    end

    def paused_status_names
      name_list("paused_status_names", "En attente client,En attente tiers")
    end

    def resolved_status_names
      name_list("resolved_status_names", "Résolu,Fermé")
    end

    def at_risk_threshold_minutes
      settings["at_risk_threshold_minutes"].to_i.clamp(1, 100_000)
    rescue StandardError
      240
    end

    def name_list(key, default)
      raw = settings[key].presence || default
      raw.split(",").map(&:strip).reject(&:blank?)
    end
  end
end
