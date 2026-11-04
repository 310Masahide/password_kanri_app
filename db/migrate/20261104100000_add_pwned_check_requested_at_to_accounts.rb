class AddPwnedCheckRequestedAtToAccounts < ActiveRecord::Migration[8.1]
  def change
    # 流出チェックを予約した日時（同じチェックを何度も予約しないために使う）
    add_column :accounts, :pwned_check_requested_at, :datetime
  end
end
