import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "button"]
  static values = { secret: String }

  connect() {
    this.hidden = true
  }

  toggle() {
    this.hidden = !this.hidden

    if (this.fieldTarget.tagName === "INPUT") {
      // 入力欄（新規登録・編集画面）のときは、種類を切り替える
      this.fieldTarget.type = this.hidden ? "password" : "text"
    } else {
      // ただの文字（詳細画面）のときは、表示する文字を入れ替える
      this.fieldTarget.textContent = this.hidden ? "••••••••" : this.secretValue
    }

    this.buttonTarget.textContent = this.hidden ? "表示" : "隠す"
  }
}
