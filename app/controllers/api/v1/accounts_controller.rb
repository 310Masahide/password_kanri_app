class Api::V1::AccountsController < Api::V1::BaseController
  # GET /api/v1/accounts?host=www.example.com
  def index
    accounts = current_user.accounts.order(:service_name).select { |account| account.matches_host?(params[:host]) }

    render json: accounts.map { |account|
      { id: account.id, service_name: account.service_name, login_id: account.login_id, password: account.password }
    }
  end
end
