class Users::SessionsController < Devise::SessionsController
  # 二段階認証を使う人は、パスワードが合っていても、すぐにはログインさせない
  prepend_before_action :start_two_factor, only: :create

  def guest_sign_in
    user = User.guest
    # 誰かがゲストのメールアドレスでログインに失敗し続けても、ゲストログインは使えるようにする
    user.unlock_access! if user.access_locked?
    user.reset_guest_samples!
    sign_in user
    redirect_to accounts_path, notice: "ゲストユーザーとしてログインしました。"
  end

  private

  # 二段階認証を使う人だけ、ここでパスワードを確かめ、コードを入れる画面に進める
  # （使っていない人は、何もせずに Devise のいつものログインに進む）
  def start_two_factor
    user = User.find_by(email: params.dig(:user, :email).to_s.strip.downcase)
    return unless user&.otp_enabled?

    # valid_for_authentication? は、失敗の回数を数えて、5回でロックする（いつものログインと同じ）
    if user.valid_for_authentication? { user.valid_password?(params.dig(:user, :password).to_s) }
      session[:otp_user_id] = user.id
      session[:otp_started_at] = Time.current.to_i
      redirect_to new_users_two_factor_path
    else
      self.resource = User.new(email: user.email)
      flash.now[:alert] = I18n.t("devise.failure.#{user.unauthenticated_message}", authentication_keys: User.human_attribute_name(:email))
      render :new, status: :unprocessable_content
    end
  end
end

