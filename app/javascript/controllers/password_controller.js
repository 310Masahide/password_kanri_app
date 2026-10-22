import { Controller } from "@hotwired/stimulus"

// まぎらわしい文字（0とO、1とlとI）は除いている
const CHARACTERS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*-_"
const LENGTH = 16

export default class extends Controller {
  static targets = ["field", "button"]
  static values = { secret: String }

  connect() {
    this.hidden = true
  }

  toggle() {
    this.hidden = !this.hidden
    this.render()
  }

  // ランダムなパスワードを作って、入力欄に入れる
  generate() {
    const numbers = new Uint32Array(LENGTH)
    crypto.getRandomValues(numbers)
    this.fieldTarget.value = Array.from(numbers, (n) => CHARACTERS[n % CHARACTERS.length]).join("")

    // 作ったパスワードを確認できるように、見える状態にする
    this.hidden = false
    this.render()
  }

  render() {
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
