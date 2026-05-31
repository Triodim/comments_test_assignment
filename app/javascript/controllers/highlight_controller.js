import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const scrollToId = document.body.dataset.scrollTo
    if (scrollToId && this.element.id === `comment-${scrollToId}`) {
      // Small delay lets the flex layout fully settle before we measure positions
      setTimeout(() => {
        this.#scrollIntoContainer()
        this.#flash()
      }, 50)
    }
  }

  #scrollIntoContainer() {
    const container = document.getElementById('comments-list')
    if (!container) return

    // Compute absolute offset of element within the scroll container
    const elementRect   = this.element.getBoundingClientRect()
    const containerRect = container.getBoundingClientRect()
    container.scrollTop += elementRect.top - containerRect.top
  }

  #flash() {
    this.element.classList.add('ring-2', 'ring-inset', 'ring-indigo-400', 'bg-indigo-50')
    setTimeout(() => {
      this.element.classList.remove('ring-2', 'ring-inset', 'ring-indigo-400', 'bg-indigo-50')
    }, 333)
  }
}
