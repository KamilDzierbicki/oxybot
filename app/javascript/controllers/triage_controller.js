import { Controller } from "@hotwired/stimulus"

// Keyboard triage for the insights list: j/k move between cards, l links the suggestion, d dismisses.
// When a card is removed by a Turbo Stream, focus moves to the next card instead of getting lost.
export default class extends Controller {
  static targets = ["card"]

  connect() {
    this.keydown = this.keydown.bind(this)
    this.beforeStreamRender = this.beforeStreamRender.bind(this)
    document.addEventListener("keydown", this.keydown)
    document.addEventListener("turbo:before-stream-render", this.beforeStreamRender)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydown)
    document.removeEventListener("turbo:before-stream-render", this.beforeStreamRender)
  }

  keydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey || this.typing(event.target)) return

    const actions = { j: () => this.move(1), k: () => this.move(-1), l: () => this.press("link"), d: () => this.press("dismiss") }
    const action = actions[event.key]
    if (!action) return

    event.preventDefault()
    action()
  }

  move(step) {
    const cards = this.cardTargets
    if (cards.length === 0) return

    const index = cards.indexOf(this.current)
    const next = cards[Math.min(Math.max(index + step, 0), cards.length - 1)] || cards[0]
    this.focus(next)
  }

  press(name) {
    const card = this.current || this.cardTargets[0]
    card?.querySelector(`[data-triage-action="${name}"]`)?.click()
  }

  beforeStreamRender(event) {
    const stream = event.target
    if (stream.getAttribute("action") !== "remove") return

    const card = this.cardTargets.find((element) => element.id === stream.getAttribute("target"))
    if (!card || !card.contains(document.activeElement)) return

    const next = this.cardTargets[this.cardTargets.indexOf(card) + 1] || this.cardTargets[this.cardTargets.indexOf(card) - 1]
    const render = event.detail.render
    event.detail.render = async (element) => {
      await render(element)
      if (next) this.focus(next)
    }
  }

  focus(card) {
    card.focus()
    const smooth = !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    card.scrollIntoView({ block: "nearest", behavior: smooth ? "smooth" : "auto" })
  }

  get current() {
    return this.cardTargets.find((card) => card.contains(document.activeElement))
  }

  typing(element) {
    return element.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(element.tagName)
  }
}
