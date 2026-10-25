const hostElement = document.getElementById("host")
const accountsElement = document.getElementById("accounts")
const settingsLink = document.getElementById("open-settings")
const registerSection = document.getElementById("register")
const registerForm = document.getElementById("register-form")
const serviceNameInput = document.getElementById("service-name")
const loginIdInput = document.getElementById("login-id")
const passwordInput = document.getElementById("password")
const generateButton = document.getElementById("generate")
const readPageButton = document.getElementById("read-page")
const registerMessage = document.getElementById("register-message")

// まぎらわしい文字（0とO、1とlとI）は除いている
const CHARACTERS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*-_"
const PASSWORD_LENGTH = 16

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

// 今開いているタブと、保存してある設定を調べる
const [tab] = await chrome.tabs.query({ active: true, currentWindow: true })
const url = new URL(tab.url)
const { server, token } = await chrome.storage.local.get(["server", "token"])

if (!url.protocol.startsWith("http")) {
  hostElement.textContent = "（このページでは使えません）"
} else if (!server || !token) {
  hostElement.textContent = url.hostname
  showMessage("先に「設定」で、アプリの URL とトークンを保存してください。")
} else {
  hostElement.textContent = url.hostname
  registerSection.hidden = false
  serviceNameInput.value = tab.title || url.hostname
  await showAccounts()
}

// アプリの API を呼ぶ（トークンを付けて送る）
function callApi(path, options = {}) {
  return fetch(`${server}${path}`, {
    ...options,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", ...options.headers }
  })
}

// アプリの API に問い合わせて、このサイトのアカウントを一覧にする
async function showAccounts() {
  showMessage("探しています…")

  let accounts
  try {
    const response = await callApi(`/api/v1/accounts?host=${encodeURIComponent(url.hostname)}`)

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

  accountsElement.replaceChildren(...accounts.map(accountRow))
}

// アカウント1件分の表示を作る
function accountRow(account) {
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
    const result = await runInPage({ action: "fill", loginId: account.login_id || "", password: account.password })
    showMessage(result.message)
    if (result.ok) setTimeout(() => window.close(), 1000)
  })

  row.append(info, button)
  return row
}

// 開いているページの中で、ログインフォームを操作する
async function runInPage(request) {
  try {
    const [result] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: operateLoginForm,
      args: [{ ...request, expectedHost: url.hostname }]
    })
    return result.result
  } catch {
    return { ok: false, message: "このページは操作できませんでした。" }
  }
}

// 強いパスワードを作る
generateButton.addEventListener("click", () => {
  const numbers = new Uint32Array(PASSWORD_LENGTH)
  crypto.getRandomValues(numbers)
  passwordInput.value = Array.from(numbers, (n) => CHARACTERS[n % CHARACTERS.length]).join("")
})

// ページのフォームに入力されている、ログインIDとパスワードを読み取る
readPageButton.addEventListener("click", async () => {
  const result = await runInPage({ action: "read" })
  registerMessage.textContent = result.message
  if (!result.ok) return

  if (result.loginId) loginIdInput.value = result.loginId
  if (result.password) passwordInput.value = result.password
})

// アプリに登録する
registerForm.addEventListener("submit", async (event) => {
  event.preventDefault()
  registerMessage.textContent = "登録しています…"

  try {
    const response = await callApi("/api/v1/accounts", {
      method: "POST",
      body: JSON.stringify({
        account: {
          service_name: serviceNameInput.value,
          login_id: loginIdInput.value,
          password: passwordInput.value,
          // 「?」より後ろには、ログインの合言葉などが入っていることがあるので、保存しない
          url: `${url.origin}${url.pathname}`
        }
      })
    })

    if (response.status === 201) {
      registerMessage.textContent = "登録しました。"
      registerForm.reset()
      registerSection.open = false
      await showAccounts()
    } else if (response.status === 422) {
      const { errors } = await response.json()
      registerMessage.textContent = errors.join(" ")
    } else {
      registerMessage.textContent = `エラーになりました（${response.status}）。`
    }
  } catch {
    registerMessage.textContent = "アプリにつながりませんでした。"
  }
})

// ログインフォームを操作する（この関数は、開いているページの中で動く）
// action が "fill" なら入力し、"read" なら入力されている値を読み取る
function operateLoginForm({ action, expectedHost, loginId, password }) {
  // ボタンを押すまでのあいだに、別のサイトに移動していたら何もしない
  if (location.hostname !== expectedHost) {
    return { ok: false, message: "ページが変わったため、やめました。" }
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

  const passwordField = [...document.querySelectorAll('input[type="password"]')].find(isUsable)

  // パスワードの欄より前にある、いちばん近い欄を、ログインIDの欄とみなす
  // （パスワードの欄がない画面では、最初の入力欄をログインIDの欄とみなす）
  const loginField = passwordField
    ? textInputs(passwordField.form || document)
        .filter((input) => input.compareDocumentPosition(passwordField) & Node.DOCUMENT_POSITION_FOLLOWING)
        .pop()
    : textInputs(document)[0]

  if (action === "read") {
    if (!loginField?.value && !passwordField?.value) {
      return { ok: false, message: "ページに入力されている内容が見つかりませんでした。" }
    }
    return { ok: true, message: "ページから読み取りました。", loginId: loginField?.value, password: passwordField?.value }
  }

  if (!passwordField) {
    if (loginField && loginId) {
      setValue(loginField, loginId)
      return { ok: true, message: "ログインIDを入力しました。" }
    }
    return { ok: false, message: "入力欄が見つかりませんでした。" }
  }

  if (loginField && loginId) setValue(loginField, loginId)
  setValue(passwordField, password)
  return { ok: true, message: "入力しました。" }
}
