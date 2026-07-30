# frozen_string_literal: true

module Itsm
  # Calculs de temps en heures ouvrées selon une politique SLA :
  # ajout d'une durée ouvrée à une date, et durée ouvrée écoulée entre deux dates.
  # En mode 24/7 les calculs sont de simples additions calendaires.
  class BusinessTimeCalculator
    def initialize(policy)
      @policy = policy
    end

    def add_minutes(from, minutes)
      add_seconds(from, minutes * 60)
    end

    # Date obtenue en ajoutant `seconds` secondes ouvrées à partir de `from`.
    def add_seconds(from, seconds)
      return from + seconds if @policy.support_24_7?

      remaining = seconds.to_f
      cursor = from

      # Borne de sécurité : 10 ans de jours parcourus au maximum.
      3650.times do
        window = business_window(cursor.to_date)

        if window
          window_start, window_end = window
          cursor = window_start if cursor < window_start

          if cursor < window_end
            available = window_end - cursor
            return cursor + remaining if remaining <= available

            remaining -= available
          end
        end

        cursor = (cursor.to_date + 1).to_time(:local)
      end

      raise "openproject-itsm: calcul d'échéance SLA sans issue (politique ##{@policy.id})"
    end

    # Secondes ouvrées écoulées entre deux dates.
    def seconds_between(from, to)
      return 0 if to <= from
      return (to - from).to_i if @policy.support_24_7?

      total = 0.0
      cursor_date = from.to_date

      while cursor_date <= to.to_date
        window = business_window(cursor_date)

        if window
          window_start, window_end = window
          slice_start = [from, window_start].max
          slice_end = [to, window_end].min
          total += (slice_end - slice_start) if slice_end > slice_start
        end

        cursor_date += 1
      end

      total.to_i
    end

    private

    # [début, fin] de la plage ouvrée du jour, ou nil si jour non travaillé.
    def business_window(date)
      return nil unless @policy.working_day_numbers.include?(date.cwday)
      return nil if @policy.holidays.include?(date)

      base = date.to_time(:local)
      [base + (@policy.day_start_minutes * 60), base + (@policy.day_end_minutes * 60)]
    end
  end
end
