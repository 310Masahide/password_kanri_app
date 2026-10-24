class Api::V1::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate_api_token!

  private

  attr_reader :current_user

  # 「Authorization: Bearer トークン」で送られてきたトークンを確かめる
  def authenticate_api_token!
    api_token = authenticate_with_http_token { |token, _options| ApiToken.find_by_token(token) }

    if api_token
      api_token.touch(:last_used_at)
      @current_user = api_token.user
    else
      render json: { error: "トークンが正しくありません" }, status: :unauthorized
    end
  end
end
