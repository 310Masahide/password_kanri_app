class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :validatable,
         :lockable, :timeoutable
  has_many :accounts, dependent: :destroy
  has_many :api_tokens, dependent: :destroy

  GUEST_EMAIL = "guest@example.com".freeze

  # ゲストユーザーを探す。いなければ作る
  def self.guest
    find_or_create_by!(email: GUEST_EMAIL) do |user|
      user.password = SecureRandom.urlsafe_base64
    end
  end

  def guest?
    email == GUEST_EMAIL
  end

  # ゲストのデータを、サンプルだけの状態に戻す（前の人が発行したトークンも消す）
  # 流出チェックの結果は決まっているので、固定の値を入れて、ログインのたびに API を呼ばないようにする
  def reset_guest_samples!
    api_tokens.destroy_all
    accounts.destroy_all
    accounts.create!(service_name: "サンプル：ショッピングサイト", login_id: "guest_shop",
                     password: "password", pwned_count: 52_372_427, url: "https://example.com",
                     memo: "よく使われるパスワードの例です。流出チェックで警告が出ます。")
    accounts.create!(service_name: "サンプル：SNS", login_id: "guest_sns",
                     password: SecureRandom.base64(12), pwned_count: 0, url: "https://example.com",
                     memo: "ランダムに作った強いパスワードの例です。")
  end
end
