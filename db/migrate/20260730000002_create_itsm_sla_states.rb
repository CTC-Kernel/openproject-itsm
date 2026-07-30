# frozen_string_literal: true

class CreateItsmSlaStates < ActiveRecord::Migration[7.1]
  def change
    create_table :itsm_sla_states do |t|
      t.references :work_package, null: false, index: { unique: true }
      t.references :sla_policy, null: true, index: true

      t.datetime :started_at, null: false
      t.datetime :response_due_at
      t.datetime :resolution_due_at
      t.datetime :first_responded_at
      t.datetime :resolved_at

      t.datetime :paused_at
      t.integer :paused_seconds, null: false, default: 0

      t.boolean :response_breached, null: false, default: false
      t.boolean :resolution_breached, null: false, default: false
      t.datetime :response_notified_at
      t.datetime :resolution_notified_at

      t.timestamps
    end

    add_index :itsm_sla_states, :resolution_due_at
    add_index :itsm_sla_states, :response_due_at
  end
end
