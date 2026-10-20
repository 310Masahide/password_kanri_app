import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "button"]

  toggle() {
    const hidden = this.fieldTarget.type === "password"
    this.fieldTarget.type = hidden ? "text" : "password"
    this.buttonTarget.textContent = hidden ? "隠す" : "表示"
  }
}
