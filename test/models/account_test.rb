require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "パスワードは暗号化して保存され、読み出すと元に戻る" do
    account = accounts(:alice_amazon)
    assert_not_equal "test1234", account.ciphertext_for(:password)
    assert_equal "test1234", account.password
  end

  test "サービス名が空だと保存できない" do
    account = users(:alice).accounts.build(service_name: "", password: "test1234")
    assert_not account.valid?
  end

  test "パスワードが空だと保存できない" do
    account = users(:alice).accounts.build(service_name: "テスト", password: "")
    assert_not account.valid?
  end

  test "パスワードを保存すると、流出回数が記録される" do
    account = accounts(:alice_amazon)
    PwnedPasswordChecker.stub(:count, 100) do
      account.update!(password: "password")
    end
    assert_equal 100, account.pwned_count
  end

  test "パスワードが変わらないときは、流出チェックをしない" do
    account = accounts(:alice_amazon)
    PwnedPasswordChecker.stub(:count, ->(_password) { flunk "APIを呼んではいけない" }) do
      account.update!(memo: "メモだけ変更")
    end
  end
end
