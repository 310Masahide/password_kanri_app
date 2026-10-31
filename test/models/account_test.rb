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

  test "同じパスワードのアカウントがあると、使い回しとして数える" do
    alice = users(:alice)
    first, second = PwnedPasswordChecker.stub(:count, 0) do
      [ alice.accounts.create!(service_name: "A", password: "same-password"),
        alice.accounts.create!(service_name: "B", password: "same-password") ]
    end
    assert_equal 1, first.reused_count
    assert_equal 1, second.reused_count
    assert_includes alice.accounts.reused_fingerprints, first.password_fingerprint
  end

  test "パスワードを変えると、使い回しではなくなる" do
    alice = users(:alice)
    PwnedPasswordChecker.stub(:count, 0) do
      first = alice.accounts.create!(service_name: "A", password: "same-password")
      second = alice.accounts.create!(service_name: "B", password: "same-password")
      second.update!(password: "other-password")
      assert_equal 0, first.reused_count
    end
  end

  test "他人の同じパスワードは使い回しに数えず、指紋も別のものになる" do
    mine, theirs = PwnedPasswordChecker.stub(:count, 0) do
      [ users(:alice).accounts.create!(service_name: "A", password: "same-password"),
        users(:bob).accounts.create!(service_name: "B", password: "same-password") ]
    end
    assert_equal 0, mine.reused_count
    assert_not_equal mine.password_fingerprint, theirs.password_fingerprint
  end

  test "指紋にはパスワードそのものも、ただのハッシュも入らない" do
    account = PwnedPasswordChecker.stub(:count, 0) do
      users(:alice).accounts.create!(service_name: "A", password: "same-password")
    end
    assert_not_includes account.password_fingerprint, "same-password"
    assert_not_equal OpenSSL::Digest::SHA256.hexdigest("same-password"), account.password_fingerprint
  end

  test "再チェックすると、流出回数と確認した日時が更新される" do
    account = accounts(:alice_amazon)
    PwnedPasswordChecker.stub(:count, 5) do
      assert account.recheck_pwned!
    end
    assert_equal 5, account.reload.pwned_count
    assert_not_nil account.pwned_checked_at
  end

  test "再チェックで API が失敗したら、前回の結果を残す" do
    account = accounts(:alice_amazon)
    account.update_columns(pwned_count: 3, pwned_checked_at: 1.day.ago)
    checked_at = account.reload.pwned_checked_at
    PwnedPasswordChecker.stub(:count, nil) do
      assert_not account.recheck_pwned!
    end
    account.reload
    assert_equal 3, account.pwned_count
    assert_equal checked_at, account.pwned_checked_at
  end

  test "長すぎる値は保存できない" do
    account = users(:alice).accounts.build(service_name: "あ" * 101, password: "test1234")
    assert_not account.valid?
    assert_includes account.errors.full_messages, "サービス名は100文字以内で入力してください"

    account = users(:alice).accounts.build(service_name: "テスト", password: "test1234", memo: "あ" * 1001)
    assert_not account.valid?
  end
end
