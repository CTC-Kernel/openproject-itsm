# frozen_string_literal: true

# À exécuter dans le contexte d'OpenProject (le plugin étant dans Gemfile.plugins) :
#   bundle exec rspec vendor/openproject-itsm/spec
require "spec_helper"

RSpec.describe Itsm::BusinessTimeCalculator do
  let(:policy) do
    Itsm::SlaPolicy.new(name: "Test",
                        support_24_7: false,
                        day_start: "09:00",
                        day_end: "17:00",
                        working_days: "1,2,3,4,5",
                        holiday_dates: "2026-01-01")
  end

  subject(:calculator) { described_class.new(policy) }

  describe "#add_minutes" do
    it "reste dans la journée ouvrée quand la durée le permet" do
      # Lundi 5 janvier 2026, 10h00 + 120 min => 12h00
      from = Time.zone.local(2026, 1, 5, 10, 0)
      expect(calculator.add_minutes(from, 120)).to eq Time.zone.local(2026, 1, 5, 12, 0)
    end

    it "reporte sur le jour ouvré suivant" do
      # Lundi 16h00 + 240 min => 1h restant lundi, 3h mardi => mardi 12h00
      from = Time.zone.local(2026, 1, 5, 16, 0)
      expect(calculator.add_minutes(from, 240)).to eq Time.zone.local(2026, 1, 6, 12, 0)
    end

    it "saute le week-end" do
      # Vendredi 9 janvier 16h00 + 120 min => lundi 12 janvier 10h00
      from = Time.zone.local(2026, 1, 9, 16, 0)
      expect(calculator.add_minutes(from, 120)).to eq Time.zone.local(2026, 1, 12, 10, 0)
    end

    it "saute les jours fériés" do
      # Mercredi 31 décembre 2025 16h00 + 120 min : le 1er janvier est férié
      # => vendredi 2 janvier 10h00
      from = Time.zone.local(2025, 12, 31, 16, 0)
      expect(calculator.add_minutes(from, 120)).to eq Time.zone.local(2026, 1, 2, 10, 0)
    end

    it "démarre à l'ouverture quand le début est hors plage" do
      # Samedi => démarre lundi 09h00, +60 min => 10h00
      from = Time.zone.local(2026, 1, 10, 14, 0)
      expect(calculator.add_minutes(from, 60)).to eq Time.zone.local(2026, 1, 12, 10, 0)
    end

    context "en 24/7" do
      before { policy.support_24_7 = true }

      it "additionne simplement la durée" do
        from = Time.zone.local(2026, 1, 10, 14, 0)
        expect(calculator.add_minutes(from, 90)).to eq from + 90.minutes
      end
    end
  end

  describe "#seconds_between" do
    it "compte uniquement le temps ouvré" do
      # Vendredi 16h00 -> lundi 10h00 : 1h vendredi + 1h lundi
      from = Time.zone.local(2026, 1, 9, 16, 0)
      to = Time.zone.local(2026, 1, 12, 10, 0)
      expect(calculator.seconds_between(from, to)).to eq 2.hours.to_i
    end

    it "retourne 0 quand l'intervalle est inversé ou nul" do
      now = Time.zone.local(2026, 1, 5, 10, 0)
      expect(calculator.seconds_between(now, now)).to eq 0
      expect(calculator.seconds_between(now, now - 1.hour)).to eq 0
    end
  end
end
