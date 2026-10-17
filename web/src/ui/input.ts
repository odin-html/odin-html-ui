/* Input, on the authoring model in README.md: one custom element wrapping the markup
 * ui/input/input.odin already emits, flipping a password field
 * between password and text when its eye button is clicked, and swapping the
 * two icons inside that button to match.
 *
 * What changed from the document-delegating input.js is where the handler
 * lives, not what it does: one click listener on `this` instead of one on
 * `document`, and the field is looked up inside the element rather than with
 * document.getElementById. The button still carries its target's id -- the
 * toggle is written only for a field that has one, which is the port's
 * deviation from upstream recorded in input.odin -- so which input flips is
 * decided by exactly the same attribute value as before.
 *
 * input.contract.json names everything this class reads from the markup;
 * input_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./input.contract.json"

const TOGGLE = contract.attributes.toggle
const TOGGLE_SELECTOR = `[${TOGGLE}]`

class OhInput extends HTMLElement {
  /* A listener on `this` covers descendants swapped in later and dies with the
   * element, so there is nothing to tear down: no disconnectedCallback, per
   * the checklist. The field holds the handler rather than a bound method so
   * the reference is stable -- connectedCallback runs again on every move, and
   * addEventListener de-duplicates by reference. */
  #onClick = (event: Event): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    const button = target.closest(TOGGLE_SELECTOR)
    if (!button || !this.contains(button)) return

    const id = button.getAttribute(TOGGLE)
    if (!id) return

    const field = this.querySelector<HTMLInputElement>(`#${CSS.escape(id)}`)
    if (!field) return

    const iconOpen = button.querySelector(contract.selectors.iconOpen)
    const iconClosed = button.querySelector(contract.selectors.iconClosed)

    const reveal = field.type === "password"
    field.type = reveal ? "text" : "password"
    iconOpen?.classList.toggle(contract.hidden, reveal)
    iconClosed?.classList.toggle(contract.hidden, !reveal)
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)
  }
}

customElements.define(contract.element, OhInput)
