class Users::SessionsController < Devise::SessionsController
  def guest_sign_in
    user = User.guest
    user.reset_guest_samples!
    sign_in user
    redirect_to accounts_path, notice: "ゲストユーザーとしてログインしました。"
  end
end
