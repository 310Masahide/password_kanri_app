# 二段階認証の設定（有効にする・やめる）
class TwoFactorSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :no_store
  before_action :ensure_normal_user

  def show
    # 有効にした直後だけ、予備コードを1回だけ表示する
    @recovery_codes = flash[:recovery_codes]
  end

  # 新しい秘密の文字列を作り、QR コードを表示する（確認できるまでは、データベースに保存しない）
  def new
    redirect_to two_factor_setting_path and return if current_user.otp_enabled?

    session[:otp_setup_secret] ||= ROTP::Base32.random
    @secret = session[:otp_setup_secret]
    @qr_code = RQRCode::QRCode.new(User.otp_provisioning_uri(@secret, current_user.email))
  end

  # 認証アプリのコードが正しければ、有効にする
  def create
    secret = session[:otp_setup_secret]
    redirect_to new_two_factor_setting_path and return if secret.blank?

    codes = current_user.enable_otp!(secret, params[:code])
    if codes
      session.delete(:otp_setup_secret)
      redirect_to two_factor_setting_path, notice: "二段階認証を有効にしました。", flash: { recovery_codes: codes }, status: :see_other
    else
      @secret = secret
      @qr_code = RQRCode::QRCode.new(User.otp_provisioning_uri(@secret, current_user.email))
      flash.now[:alert] = "コードが正しくありません。認証アプリの最新のコードを入力してください。"
      render :new, status: :unprocessable_content
    end
  end

  # やめるときは、ログインパスワードを確かめる（ログインしたまま離れた席で、勝手に外されないように）
  def destroy
    if current_user.valid_password?(params[:current_password].to_s)
      current_user.disable_otp!
      redirect_to two_factor_setting_path, notice: "二段階認証をやめました。", status: :see_other
    else
      redirect_to two_factor_setting_path, alert: "パスワードが正しくありません。", status: :see_other
    end
  end

  private

  # ゲストユーザーは全員で共有するので、二段階認証を設定できないようにする
  def ensure_normal_user
    if current_user.guest?
      redirect_to accounts_path, alert: "ゲストユーザーは二段階認証を設定できません。"
    end
  end
end
