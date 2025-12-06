class CreateMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :messages do |t|
      t.bigint :channel_id, null: false
      t.text :text
      t.datetime :message_timestamp, null: false
      t.jsonb :embedding  # Store embedding as JSONB array

      t.timestamps
    end

    add_index :messages, :channel_id
    add_index :messages, :message_timestamp
    add_index :messages, :embedding, using: :gin  # GIN index for JSONB
  end
end
