class ApiTokensController < ApplicationController
  before_action :authenticate_user!
  before_action :no_store
  before_action :ensure_normal_user

  def index
    @token = flash[:token]
    @api_tokens = current_user.api_tokens.order(created_at: :desc)
  end

  # 発行したら一覧に移動する（再読み込みで、もう1本発行されないようにするため）
  # 本物のトークンは flash に入れて、移動した先の画面で1回だけ表示する
  def create
    name = params[:name].to_s.strip.first(50).presence || "Chrome拡張機能"
    _api_token, token = ApiToken.issue!(user: current_user, name: name)
    redirect_to api_tokens_path, flash: { token: token }, status: :see_other
  end

  def destroy
    current_user.api_tokens.find(params[:id]).destroy!
    redirect_to api_tokens_path, notice: "トークンを削除しました。", status: :see_other
  end

  private

  # ゲストユーザーは全員で共有するので、トークンを発行できないようにする
  def ensure_normal_user
    if current_user.guest?
      redirect_to accounts_path, alert: "ゲストユーザーは拡張機能の連携を使えません。"
    end
  end
end
