import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  async copy(event) {
    const button = event.currentTarget
    // 元の文字を覚えておく（すでに覚えていれば、そのまま使う）
    button.dataset.label ??= button.textContent

    try {
      await navigator.clipboard.writeText(this.textValue)
      button.textContent = "コピーしました"
    } catch {
      button.textContent = "コピーできませんでした"
    }

    setTimeout(() => { button.textContent = button.dataset.label }, 2000)
  }
}

