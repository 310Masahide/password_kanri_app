class CreateAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :accounts do |t|
      t.string :service_name
      t.string :login_id
      t.string :password
      t.string :url
      t.text :memo
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
