# ログインの2段階目：パスワードが合った人に、認証アプリのコードを入れてもらう
class Users::TwoFactorController < ApplicationController
  # パスワードの確認から5分たったら、最初からやり直してもらう
  TIME_LIMIT = 5.minutes

  before_action :no_store
  before_action :set_pending_user

  def new
  end

  def create
    # 間違えた回数は、パスワードの間違いと合わせて数え、5回でロックする
    if @user.valid_for_authentication? { @user.verify_otp_or_recovery_code(params[:code]) }
      session.delete(:otp_user_id)
      session.delete(:otp_started_at)
      sign_in(:user, @user)
      redirect_to after_sign_in_path_for(@user), notice: I18n.t("devise.sessions.signed_in")
    elsif @user.access_locked?
      clear_pending
      redirect_to new_user_session_path, alert: I18n.t("devise.failure.locked")
    else
      flash.now[:alert] = "コードが正しくありません。"
      render :new, status: :unprocessable_content
    end
  end

  private

  def set_pending_user
    started_at = session[:otp_started_at].to_i
    @user = User.find_by(id: session[:otp_user_id]) if started_at > TIME_LIMIT.ago.to_i

    unless @user&.otp_enabled?
      clear_pending
      redirect_to new_user_session_path, alert: "もう一度ログインしてください。"
    end
  end

  def clear_pending
    session.delete(:otp_user_id)
    session.delete(:otp_started_at)
  end
end
