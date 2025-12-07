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

ActiveRecord::Schema[7.0].define(version: 2024_12_07_000001) do
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
    t.index ["channel_id"], name: "index_messages_on_channel_id"
    t.index ["channel_name"], name: "index_messages_on_channel_name"
    t.index ["embedding_vector"], name: "index_messages_on_embedding_vector", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["message_timestamp"], name: "index_messages_on_message_timestamp"
  end

end
