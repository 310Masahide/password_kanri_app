class ApiTokensController < ApplicationController
  before_action :authenticate_user!
  before_action :no_store
  before_action :ensure_normal_user

  def index
    @api_tokens = current_user.api_tokens.order(created_at: :desc)
  end

  def create
    name = params[:name].to_s.strip.first(50).presence || "Chrome拡張機能"
    _api_token, @token = ApiToken.issue!(user: current_user, name: name)
    @api_tokens = current_user.api_tokens.order(created_at: :desc)
    render :index
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
