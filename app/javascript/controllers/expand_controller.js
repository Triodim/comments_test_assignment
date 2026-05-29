import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["children", "btn"]

  connect() {
    this._expand = () => this.expand()
    this._collapse = () => this.collapse()
    window.addEventListener('comments:expand-all', this._expand)
    window.addEventListener('comments:collapse-all', this._collapse)
  }

  disconnect() {
    window.removeEventListener('comments:expand-all', this._expand)
    window.removeEventListener('comments:collapse-all', this._collapse)
  }

  toggle() {
    this.childrenTarget.classList.contains('hidden') ? this.expand() : this.collapse()
  }

  expand() {
    this.childrenTarget.classList.remove('hidden')
    this.btnTarget.textContent = 'Collapse'
  }

  collapse() {
    this.childrenTarget.classList.add('hidden')
    this.btnTarget.textContent = 'Expand'
  }
}
