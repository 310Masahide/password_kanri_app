require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # 画面を出さないブラウザ（ヘッドレス Chrome）で動かす。GitHub Actions でもそのまま動く
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  include Devise::Test::IntegrationHelpers

  private

  # このテストのブラウザに、クリップボードの読み書きを許可する（ふつうは人が許可を押す）
  def allow_clipboard
    page.driver.browser.execute_cdp(
      "Browser.grantPermissions",
      origin: Capybara.current_session.server.base_url,
      permissions: %w[ clipboardReadWrite clipboardSanitizedWrite ]
    )
  end

  # クリップボードの中身を読む
  def clipboard_text
    page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")
  end
end

