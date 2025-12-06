class AddChannelNameToMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :messages, :channel_name, :string
    add_index :messages, :channel_name

    # Also change channel_id to string since we're using composite IDs like "chat_id_thread_id"
    change_column :messages, :channel_id, :string
  end
end
