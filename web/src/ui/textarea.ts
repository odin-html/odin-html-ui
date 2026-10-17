/* Textarea, on the authoring model in README.md: one custom element wrapping the markup
 * ui/textarea/textarea.odin already emits, growing an auto-resizing
 * textarea to fit its content -- on every input event, and once when the
 * element connects.
 *
 * What changed from the document-delegating textarea.js is where the handlers
 * live, not what they do: one input listener on `this` instead of one on
 * `document`, and the initial sizing runs in connectedCallback for this
 * element's own field instead of a document-wide querySelectorAll driven by
 * DOMContentLoaded and an "htmx:after:init" event no htmx version emits. An
 * element inserted by a swap sizes itself when it connects, which is what the
 * two document-level hooks were reaching for.
 *
 * textarea.contract.json names everything this class reads from the markup;
 * textarea_test.odin renders the Odin side and asserts it is all there. Read
 * the names from the contract here, so the declaration and the code cannot
 * quietly diverge.
 */

import contract from "./textarea.contract.json"

const FIELD = contract.selectors.field
const AUTO_RESIZE = contract.attributes.autoResize
const ENABLED = contract.enabled

// The fields the initial sizing pass looks at: the role, plus the flag turned on.
const AUTO_FIELD = `${FIELD}[${AUTO_RESIZE}="${ENABLED}"]`

/* Upstream's two-step measurement, unchanged: drop the box to its minimum
 * height first so scrollHeight reports the content rather than the height the
 * box already has, then grow to that. An inline min-height wins over the
 * computed one, which is only how textarea.js wrote it -- the min-height this
 * component renders is a class, so the computed value is the one in play. */
const fit = (field: HTMLTextAreaElement): void => {
  const minHeight = field.style.minHeight || getComputedStyle(field).minHeight
  field.style.height = minHeight
  field.style.height = `${field.scrollHeight}px`
}

class OhTextarea extends HTMLElement {
  /* A listener on `this` covers descendants swapped in later and dies with the
   * element, so there is nothing to tear down: no disconnectedCallback, per
   * the checklist. The field holds the handler rather than a bound method so
   * the reference is stable -- connectedCallback runs again on every move, and
   * addEventListener de-duplicates by reference. */
  #onInput = (event: Event): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    const field = target.closest(FIELD)
    if (!(field instanceof HTMLTextAreaElement) || !this.contains(field)) return
    if (field.getAttribute(AUTO_RESIZE) !== ENABLED) return

    fit(field)
  }

  connectedCallback(): void {
    this.addEventListener("input", this.#onInput)

    /* resizeAll's guard, kept: a height already set by an earlier pass -- or by
     * anything else -- is left alone, and unlike the input path this one does
     * not shrink first, so the content is measured in the box the server gave
     * it. */
    for (const field of this.querySelectorAll<HTMLTextAreaElement>(AUTO_FIELD)) {
      if (!field.style.height || field.style.height === field.style.minHeight) {
        field.style.height = `${field.scrollHeight}px`
      }
    }
  }
}

customElements.define(contract.element, OhTextarea)
