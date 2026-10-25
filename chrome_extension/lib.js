// ポップアップとバックグラウンドの両方で使う処理

// 保存してある設定（アプリの URL とトークン）を読み込む
export function loadSettings() {
  return chrome.storage.local.get(["server", "token"])
}

// アプリの API を呼ぶ（トークンを付けて送る）
export function callApi({ server, token }, path, options = {}) {
  return fetch(`${server}${path}`, {
    ...options,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", ...options.headers }
  })
}

// このサイト（ホスト名）のアカウントを、アプリに問い合わせる
export async function fetchAccounts(settings, host) {
  try {
    const response = await callApi(settings, `/api/v1/accounts?host=${encodeURIComponent(host)}`)

    if (response.status === 401) {
      return { ok: false, message: "トークンが正しくありません。「設定」を確かめてください。" }
    }
    if (!response.ok) {
      return { ok: false, message: `エラーになりました（${response.status}）。` }
    }
    return { ok: true, accounts: await response.json() }
  } catch {
    return { ok: false, message: "アプリにつながりませんでした。" }
  }
}

// 開いているページの中で、ログインフォームを操作する
export async function runInPage(tab, request) {
  try {
    const [result] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: operateLoginForm,
      args: [{ ...request, expectedHost: new URL(tab.url).hostname }]
    })
    return result.result
  } catch {
    return { ok: false, message: "このページは操作できませんでした。" }
  }
}

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
