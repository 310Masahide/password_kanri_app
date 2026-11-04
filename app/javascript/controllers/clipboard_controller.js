import { Controller } from "@hotwired/stimulus"

// コピーしたパスワードがクリップボードに残り続けないように、30秒たったら空にする
const CLEAR_AFTER_MS = 30000
// 画面を移動しても止まらないように、コントローラーの外で覚えておく
let clearTimer

export default class extends Controller {
  static values = { text: String }

  async copy(event) {
    const button = event.currentTarget
    // 元の文字を覚えておく（すでに覚えていれば、そのまま使う）
    button.dataset.label ??= button.textContent

    try {
      await navigator.clipboard.writeText(this.textValue)
      button.textContent = "コピーしました（30秒で消えます）"
      this.scheduleClear()
    } catch {
      button.textContent = "コピーできませんでした"
    }

    setTimeout(() => { button.textContent = button.dataset.label }, 2000)
  }

  // 前の予約を取り消してから、新しく予約する（続けてコピーしたときは、最後から30秒）
  scheduleClear() {
    clearTimeout(clearTimer)
    clearTimer = setTimeout(() => {
      // ブラウザは、このページが前に出ていないと書き込ませないので、失敗しても何もしない
      navigator.clipboard.writeText("").catch(() => {})
    }, CLEAR_AFTER_MS)
  }
}

