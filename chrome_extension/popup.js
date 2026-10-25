const hostElement = document.getElementById("host")
const accountsElement = document.getElementById("accounts")
const settingsLink = document.getElementById("open-settings")

settingsLink.addEventListener("click", (event) => {
  event.preventDefault()
  chrome.runtime.openOptionsPage()
})

// ポップアップに、お知らせを1行だけ表示する
function showMessage(text) {
  const p = document.createElement("p")
  p.className = "hint"
  p.textContent = text
  accountsElement.replaceChildren(p)
}

// 今開いているタブのホスト名を調べる
const [tab] = await chrome.tabs.query({ active: true, currentWindow: true })
const url = new URL(tab.url)

if (url.protocol.startsWith("http")) {
  hostElement.textContent = url.hostname
  await showAccounts(url.hostname)
} else {
  hostElement.textContent = "（このページでは使えません）"
}

// アプリの API に問い合わせて、このサイトのアカウントを一覧にする
async function showAccounts(host) {
  const { server, token } = await chrome.storage.local.get(["server", "token"])
  if (!server || !token) {
    showMessage("先に「設定」で、アプリの URL とトークンを保存してください。")
    return
  }

  showMessage("探しています…")

  let accounts
  try {
    const response = await fetch(`${server}/api/v1/accounts?host=${encodeURIComponent(host)}`, {
      headers: { Authorization: `Bearer ${token}` }
    })

    if (response.status === 401) {
      showMessage("トークンが正しくありません。「設定」を確かめてください。")
      return
    }
    if (!response.ok) {
      showMessage(`エラーになりました（${response.status}）。`)
      return
    }
    accounts = await response.json()
  } catch {
    showMessage("アプリにつながりませんでした。")
    return
  }

  if (accounts.length === 0) {
    showMessage("このサイトのアカウントは登録されていません。")
    return
  }

  accountsElement.replaceChildren(...accounts.map((account) => accountRow(account, host)))
}

// アカウント1件分の表示を作る
function accountRow(account, host) {
  const row = document.createElement("div")
  row.className = "account"

  const info = document.createElement("div")
  const name = document.createElement("strong")
  name.textContent = account.service_name
  const loginId = document.createElement("div")
  loginId.className = "hint"
  loginId.textContent = account.login_id || "（ログインIDなし）"
  info.append(name, loginId)

  const button = document.createElement("button")
  button.textContent = "入力"
  button.addEventListener("click", async () => {
    try {
      const [result] = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: fillLoginForm,
        args: [host, account.login_id || "", account.password]
      })
      showMessage(result.result.message)
      if (result.result.ok) setTimeout(() => window.close(), 1000)
    } catch {
      showMessage("このページには入力できませんでした。")
    }
  })

  row.append(info, button)
  return row
}

// ログインフォームに入力する（この関数は、開いているページの中で動く）
function fillLoginForm(expectedHost, loginId, password) {
  // ボタンを押すまでのあいだに、別のサイトに移動していたら入力しない
  if (location.hostname !== expectedHost) {
    return { ok: false, message: "ページが変わったため、入力をやめました。" }
  }

  const isUsable = (input) => input.offsetParent !== null && !input.disabled && !input.readOnly

  // React などで作られたサイトにも入力が伝わるように、値を入れてから「入力した」と知らせる
  const setValue = (input, value) => {
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(input, value)
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.dispatchEvent(new Event("change", { bubbles: true }))
  }

  const textInputs = (scope) =>
    [...scope.querySelectorAll('input[type="email"], input[type="text"], input[type="tel"], input:not([type])')]
      .filter(isUsable)

  const passwordInput = [...document.querySelectorAll('input[type="password"]')].find(isUsable)

  if (!passwordInput) {
    // パスワードの欄がない画面（ログインIDだけを先に入れる画面など）では、ログインIDだけ入れる
    const loginInput = textInputs(document)[0]
    if (loginInput && loginId) {
      setValue(loginInput, loginId)
      return { ok: true, message: "ログインIDを入力しました。" }
    }
    return { ok: false, message: "入力欄が見つかりませんでした。" }
  }

  // パスワードの欄より前にある、いちばん近い欄を、ログインIDの欄とみなす
  const loginInput = textInputs(passwordInput.form || document)
    .filter((input) => input.compareDocumentPosition(passwordInput) & Node.DOCUMENT_POSITION_FOLLOWING)
    .pop()

  if (loginInput && loginId) setValue(loginInput, loginId)
  setValue(passwordInput, password)
  return { ok: true, message: "入力しました。" }
}
