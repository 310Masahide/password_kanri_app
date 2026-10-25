const form = document.getElementById("settings")
const server = document.getElementById("server")
const token = document.getElementById("token")
const testButton = document.getElementById("test")
const message = document.getElementById("message")

// 保存してある設定を読み込む
chrome.storage.local.get(["server", "token"]).then((settings) => {
  if (settings.server) server.value = settings.server
  if (settings.token) token.value = settings.token
})

// 設定を保存する
form.addEventListener("submit", async (event) => {
  event.preventDefault()
  await chrome.storage.local.set({ server: server.value, token: token.value.trim() })
  message.textContent = "保存しました。"
})

// アプリにつながるか、トークンが正しいかを確かめる
testButton.addEventListener("click", async () => {
  message.textContent = "確認しています…"

  try {
    const response = await fetch(`${server.value}/api/v1/accounts?host=connection-test.invalid`, {
      headers: { Authorization: `Bearer ${token.value.trim()}` }
    })

    if (response.ok) {
      message.textContent = "つながりました。トークンも正しいです。"
    } else if (response.status === 401) {
      message.textContent = "つながりましたが、トークンが正しくありません。"
    } else {
      message.textContent = `つながりましたが、エラーになりました（${response.status}）。`
    }
  } catch {
    message.textContent = "アプリにつながりませんでした。URL と、アプリが起動しているかを確かめてください。"
  }
})
