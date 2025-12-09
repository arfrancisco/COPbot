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

ActiveRecord::Schema[7.0].define(version: 2024_12_09_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "vector"

  create_table "messages", force: :cascade do |t|
    t.string "channel_id", null: false
    t.text "text"
    t.datetime "message_timestamp", null: false
    t.jsonb "embedding"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "channel_name"
    t.vector "embedding_vector", limit: 1536
    t.string "sender_id"
    t.string "sender_name"
    t.string "sender_username"
    t.index ["channel_id"], name: "index_messages_on_channel_id"
    t.index ["channel_name"], name: "index_messages_on_channel_name"
    t.index ["embedding_vector"], name: "index_messages_on_embedding_vector", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["message_timestamp"], name: "index_messages_on_message_timestamp"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
  end

  create_table "user_queries", force: :cascade do |t|
    t.bigint "telegram_user_id"
    t.bigint "telegram_chat_id"
    t.string "username"
    t.text "query_text", null: false
    t.text "response_text"
    t.text "error_message"
    t.integer "search_results_count"
    t.integer "context_message_ids", default: [], array: true
    t.text "context_provided"
    t.text "search_query_used"
    t.string "model_used", default: "gpt-4o"
    t.decimal "temperature"
    t.integer "max_tokens"
    t.integer "prompt_tokens"
    t.integer "completion_tokens"
    t.integer "total_tokens"
    t.datetime "queried_at", null: false
    t.datetime "responded_at"
    t.integer "response_time_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_used"], name: "index_user_queries_on_model_used"
    t.index ["queried_at"], name: "index_user_queries_on_queried_at"
    t.index ["telegram_chat_id"], name: "index_user_queries_on_telegram_chat_id"
    t.index ["telegram_user_id"], name: "index_user_queries_on_telegram_user_id"
  end

end
