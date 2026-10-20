class AddPwnedCountToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :pwned_count, :integer
  end
end
