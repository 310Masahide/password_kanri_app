class Users::SessionsController < Devise::SessionsController
  def guest_sign_in
    user = User.guest
    # 誰かがゲストのメールアドレスでログインに失敗し続けても、ゲストログインは使えるようにする
    user.unlock_access! if user.access_locked?
    user.reset_guest_samples!
    sign_in user
    redirect_to accounts_path, notice: "ゲストユーザーとしてログインしました。"
  end
end
