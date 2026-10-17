/* Avatar, on the authoring model in README.md: one custom element wrapping the markup
 * ui/avatar/avatar.odin already emits, hiding the fallback when the
 * image loads and hiding the image -- showing the fallback -- when it does not.
 * Both are rendered, always; which one survives is decided here.
 *
 * What changed from the document-delegating avatar.js is where the handlers
 * live, not what they do: load and error are listened for on `this` in the
 * capture phase instead of on `document`, and the sweep for images that
 * resolved before anyone was listening runs in connectedCallback over this
 * element's own images, instead of a document-wide querySelectorAll driven by
 * DOMContentLoaded and an "htmx:after:init" event no htmx version emits. An
 * element inserted by a swap settles its images when it connects, which is what
 * the two document-level hooks were reaching for.
 *
 * Capture, not bubbling: load and error do not bubble, so a listener on `this`
 * only sees them on the way down. That is the checklist's second exception, and
 * it is the same reason avatar.js passed `true` to its document listeners.
 *
 * Two of upstream's behaviours are kept as they are. A load after an error does
 * not un-hide the image -- only the fallback is touched on load -- so an <img>
 * whose src is repointed at something that works stays hidden; and an image with
 * no src at all is `complete` with naturalWidth 0, so the connect sweep reads it
 * as failed and shows the fallback, which is the outcome that markup wants
 * anyway.
 *
 * avatar.contract.json names everything this class reads from the markup;
 * avatar_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./avatar.contract.json"

const IMAGE = contract.selectors.image
const FALLBACK = contract.selectors.fallback

/* Upstream's two outcomes, unchanged, including where the fallback is looked
 * for: the image's own parent, which is the frame both of them sit in. */
const settle = (img: HTMLImageElement, loaded: boolean): void => {
  const fallback = img.parentElement?.querySelector<HTMLElement>(FALLBACK)
  if (loaded) {
    if (fallback) fallback.style.display = "none"
    return
  }

  img.style.display = "none"
  if (fallback) fallback.style.display = "flex"
}

class OhAvatar extends HTMLElement {
  /* Listeners on `this` cover descendants swapped in later and die with the
   * element, so there is nothing to tear down: no disconnectedCallback, per the
   * checklist. The fields hold the handlers rather than bound methods so the
   * references are stable -- connectedCallback runs again on every move, and
   * addEventListener de-duplicates by reference (and by capture flag). */
  #onLoad = (event: Event): void => {
    const img = event.target
    if (img instanceof HTMLImageElement && img.matches(IMAGE)) settle(img, true)
  }

  #onError = (event: Event): void => {
    const img = event.target
    if (img instanceof HTMLImageElement && img.matches(IMAGE)) settle(img, false)
  }

  connectedCallback(): void {
    this.addEventListener("load", this.#onLoad, true)
    this.addEventListener("error", this.#onError, true)

    /* checkImages, narrowed to this element: an image that finished before the
     * element upgraded fired its event at nobody, so the outcome is read off
     * `complete` and naturalWidth instead of waited for. */
    for (const img of this.querySelectorAll<HTMLImageElement>(IMAGE)) {
      if (img.complete) settle(img, img.naturalWidth > 0)
    }
  }
}

customElements.define(contract.element, OhAvatar)
