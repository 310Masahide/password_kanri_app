class AddPasswordFingerprintAndPwnedCheckedAtToAccounts < ActiveRecord::Migration[7.1]
  def up
    add_column :accounts, :password_fingerprint, :string
    add_column :accounts, :pwned_checked_at, :datetime
    add_index :accounts, [:user_id, :password_fingerprint]
  end

  def down
    remove_index :accounts, [:user_id, :password_fingerprint]
    remove_column :accounts, :pwned_checked_at
    remove_column :accounts, :password_fingerprint
  end
end
