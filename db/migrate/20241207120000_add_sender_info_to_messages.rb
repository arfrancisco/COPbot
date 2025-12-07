class AddSenderInfoToMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :messages, :sender_id, :string
    add_column :messages, :sender_name, :string
    add_column :messages, :sender_username, :string

    add_index :messages, :sender_id
  end
end
