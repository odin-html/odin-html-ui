/* Progress, the first component on the authoring model in README.md: one custom
 * element wrapping the markup ui/progress/progress.odin already
 * emits, keeping the indicator's width in step with aria-valuenow/-valuemax
 * on the progressbar. aria-valuenow stays the single source of truth:
 * whatever writes it -- htmx, another script -- moves the bar.
 *
 * progress.contract.json names everything this class reads from the markup;
 * progress_test.odin renders the Odin side and asserts it is all there. Read
 * the names from the contract here, so the declaration and the code cannot
 * quietly diverge.
 */

import contract from "./progress.contract.json"

const [VALUENOW, VALUEMAX] = contract.observed

class OhProgress extends HTMLElement {
  /* Watches the subtree rather than the bar alone, so an htmx swap that
   * replaces the inner markup (childList) re-syncs just like an attribute
   * write does. Owned by the instance and observing `this`, it dies with the
   * element: no disconnectedCallback, per the checklist. */
  #observer = new MutationObserver(() => this.#update())

  connectedCallback(): void {
    this.#update()
    this.#observer.observe(this, {
      subtree: true,
      childList: true,
      attributes: true,
      attributeFilter: contract.observed,
    })
  }

  #update(): void {
    const bar = this.querySelector(contract.selectors.bar)
    const indicator = this.querySelector<HTMLElement>(
      contract.selectors.indicator,
    )
    if (!bar || !indicator) return

    const value = parseFloat(bar.getAttribute(VALUENOW) ?? "0")
    const max = parseFloat(bar.getAttribute(VALUEMAX) ?? "100") || 100
    const percentage = Math.max(0, Math.min(100, (value / max) * 100))

    indicator.style.width = `${percentage}%`
  }
}

customElements.define(contract.element, OhProgress)
