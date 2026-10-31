class Account < ApplicationRecord
  belongs_to :user
  encrypts :password

  validates :service_name, presence: true, length: { maximum: 100 }
  validates :login_id, length: { maximum: 255 }
  validates :password, presence: true, length: { maximum: 255 }
  validates :url, length: { maximum: 2048 }
  validates :memo, length: { maximum: 1000 }

  before_save :check_pwned_password, if: :needs_pwned_check?
  before_save :set_password_fingerprint, if: -> { will_save_change_to_password? || password_fingerprint.nil? }

  # サービス名に、キーワードを含むものだけにしぼる（大文字・小文字は区別しない）
  scope :search, ->(keyword) {
    return all if keyword.blank?

    where("LOWER(service_name) LIKE ?", "%#{sanitize_sql_like(keyword.downcase)}%")
  }

  # パスワードの「指紋」を作る。暗号化したパスワードは毎回違う文字になり比べられないので、これで比べる
  # 鍵がないと計算できず、指紋から元のパスワードにも戻せない
  # ユーザーIDも混ぜて、別のユーザーと同じパスワードかどうかは分からないようにしている
  def self.fingerprint_for(user_id, password)
    key = Rails.application.key_generator.generate_key("account/password_fingerprint", 32)
    OpenSSL::HMAC.hexdigest("SHA256", key, "#{user_id}:#{password}")
  end

  # 2件以上で使われている指紋の一覧（一覧画面で、1件ずつ数えなくて済むようにする）
  def self.reused_fingerprints
    where.not(password_fingerprint: nil).group(:password_fingerprint).having("COUNT(*) > 1").pluck(:password_fingerprint)
  end

  # 同じパスワードを使っている、自分のほかのアカウントの数
  def reused_count
    return 0 if password_fingerprint.nil?

    user.accounts.where(password_fingerprint: password_fingerprint).where.not(id: id).count
  end

  # 流出チェックをやり直す。調べられなかったときは、前回の結果を残して false を返す
  def recheck_pwned!
    count = PwnedPasswordChecker.count(password)
    return false if count.nil?

    update!(pwned_count: count, pwned_checked_at: Time.current)
  end

  # 登録した URL のホスト名が、指定したホスト名と一致するか（先頭の「www.」と大文字・小文字の違いは無視する）
  def matches_host?(host)
    return false if host.blank? || url.blank?

    registered_host = URI.parse(url).host
    registered_host.present? && normalize_host(registered_host) == normalize_host(host)
  rescue URI::InvalidURIError
    false
  end

  private

  def normalize_host(host)
    host.downcase.delete_prefix("www.")
  end

  # パスワードが変わったとき、またはまだ調べられていないときに調べる
  # （ゲストのサンプルのように、結果をあらかじめ入れてあるときは調べない）
  def needs_pwned_check?
    pwned_count.nil? || (will_save_change_to_password? && !will_save_change_to_pwned_count?)
  end

  def check_pwned_password
    self.pwned_count = PwnedPasswordChecker.count(password)
    self.pwned_checked_at = pwned_count && Time.current
  end

  def set_password_fingerprint
    self.password_fingerprint = self.class.fingerprint_for(user_id, password)
  end
end

