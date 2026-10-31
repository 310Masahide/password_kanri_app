class AddPasswordFingerprintAndPwnedCheckedAtToAccounts < ActiveRecord::Migration[7.1]
  def up
    add_column :accounts, :password_fingerprint, :string
    add_column :accounts, :pwned_checked_at, :datetime
    add_index :accounts, [:user_id, :password_fingerprint]

    # 登録済みのデータにも指紋を付ける（API は呼ばず、updated_at も変えない）
    Account.reset_column_information
    Account.find_each do |account|
      account.update_column(:password_fingerprint, Account.fingerprint_for(account.user_id, account.password))
    end
  end

  def down
    remove_index :accounts, [:user_id, :password_fingerprint]
    remove_column :accounts, :pwned_checked_at
    remove_column :accounts, :password_fingerprint
  end
end
