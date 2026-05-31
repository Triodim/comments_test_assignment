import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (window.location.hash === `#${this.element.id}`) {
      requestAnimationFrame(() => {
        this.element.scrollIntoView({ behavior: 'instant', block: 'start' })
        this.#flash()
      })
    }
  }

  #flash() {
    this.element.classList.add('ring-2', 'ring-inset', 'ring-indigo-400', 'bg-indigo-50')
    setTimeout(() => {
      this.element.classList.remove('ring-2', 'ring-inset', 'ring-indigo-400', 'bg-indigo-50')
    }, 333)
  }
}
