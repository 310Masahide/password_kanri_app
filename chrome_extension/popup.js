import { loadSettings, callApi, fetchAccounts, runInPage } from "./lib.js"

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
const settings = await loadSettings()

if (!url.protocol.startsWith("http")) {
  hostElement.textContent = "（このページでは使えません）"
} else if (!settings.server || !settings.token) {
  hostElement.textContent = url.hostname
  showMessage("先に「設定」で、アプリの URL とトークンを保存してください。")
} else {
  hostElement.textContent = url.hostname
  registerSection.hidden = false
  serviceNameInput.value = tab.title || url.hostname
  await showAccounts()
}

// このサイトのアカウントを一覧にする
async function showAccounts() {
  showMessage("探しています…")

  const result = await fetchAccounts(settings, url.hostname)
  if (!result.ok) {
    showMessage(result.message)
    return
  }
  if (result.accounts.length === 0) {
    showMessage("このサイトのアカウントは登録されていません。")
    return
  }

  accountsElement.replaceChildren(...result.accounts.map(accountRow))
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
    const result = await runInPage(tab, { action: "fill", loginId: account.login_id || "", password: account.password })
    showMessage(result.message)
    if (result.ok) setTimeout(() => window.close(), 1000)
  })

  row.append(info, button)
  return row
}

// 強いパスワードを作る
generateButton.addEventListener("click", () => {
  const numbers = new Uint32Array(PASSWORD_LENGTH)
  crypto.getRandomValues(numbers)
  passwordInput.value = Array.from(numbers, (n) => CHARACTERS[n % CHARACTERS.length]).join("")
})

// ページのフォームに入力されている、ログインIDとパスワードを読み取る
readPageButton.addEventListener("click", async () => {
  const result = await runInPage(tab, { action: "read" })
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
    const response = await callApi(settings, "/api/v1/accounts", {
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
