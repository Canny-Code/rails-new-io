class CreateAcidicJobTables < ActiveRecord::Migration[8.0]
  def change
    create_table :acidic_job_executions, force: true do |t|
      t.string      :idempotency_key, null: false,  index: { unique: true }
      t.json        :serialized_job, 	null: false,  default: "{}"
      t.datetime    :last_run_at, 		null: true
      t.datetime    :locked_at, 			null: true
      t.string      :recover_to, 	    null: true
      t.json        :definition, 			null: true,   default: "{}"
      t.timestamps
    end

    create_table :acidic_job_entries do |t|
      t.references :execution, null: false, foreign_key: { to_table: :acidic_job_executions }
      t.string :step, null: false
      t.string :action, null: false
      t.datetime :timestamp, null: false
      t.json :data

      t.timestamps
    end
    add_index :acidic_job_entries, [ :execution_id, :step ]

    create_table :acidic_job_values do |t|
      t.references :execution, null: false, foreign_key: { to_table: :acidic_job_executions }
      t.string :key, null: false
      t.json :value, null: false,   default: "{}"

      t.timestamps
    end
    add_index :acidic_job_values, [ :execution_id, :key ], unique: true
  end
end
