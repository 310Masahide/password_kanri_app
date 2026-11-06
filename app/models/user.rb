class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :validatable,
         :lockable, :timeoutable
  has_many :accounts, dependent: :destroy
  has_many :api_tokens, dependent: :destroy

  GUEST_EMAIL = "guest@example.com".freeze

  # 認証アプリに表示される名前
  OTP_ISSUER = "PasswordKanri".freeze
  # 予備コードの数
  RECOVERY_CODE_COUNT = 10

  encrypts :otp_secret
  serialize :otp_recovery_digests, coder: JSON, type: Array

  # ゲストユーザーを探す。いなければ作る
  def self.guest
    find_or_create_by!(email: GUEST_EMAIL) do |user|
      user.password = SecureRandom.urlsafe_base64
    end
  end

  def guest?
    email == GUEST_EMAIL
  end

  def otp_enabled?
    otp_enabled_at.present?
  end

  # 認証アプリに登録するための URL（QR コードにして表示する）
  def self.otp_provisioning_uri(secret, email)
    ROTP::TOTP.new(secret, issuer: OTP_ISSUER).provisioning_uri(email)
  end

  # 認証アプリのコードが正しいかを確かめる。1つ前（30秒前）のコードまで受け付ける
  # 一度使ったコードは、もう使えない（盗み見たコードを使い回されないようにする）
  def self.verify_otp(secret, code, after: nil)
    ROTP::TOTP.new(secret).verify(code.to_s.gsub(/\s/, ""), drift_behind: 30, after: after)
  end

  # 二段階認証を有効にする。コードが正しければ、予備コードを作って返す
  def enable_otp!(secret, code)
    consumed_at = self.class.verify_otp(secret, code)
    return nil unless consumed_at

    codes = Array.new(RECOVERY_CODE_COUNT) { SecureRandom.alphanumeric(10).downcase }
    update!(otp_secret: secret, otp_enabled_at: Time.current, otp_consumed_at: consumed_at,
            otp_recovery_digests: codes.map { |c| digest_recovery_code(c) })
    codes
  end

  def disable_otp!
    update!(otp_secret: nil, otp_enabled_at: nil, otp_consumed_at: nil, otp_recovery_digests: [])
  end

  # ログインのときのコードを確かめる。認証アプリのコードか、予備コード（1回だけ使える）のどちらか
  def verify_otp_or_recovery_code(code)
    return false unless otp_enabled?

    if (consumed_at = self.class.verify_otp(otp_secret, code, after: otp_consumed_at))
      update_column(:otp_consumed_at, consumed_at)
      return true
    end

    digest = digest_recovery_code(code)
    return false unless otp_recovery_digests.include?(digest)

    update!(otp_recovery_digests: otp_recovery_digests - [ digest ])
    true
  end

  # ゲストのデータを、サンプルだけの状態に戻す（前の人が発行したトークンも消す）
  # 流出チェックの結果は決まっているので、固定の値を入れて、ログインのたびに API を呼ばないようにする
  def reset_guest_samples!
    api_tokens.destroy_all
    accounts.destroy_all
    accounts.create!(service_name: "サンプル：ショッピングサイト", login_id: "guest_shop",
                     password: "password", pwned_count: 52_372_427, pwned_checked_at: Time.current, url: "https://example.com",
                     memo: "よく使われるパスワードの例です。流出チェックで警告が出ます。")
    accounts.create!(service_name: "サンプル：SNS", login_id: "guest_sns",
                     password: SecureRandom.base64(12), pwned_count: 0, pwned_checked_at: Time.current, url: "https://example.com",
                     memo: "ランダムに作った強いパスワードの例です。")
  end

  private

  # 予備コードは十分に長いランダムな文字なので、SHA-256 でハッシュ化して保存する
  def digest_recovery_code(code)
    Digest::SHA256.hexdigest(code.to_s.strip.downcase)
  end
end
