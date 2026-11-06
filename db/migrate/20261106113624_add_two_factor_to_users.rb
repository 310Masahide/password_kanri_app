class AddTwoFactorToUsers < ActiveRecord::Migration[8.1]
  def change
    # 認証アプリと共有する秘密の文字列（モデルで暗号化して保存する）
    add_column :users, :otp_secret, :string
    # 二段階認証を有効にした日時（空なら使っていない）
    add_column :users, :otp_enabled_at, :datetime
    # 最後に使ったコードの時刻（同じコードを2回使えないようにする）
    add_column :users, :otp_consumed_at, :integer
    # 予備コードのハッシュ（スマホをなくしたとき用。本物は保存しない）
    add_column :users, :otp_recovery_digests, :text
  end
end
