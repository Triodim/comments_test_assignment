import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    // Delay observation so the element settles into its final position after a
    // turbo_stream.replace — prevents the observer from firing immediately on
    // connect when the sentinel is still within the visible scroll area.
    this.connectTimeout = setTimeout(() => this.#setupObserver(), 200)
  }

  disconnect() {
    clearTimeout(this.connectTimeout)
    this.observer?.disconnect()
  }

  #setupObserver() {
    const scrollRoot = document.getElementById('comments-list')
    this.observer = new IntersectionObserver(
      entries => this.#onIntersect(entries),
      { root: scrollRoot, threshold: 0.1 },
    )
    this.observer.observe(this.element)
  }

  #onIntersect(entries) {
    if (!entries[0].isIntersecting) return
    this.observer.unobserve(this.element)
    this.#load()
  }

  async #load() {
    const response = await fetch(this.urlValue, {
      headers: { Accept: 'text/vnd.turbo-stream.html' },
    })
    const html = await response.text()
    Turbo.renderStreamMessage(html)
  }
}
