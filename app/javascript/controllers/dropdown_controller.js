import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.closeHandler = this.close.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    document.addEventListener("click", this.closeHandler)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.closeHandler)
  }
}
