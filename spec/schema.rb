ActiveRecord::Schema.define do
  self.verbose = false

  create_table :aeternitas_pollable_meta_data, force: true do |t|
    t.string :pollable_type, null: false
    t.integer :pollable_id, null: false
    t.string :pollable_class, null: false
    t.datetime :next_polling, null: false, default: "1970-01-01 00:00:00"
    t.datetime :last_polling
    t.string :state
    t.text :deactivation_reason
    t.datetime :deactivated_at

    t.timestamps
  end
  add_index :aeternitas_pollable_meta_data, [:pollable_id, :pollable_type], name: "aeternitas_pollable_unique", unique: true
  add_index :aeternitas_pollable_meta_data, [:next_polling, :state], name: "aeternitas_pollable_enqueueing"
  add_index :aeternitas_pollable_meta_data, [:pollable_class], name: "aeternitas_pollable_class"

  create_table :aeternitas_sources, id: :string, primary_key: :fingerprint, force: true do |t|
    t.string :pollable_type, null: false
    t.integer :pollable_id, null: false
    t.datetime :created_at
  end
  add_index :aeternitas_sources, [:pollable_id, :pollable_type], name: "aeternitas_pollable_source"

  create_table :full_pollables, force: true do |t|
    t.string :name
    t.timestamps
    t.string :type
  end

  create_table :simple_pollables, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :aeternitas_unique_job_locks, force: true do |t|
    t.string :lock_digest, null: false
    t.string :guard_key_digest
    t.string :job_id
    t.datetime :expires_at, null: false

    t.timestamps
  end
  add_index :aeternitas_unique_job_locks, :lock_digest, unique: true
  add_index :aeternitas_unique_job_locks, :guard_key_digest
  add_index :aeternitas_unique_job_locks, :expires_at

  create_table :aeternitas_guard_locks, force: true do |t|
    t.string :lock_key, null: false
    t.string :state, null: false
    t.string :token, null: false, limit: 20
    t.datetime :locked_until, null: false
    t.text :reason

    t.timestamps
  end
  add_index :aeternitas_guard_locks, :lock_key, unique: true
  add_index :aeternitas_guard_locks, :locked_until

  create_table :aeternitas_metrics, force: true do |t|
    t.string :name, null: false
    t.string :pollable_class, null: false
    t.float :value, null: false
    t.datetime :created_at, null: false
  end
  add_index :aeternitas_metrics, [:name, :pollable_class, :created_at]
end
