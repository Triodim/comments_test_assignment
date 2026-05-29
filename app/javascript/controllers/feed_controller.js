import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  expandAll() {
    window.dispatchEvent(new CustomEvent('comments:expand-all'))
  }

  collapseAll() {
    window.dispatchEvent(new CustomEvent('comments:collapse-all'))
  }
}
