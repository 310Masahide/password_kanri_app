class Account < ApplicationRecord
  # 流出チェックを調べ直す間隔
  PWNED_RECHECK_INTERVAL = 7.days
  # 予約したチェックが終わらなかったとき（API が失敗した、サーバーが再起動した など）に、もう一度予約するまでの時間
  PWNED_RETRY_INTERVAL = 1.hour

  belongs_to :user
  encrypts :password

  validates :service_name, presence: true, length: { maximum: 100 }
  validates :login_id, length: { maximum: 255 }
  validates :password, presence: true, length: { maximum: 255 }
  validates :url, length: { maximum: 2048 }
  validates :memo, length: { maximum: 1000 }

  before_save :reset_pwned_result, if: :needs_pwned_check?
  after_commit :enqueue_pwned_check, on: %i[ create update ], if: -> { @pwned_check_needed }
  before_save :set_password_fingerprint, if: -> { will_save_change_to_password? || password_fingerprint.nil? }

  # サービス名に、キーワードを含むものだけにしぼる（大文字・小文字は区別しない）
  scope :search, ->(keyword) {
    return all if keyword.blank?

    where("LOWER(service_name) LIKE ?", "%#{sanitize_sql_like(keyword.downcase)}%")
  }

  # 過去に流出したことのあるもの
  scope :pwned, -> { where("pwned_count > 0") }

  # パスワードの「指紋」を作る。暗号化したパスワードは毎回違う文字になり比べられないので、これで比べる
  # 鍵がないと計算できず、指紋から元のパスワードにも戻せない
  # ユーザーIDも混ぜて、別のユーザーと同じパスワードかどうかは分からないようにしている
  def self.fingerprint_for(user_id, password)
    key = Rails.application.key_generator.generate_key("account/password_fingerprint", 32)
    OpenSSL::HMAC.hexdigest("SHA256", key, "#{user_id}:#{password}")
  end

  # 調べ直す時期が来ていて、まだ予約していない（または予約から時間がたった）もの
  scope :pwned_check_due, -> {
    where("pwned_checked_at IS NULL OR pwned_checked_at < ?", PWNED_RECHECK_INTERVAL.ago)
      .where("pwned_check_requested_at IS NULL OR pwned_check_requested_at < ?", PWNED_RETRY_INTERVAL.ago)
  }

  # 調べ直す時期が来たものを、裏で調べ直すように予約する。予約した件数を返す
  # 予約の日時を「時期が来ているものだけ」書き換え、書き換えられたときだけ予約するので、
  # 同時に一覧を開いても、同じアカウントを二重に予約しない
  def self.request_due_pwned_checks!
    pwned_check_due.ids.count do |id|
      claimed = where(id: id).pwned_check_due.update_all(pwned_check_requested_at: Time.current) == 1
      PwnedCheckJob.perform_later(id) if claimed
      claimed
    end
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

  # 裏で流出チェックをしている途中か
  def pwned_check_pending?
    pwned_count.nil? && pwned_check_requested_at.present? && pwned_check_requested_at > PWNED_RETRY_INTERVAL.ago
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

  # 新しく登録したとき、またはパスワードが変わったときに調べる
  # （ゲストのサンプルのように、結果をあらかじめ入れてあるときは調べない）
  def needs_pwned_check?
    return false if will_save_change_to_pwned_count?

    new_record? || will_save_change_to_password?
  end

  # 前のパスワードの結果は使えないので消し、保存が終わったら裏で調べるように印を付ける
  # （保存の途中で API を待たないので、すぐに画面が返る）
  def reset_pwned_result
    self.pwned_count = nil
    self.pwned_checked_at = nil
    self.pwned_check_requested_at = Time.current
    @pwned_check_needed = true
  end

  # データベースへの保存が確定してから予約する（確定前にジョブが動くと、古いデータを調べてしまうため）
  def enqueue_pwned_check
    @pwned_check_needed = false
    PwnedCheckJob.perform_later(id)
  end

  def set_password_fingerprint
    self.password_fingerprint = self.class.fingerprint_for(user_id, password)
  end
end

