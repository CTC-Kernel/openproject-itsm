# frozen_string_literal: true

module Itsm
  module ItsmHelper
    # Badge de priorité P1..P4 (couleur + texte, jamais la couleur seule).
    def itsm_priority_badge(priority_name)
      css = { "P1" => "-p1", "P2" => "-p2", "P3" => "-p3", "P4" => "-p4" }
            .fetch(priority_name.to_s[0, 2], "-p4")
      tag.span(priority_name, class: "op-itsm-badge #{css}")
    end

    # Durée compacte lisible : "45 min", "3 h 20", "2 j 4 h".
    def itsm_duration_short(seconds)
      return "—" if seconds.nil?

      minutes = (seconds / 60).round
      if minutes < 60
        "#{minutes} min"
      elsif minutes < 1440
        h, m = minutes.divmod(60)
        m.zero? ? "#{h} h" : "#{h} h #{format('%02d', m)}"
      else
        d, rest = minutes.divmod(1440)
        "#{d} j #{rest / 60} h"
      end
    end

    # Échéance relative : "dans 2 h 30" / "dépassée de 45 min" / "—".
    def itsm_due_label(due_at)
      return "—" if due_at.nil?

      delta = due_at - Time.zone.now
      if delta.negative?
        tag.span("#{t('itsm.dashboard.overdue_by')} #{itsm_duration_short(-delta)}",
                 class: "op-itsm-due -overdue")
      else
        tag.span("#{t('itsm.dashboard.due_in')} #{itsm_duration_short(delta)}",
                 class: "op-itsm-due")
      end
    end
  end
end
