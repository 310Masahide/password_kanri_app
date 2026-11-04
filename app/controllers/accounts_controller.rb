class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :no_store
  before_action :set_account, only: %i[ show edit update destroy recheck ]

  # GET /accounts
  def index
    # 前に調べてから7日以上たったものを、裏で調べ直す（無料の Render では定期実行が使えないので、一覧を開いたときに行う）
    # ゲストのサンプルは結果が決まっているので、API を呼ばない
    current_user.accounts.request_due_pwned_checks! unless current_user.guest?
    @reused_fingerprints = current_user.accounts.reused_fingerprints
    @pwned_total = current_user.accounts.pwned.count
    @reused_total = current_user.accounts.where(password_fingerprint: @reused_fingerprints).count
    @accounts = current_user.accounts.search(params[:q]).order(:service_name)
    @accounts = @accounts.pwned if params[:filter] == "pwned"
    @accounts = @accounts.where(password_fingerprint: @reused_fingerprints) if params[:filter] == "reused"
  end

  # GET /accounts/1
  def show
  end

  # GET /accounts/new
  def new
    @account = current_user.accounts.build
  end

  # GET /accounts/1/edit
  def edit
  end

  # POST /accounts
  def create
    @account = current_user.accounts.build(account_params)

    if @account.save
      redirect_to @account, notice: "登録しました。"
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /accounts/1
  def update
    if @account.update(account_params)
      redirect_to @account, notice: "更新しました。", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /accounts/1
  def destroy
    @account.destroy!
    redirect_to accounts_path, notice: "削除しました。", status: :see_other
  end

  # POST /accounts/1/recheck
  def recheck
    if @account.recheck_pwned!
      redirect_to @account, notice: "流出チェックをやり直しました。", status: :see_other
    else
      redirect_to @account, alert: "流出チェックができませんでした。前回の結果のままです。", status: :see_other
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_account
      @account = current_user.accounts.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def account_params
      params.require(:account).permit(:service_name, :login_id, :password, :url, :memo)
    end
end
