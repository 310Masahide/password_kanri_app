const hostElement = document.getElementById("host")
const settingsLink = document.getElementById("open-settings")

// 今開いているタブのホスト名を表示する
const [tab] = await chrome.tabs.query({ active: true, currentWindow: true })
const url = new URL(tab.url)
hostElement.textContent = url.protocol.startsWith("http") ? url.hostname : "（このページでは使えません）"

settingsLink.addEventListener("click", (event) => {
  event.preventDefault()
  chrome.runtime.openOptionsPage()
})
