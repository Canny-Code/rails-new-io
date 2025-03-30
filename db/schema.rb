# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_03_30_100505) do
  create_table "_litestream_lock", id: false, force: :cascade do |t|
    t.integer "id"
  end

  create_table "_litestream_seq", force: :cascade do |t|
    t.integer "seq"
  end

  create_table "_litestream_verification", force: :cascade do |t|
    t.binary "uuid"
  end

  create_table "acidic_job_entries", force: :cascade do |t|
    t.integer "execution_id", null: false
    t.string "step", null: false
    t.string "action", null: false
    t.datetime "timestamp", null: false
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["execution_id", "step"], name: "index_acidic_job_entries_on_execution_id_and_step"
    t.index ["execution_id"], name: "index_acidic_job_entries_on_execution_id"
  end

  create_table "acidic_job_executions", force: :cascade do |t|
    t.string "idempotency_key", null: false
    t.json "serialized_job", default: "{}", null: false
    t.datetime "last_run_at"
    t.datetime "locked_at"
    t.string "recover_to"
    t.json "definition", default: "{}"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_acidic_job_executions_on_idempotency_key", unique: true
  end

  create_table "acidic_job_values", force: :cascade do |t|
    t.integer "execution_id", null: false
    t.string "key", null: false
    t.json "value", default: "{}", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["execution_id", "key"], name: "index_acidic_job_values_on_execution_id_and_key", unique: true
    t.index ["execution_id"], name: "index_acidic_job_values_on_execution_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "app_changes", force: :cascade do |t|
    t.integer "generated_app_id", null: false
    t.json "configuration"
    t.datetime "applied_at"
    t.boolean "success"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "recipe_change_id"
    t.index ["generated_app_id"], name: "index_app_changes_on_generated_app_id"
    t.index ["recipe_change_id"], name: "index_app_changes_on_recipe_change_id"
  end

  create_table "app_generation_log_entries", force: :cascade do |t|
    t.integer "generated_app_id", null: false
    t.string "level", null: false
    t.string "phase", null: false
    t.text "message", null: false
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "entry_type"
    t.index ["entry_type"], name: "index_app_generation_log_entries_on_entry_type"
    t.index ["generated_app_id", "created_at"], name: "idx_on_generated_app_id_created_at_eac7d7a1a2"
    t.index ["generated_app_id"], name: "index_app_generation_log_entries_on_generated_app_id"
  end

  create_table "app_statuses", force: :cascade do |t|
    t.integer "generated_app_id", null: false
    t.string "status", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.json "status_history", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generated_app_id"], name: "index_app_statuses_on_generated_app_id"
    t.index ["status"], name: "index_app_statuses_on_status"
  end

  create_table "commits", force: :cascade do |t|
    t.string "sha", null: false
    t.text "message", null: false
    t.json "state_snapshot", null: false
    t.string "parent_sha"
    t.integer "author_id", null: false
    t.string "versioned_type", null: false
    t.integer "versioned_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_commits_on_author_id"
    t.index ["sha"], name: "index_commits_on_sha", unique: true
    t.index ["versioned_type", "versioned_id"], name: "index_commits_on_versioned"
  end

  create_table "element_custom_ingredient_checkboxes", force: :cascade do |t|
    t.boolean "checked"
    t.boolean "default"
    t.integer "ingredient_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient_id"], name: "index_element_custom_ingredient_checkboxes_on_ingredient_id"
  end

  create_table "element_radio_buttons", force: :cascade do |t|
    t.boolean "default"
    t.string "selected_option"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "element_rails_flag_checkboxes", force: :cascade do |t|
    t.boolean "default"
    t.boolean "checked"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "display_when", default: "checked"
  end

  create_table "element_text_fields", force: :cascade do |t|
    t.string "default_value"
    t.string "value"
    t.integer "max_length"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "element_unclassifieds", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "elements", force: :cascade do |t|
    t.string "label", null: false
    t.integer "sub_group_id"
    t.string "variant_type"
    t.string "variant_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.string "image_path"
    t.integer "position"
    t.string "command_line_value"
    t.index ["command_line_value"], name: "index_elements_on_command_line_value"
    t.index ["label"], name: "index_elements_on_label"
    t.index ["position"], name: "index_elements_on_position"
    t.index ["sub_group_id"], name: "index_elements_on_sub_group_id"
    t.index ["variant_type", "variant_id"], name: "index_elements_on_variant_type_and_variant_id"
  end

  create_table "generated_apps", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "user_id", null: false
    t.json "selected_gems", default: [], null: false
    t.json "configuration_options", default: {}, null: false
    t.string "github_repo_url"
    t.string "github_repo_name"
    t.string "build_log_url"
    t.datetime "last_build_at"
    t.boolean "is_public", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "workspace_path"
    t.integer "recipe_id", null: false
    t.string "generated_with_recipe_version", default: "unknown", null: false
    t.index ["github_repo_url"], name: "index_generated_apps_on_github_repo_url", unique: true
    t.index ["name"], name: "index_generated_apps_on_name"
    t.index ["recipe_id"], name: "index_generated_apps_on_recipe_id"
    t.index ["user_id", "name"], name: "index_generated_apps_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_generated_apps_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "title", null: false
    t.integer "page_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "behavior_type"
    t.string "description"
    t.index ["page_id"], name: "index_groups_on_page_id"
    t.index ["title"], name: "index_groups_on_title"
  end

  create_table "ingredient_changes", force: :cascade do |t|
    t.integer "ingredient_id", null: false
    t.string "change_type", null: false
    t.json "change_data", null: false
    t.text "description"
    t.datetime "applied_at"
    t.boolean "success"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient_id"], name: "index_ingredient_changes_on_ingredient_id"
  end

  create_table "ingredients", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.text "template_content", null: false
    t.text "conflicts_with"
    t.text "requires"
    t.text "configures_with"
    t.integer "created_by_id", null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "snippets", default: []
    t.integer "page_id"
    t.index ["created_by_id"], name: "index_ingredients_on_created_by_id"
    t.index ["name", "created_by_id"], name: "index_ingredients_on_name_and_created_by_id", unique: true
    t.index ["page_id"], name: "index_ingredients_on_page_id"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.string "type"
    t.string "record_type"
    t.bigint "record_id"
    t.json "params"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "notifications_count"
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.string "type"
    t.bigint "event_id", null: false
    t.string "recipient_type", null: false
    t.bigint "recipient_id", null: false
    t.datetime "read_at", precision: nil
    t.datetime "seen_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "pages", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position", default: 0, null: false
    t.index ["position"], name: "index_pages_on_position"
    t.index ["slug"], name: "index_pages_on_slug", unique: true
    t.index ["title"], name: "index_pages_on_title"
  end

  create_table "recipe_changes", force: :cascade do |t|
    t.integer "recipe_id", null: false
    t.integer "ingredient_id"
    t.string "change_type", null: false
    t.json "change_data", null: false
    t.text "description"
    t.datetime "applied_at"
    t.boolean "success"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient_id"], name: "index_recipe_changes_on_ingredient_id"
    t.index ["recipe_id"], name: "index_recipe_changes_on_recipe_id"
  end

  create_table "recipe_ingredients", force: :cascade do |t|
    t.integer "recipe_id", null: false
    t.integer "ingredient_id", null: false
    t.integer "position", null: false
    t.json "configuration"
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ingredient_id"], name: "index_recipe_ingredients_on_ingredient_id"
    t.index ["recipe_id", "position"], name: "index_recipe_ingredients_on_recipe_id_and_position", unique: true
    t.index ["recipe_id"], name: "index_recipe_ingredients_on_recipe_id"
  end

  create_table "recipes", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "cli_flags"
    t.string "ruby_version"
    t.string "rails_version"
    t.string "status", default: "draft"
    t.string "head_commit_sha"
    t.integer "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "ui_state", default: {}
    t.index ["created_by_id"], name: "index_recipes_on_created_by_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.integer "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.integer "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.integer "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.integer "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.integer "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.integer "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "sub_groups", force: :cascade do |t|
    t.string "title", null: false
    t.integer "group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_sub_groups_on_group_id"
    t.index ["title"], name: "index_sub_groups_on_title"
  end

  create_table "users", force: :cascade do |t|
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "email"
    t.string "image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.text "github_token"
    t.string "github_username", null: false
    t.boolean "admin", default: false, null: false
    t.index ["github_username"], name: "index_users_on_github_username", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  add_foreign_key "acidic_job_entries", "acidic_job_executions", column: "execution_id"
  add_foreign_key "acidic_job_values", "acidic_job_executions", column: "execution_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "app_changes", "generated_apps", on_delete: :cascade
  add_foreign_key "app_changes", "recipe_changes", on_delete: :cascade
  add_foreign_key "app_generation_log_entries", "generated_apps", on_delete: :cascade
  add_foreign_key "app_statuses", "generated_apps", on_delete: :cascade
  add_foreign_key "commits", "users", column: "author_id"
  add_foreign_key "element_custom_ingredient_checkboxes", "ingredients"
  add_foreign_key "elements", "sub_groups"
  add_foreign_key "generated_apps", "recipes"
  add_foreign_key "generated_apps", "users"
  add_foreign_key "groups", "pages"
  add_foreign_key "ingredient_changes", "ingredients", on_delete: :cascade
  add_foreign_key "ingredients", "pages"
  add_foreign_key "ingredients", "users", column: "created_by_id"
  add_foreign_key "recipe_changes", "ingredients"
  add_foreign_key "recipe_changes", "recipes", on_delete: :cascade
  add_foreign_key "recipe_ingredients", "ingredients"
  add_foreign_key "recipe_ingredients", "recipes"
  add_foreign_key "recipes", "users", column: "created_by_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "sub_groups", "groups"
end
