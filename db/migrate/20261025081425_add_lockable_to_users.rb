class AddLockableToUsers < ActiveRecord::Migration[7.1]
  def change
    # Devise の :lockable（ログインに何回も失敗したらロックする）で使う列
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :locked_at, :datetime
  end
end
