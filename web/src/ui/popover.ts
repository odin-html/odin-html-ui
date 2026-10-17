/* Popover, on the authoring model in README.md -- and mostly on the platform. The old
 * popover.js was 557 lines because popover="manual" made the script own
 * dismissal, positioning and animation; here the content is
 * popover="auto" (light dismiss, Escape, stacking: native), positioned by CSS
 * anchor positioning (no script), and animated by @starting-style (no
 * script). What is left is the one thing with no declarative form here: a
 * click on the trigger toggles the content, because the trigger wraps the
 * caller's button and popovertarget cannot be written onto an element the
 * component does not render.
 *
 * The one subtlety is that native light dismiss races that click: an open
 * auto popover closes on the *pointerdown* of the very click that would
 * toggle it, so by the time the click handler runs the content reads closed
 * and a naive toggle would reopen it. The pointerdown listener records what
 * was true at press time; a click whose press saw the popover open is the
 * dismissal itself and must not reopen.
 *
 * Nothing outlives the node: two listeners on `this`, no fields but the
 * press-time flag (view state), no observers, no timers. There is no
 * disconnectedCallback and, for the first time for this component, no
 * teardown question at all -- the detach-observer an earlier version needed to
 * stop the floating-ui rAF loop is gone with the loop it watched.
 *
 * Cross-component control is not a method surface: anything that owns a
 * popover's content calls showPopover()/hidePopover() on the content element
 * itself, which is the platform's own API. window.tui.popover is gone with
 * nothing to replace it.
 *
 * popover.contract.json names everything this class reads from the markup;
 * popover_test.odin renders the Odin side and asserts it is all there. Read
 * the names from the contract here, so the declaration and the code cannot
 * quietly diverge. */

import contract from "./popover.contract.json"

const TRIGGER = contract.selectors.trigger
const CONTENT = contract.selectors.content
const TYPE = contract.attributes.type
const CLICK = contract.values.typeClick

class OhPopover extends HTMLElement {
  // What the press saw, before native light dismiss acted on it. Reset on
  // every click so a press that never became a click cannot go stale.
  #openAtPress = false

  #onPointerdown = (event: Event): void => {
    const trigger = this.#triggerFrom(event.target)
    this.#openAtPress =
      trigger !== null && (this.#content()?.matches(":popover-open") ?? false)
  }

  #onClick = (event: MouseEvent): void => {
    const trigger = this.#triggerFrom(event.target)
    if (!trigger || trigger.getAttribute(TYPE) !== CLICK) return

    // A disabled control inside the trigger disables the trigger.
    if (trigger.querySelector(':disabled, [disabled], [aria-disabled="true"]')) return

    event.preventDefault()

    const openAtPress = this.#openAtPress
    this.#openAtPress = false
    if (openAtPress) return // light dismiss already closed it

    this.#content()?.togglePopover()
  }

  connectedCallback(): void {
    this.addEventListener("pointerdown", this.#onPointerdown)
    this.addEventListener("click", this.#onClick)
  }

  /* The trigger an event came from -- and it must be *this* popover's:
   * nested popovers bubble their clicks through the outer element too. */
  #triggerFrom(target: EventTarget | null): Element | null {
    if (!(target instanceof Element)) return null

    const trigger = target.closest(TRIGGER)
    return trigger && trigger.closest(contract.element) === this ? trigger : null
  }

  #content(): HTMLElement | null {
    for (const el of this.querySelectorAll<HTMLElement>(CONTENT)) {
      if (el.closest(contract.element) === this) return el
    }
    return null
  }
}

customElements.define(contract.element, OhPopover)
