namespace :accounts do
  # secret_key_base を変えると、それまでの指紋と一致しなくなるので、全件作り直す
  desc "パスワードの指紋（使い回し検知用）を全件作り直す"
  task refingerprint: :environment do
    Account.find_each do |account|
      account.update_column(:password_fingerprint, Account.fingerprint_for(account.user_id, account.password))
    end
  end
end
