import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["input", "clear"]
  static values  = { url: String }

  connect() {
    this._debounceTimer = null
    this._activeRequest = null
  }

  disconnect() {
    clearTimeout(this._debounceTimer)
  }

  query() {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this.#fetch(), 300)
    this.clearTarget.classList.toggle("hidden", this.inputTarget.value.trim() === "")
  }

  clear() {
    this.inputTarget.value = ""
    this.clearTarget.classList.add("hidden")
    this.inputTarget.focus()
    this.#fetch()
  }

  async #fetch() {
    const q = this.inputTarget.value.trim()
    const url = q ? `${this.urlValue}?q=${encodeURIComponent(q)}` : this.urlValue

    if (this._activeRequest) this._activeRequest.abort()
    const controller = new AbortController()
    this._activeRequest = controller

    try {
      const response = await fetch(url, {
        headers: { Accept: "text/vnd.turbo-stream.html" },
        signal:  controller.signal,
      })
      if (response.ok) Turbo.renderStreamMessage(await response.text())
    } catch (err) {
      if (err.name !== "AbortError") console.error("search error", err)
    } finally {
      if (this._activeRequest === controller) this._activeRequest = null
    }
  }
}
