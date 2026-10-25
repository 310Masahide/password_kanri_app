import { loadSettings, fetchAccounts, runInPage } from "./lib.js"

// ツールバーのボタンに、短い印を3秒だけ出す
async function showBadge(tab, text, color) {
  await chrome.action.setBadgeBackgroundColor({ tabId: tab.id, color })
  await chrome.action.setBadgeText({ tabId: tab.id, text })
  setTimeout(() => chrome.action.setBadgeText({ tabId: tab.id, text: "" }), 3000)
}

// ショートカットキーが押されたとき
chrome.commands.onCommand.addListener(async (command, tab) => {
  if (command !== "fill-login" || !tab?.url?.startsWith("http")) return

  const settings = await loadSettings()
  if (!settings.server || !settings.token) {
    chrome.runtime.openOptionsPage()
    return
  }

  const result = await fetchAccounts(settings, new URL(tab.url).hostname)
  if (!result.ok) {
    await showBadge(tab, "!", "#dc3545")
    return
  }

  if (result.accounts.length === 1) {
    // 1つだけなら、すぐに入力する
    const [account] = result.accounts
    const filled = await runInPage(tab, { action: "fill", loginId: account.login_id || "", password: account.password })
    await showBadge(tab, filled.ok ? "OK" : "!", filled.ok ? "#198754" : "#dc3545")
  } else if (result.accounts.length > 1) {
    // 2つ以上あるときは、ポップアップを開いて選んでもらう
    await chrome.action.openPopup().catch(() => showBadge(tab, String(result.accounts.length), "#0d6efd"))
  } else {
    await showBadge(tab, "0", "#6c757d")
  }
})
