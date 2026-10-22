class Users::RegistrationsController < Devise::RegistrationsController
  before_action :ensure_normal_user, only: %i[edit update destroy]

  private

  def ensure_normal_user
    if current_user.guest?
      redirect_to root_path, alert: "ゲストユーザーは登録情報の変更・削除ができません。"
    end
  end
end
