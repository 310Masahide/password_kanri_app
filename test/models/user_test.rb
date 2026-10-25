require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "ログインパスワードは12文字以上でないと登録できない" do
    assert_not User.new(email: "short@example.com", password: "a" * 11).valid?
    assert User.new(email: "long@example.com", password: "a" * 12).valid?
  end
end
