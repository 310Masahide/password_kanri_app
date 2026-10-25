class Api::V1::AccountsController < Api::V1::BaseController
  # GET /api/v1/accounts?host=www.example.com
  def index
    accounts = current_user.accounts.order(:service_name).select { |account| account.matches_host?(params[:host]) }

    render json: accounts.map { |account| account_json(account) }
  end

  # POST /api/v1/accounts
  def create
    account = current_user.accounts.build(account_params)

    if account.save
      render json: account_json(account), status: :created
    else
      render json: { errors: account.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def account_params
    params.require(:account).permit(:service_name, :login_id, :password, :url)
  end

  # 拡張機能に返す項目（必要なものだけ）
  def account_json(account)
    { id: account.id, service_name: account.service_name, login_id: account.login_id, password: account.password }
  end
end
