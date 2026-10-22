import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  async copy(event) {
    const button = event.currentTarget

    try {
      await navigator.clipboard.writeText(this.textValue)
      button.textContent = "コピーしました"
    } catch {
      button.textContent = "コピーできませんでした"
    }

    setTimeout(() => { button.textContent = "コピー" }, 2000)
  }
}
