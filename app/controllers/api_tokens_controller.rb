class ApiTokensController < ApplicationController
  before_action :authenticate_user!

  def index
    @api_tokens = current_user.api_tokens.order(created_at: :desc)
  end

  def create
    name = params[:name].presence || "Chrome拡張機能"
    _api_token, @token = ApiToken.issue!(user: current_user, name: name)
    @api_tokens = current_user.api_tokens.order(created_at: :desc)
    render :index
  end

  def destroy
    current_user.api_tokens.find(params[:id]).destroy!
    redirect_to api_tokens_path, notice: "トークンを削除しました。", status: :see_other
  end
end
