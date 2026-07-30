# frozen_string_literal: true

class CreateItsmSlaPolicies < ActiveRecord::Migration[7.1]
  def change
    create_table :itsm_sla_policies do |t|
      t.references :project, null: false, index: true
      t.references :priority, null: true, index: true # IssuePriority ; null = politique par défaut
      t.string :name, null: false
      t.integer :response_minutes, null: false, default: 240
      t.integer :resolution_minutes, null: false, default: 2400
      t.boolean :support_24_7, null: false, default: false
      t.string :day_start, null: false, default: "08:30"   # HH:MM heure locale du serveur
      t.string :day_end, null: false, default: "18:00"
      t.string :working_days, null: false, default: "1,2,3,4,5" # 1=lundi … 7=dimanche
      t.text :holiday_dates # une date ISO (AAAA-MM-JJ) par ligne
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :itsm_sla_policies, %i[project_id priority_id], unique: true,
              name: "index_itsm_sla_policies_uniqueness"
  end
end
