/* Toast, on the authoring model in README.md: one custom element wrapping the markup
 * ui/toast/toast.odin already emits, counting a notification down --
 * animating the indicator bar while it goes, pausing both while the pointer is
 * over it -- and fading it out and removing it when the countdown ends or the
 * close button is pressed.
 *
 * What changed from the document-delegating toast.js is where the state lives
 * and where the handlers are, not what a toast does. toast.js kept a
 * module-level `Map` from toast element to its timer state, scanned the
 * document for [data-tui-toast] at DOMContentLoaded and again on an
 * "htmx:after:init" event no htmx version emits, and listened for dismiss
 * clicks on `document`. Here the countdown is five fields on the instance, the
 * scan is gone (an element sets its own countdown going when it connects,
 * which is what the sweep was reaching for), and the click listener is on
 * `this`.
 *
 * ## The module Map, and why nothing replaces it
 *
 * The Map did two jobs and neither is coordination: it was where a plain
 * function put per-node state (there being nowhere else), and its `has` check
 * was the "already initialised" guard that let the same document sweep run
 * repeatedly. Both are what an element gets for free -- fields, and one upgrade
 * per node -- so this is a registry that *should* disappear rather than move,
 * and it takes a real defect with it: toast.js deleted the entry only on
 * dismissal, so any toast removed another way (an htmx swap over the region it
 * sat in) stayed in the Map, and the detached element with it, for the life of
 * the page.
 *
 * Which leaves the question a notification component raises -- a toast is meant
 * to outlive whatever spawned it -- and the answer is that nothing here needs
 * to. There is no queue, no stack manager and no container: toast.odin renders
 * a self-positioning `fixed` box, so a toast's continuity is its own node's,
 * and a toast that must survive a swap is one the server rendered *outside* the
 * swap target. That is a page-level decision (the checklist's cross-swap state
 * rule: a wrapping element outside the swap target), not something this
 * element can hold on anyone's behalf. So the fields below are view state, they
 * die with the element, and there is no module state at all.
 *
 * ## What outlives the node, and why there is no disconnectedCallback
 *
 * The inventory: no observers, no rAF, no intervals, no document or window
 * listeners (the one there was is now on `this`), no module registry -- and two
 * timers, reasoned individually per the checklist.
 *
 * The auto-dismiss timeout touches this element's own subtree and then removes
 * the element: on a detached node the style writes are inert and `remove()` is
 * a no-op, so it dies harmlessly, and cancelling it would be the copybutton
 * mistake in a louder form -- a toast detached and re-attached (a move) with
 * its countdown cancelled would sit on the page forever. The same is true of
 * the 300ms timeout that removes the element after the fade. Neither is torn
 * down, and neither is redundantly re-armed: connectedCallback starts the
 * countdown once (#started), so a move keeps the countdown it already had
 * rather than restarting it.
 *
 * Two of upstream's behaviours are kept as they stand, both visible in the
 * removal check. Dismissing does not cancel the auto-dismiss timer -- toast.js
 * only dropped the Map entry -- so a toast closed early still has a timeout
 * pending, which later fades and removes a node that has already gone. And a
 * pause with no resume ends the countdown for good: mouseleave returns early
 * when the remaining time is not positive, so a toast hovered past its own
 * duration stays until it is dismissed by hand.
 *
 * The other oddities are upstream's too. The bar is animated by `width`, over a
 * class list that says `transition-transform` -- the inline transition wins, so
 * the utility is inert. `parseInt` of a duration that is not a number yields
 * NaN, which is not > 0, so the toast simply never leaves (as a negative
 * duration does, which is toast.odin's documented way of asking for one that
 * stays). And nothing arranges two toasts at the same corner: they overlap,
 * because upstream's do.
 *
 * The one deviation the wrapper forces: toast.js removed the node it was given,
 * which is now the element's child. Removing that alone would leave an empty
 * <oh-toast> behind on every notification, so the element removes *itself* --
 * the whole component leaves, which is what the call meant.
 *
 * toast.contract.json names everything this class reads from the markup;
 * toast_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./toast.contract.json"

const ROOT = contract.selectors.root
const INDICATOR = contract.selectors.indicator
const DISMISS = contract.selectors.dismiss
const DURATION = contract.attributes.duration
const DEFAULT_DURATION = contract.defaultDuration

// Upstream's 300, named: the fade, and the delay before the node goes.
const FADE_MS = 300
const FADE_TRANSITION = "opacity 300ms, transform 300ms"
const FADE_TRANSFORM = "translateY(1rem)"

class OhToast extends HTMLElement {
  /* The countdown, which is what the module Map held per toast. View state: it
   * dies with the element, and a countdown cannot outlive the node it is
   * counting down. */
  #timer: ReturnType<typeof setTimeout> | null = null
  #startTime = 0
  #remaining = 0
  #paused = false
  #progressWidth: string | null = null

  /* The Map's two other uses: `has` as the "already set up" guard, and the
   * delete-on-dismiss that made the hover handlers ignore a toast on its way
   * out. */
  #started = false
  #dismissing = false

  /* Listeners on `this` cover descendants swapped in later and die with the
   * element. The fields hold the handlers rather than bound methods so the
   * references are stable -- connectedCallback runs again on every move, and
   * addEventListener de-duplicates by reference. */
  #onClick = (event: Event): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    /* Upstream's e.target.closest("[data-tui-toast-dismiss]") followed by a
     * climb to the enclosing toast, narrowed to this element: the button is
     * inside one toast, and that toast is this one. */
    const button = target.closest(DISMISS)
    if (!button || !this.contains(button)) return

    this.#dismiss()
  }

  /* mouseenter and mouseleave do not bubble, but they are fired at every
   * element being entered or left, this one included -- so a listener on `this`
   * sees the pointer arriving over any descendant, which is what upstream's
   * listener on the toast root saw. */
  #onMouseenter = (): void => {
    if (this.#dismissing || this.#paused) return

    if (this.#timer !== null) clearTimeout(this.#timer)
    this.#timer = null

    this.#remaining = this.#remaining - (Date.now() - this.#startTime)
    this.#paused = true

    // Freeze the bar where it is: the computed width becomes the inline one,
    // with the transition off so it does not slide there.
    const indicator = this.#indicator()
    if (indicator) {
      this.#progressWidth = getComputedStyle(indicator).width
      indicator.style.transition = "none"
      indicator.style.width = this.#progressWidth
    }
  }

  #onMouseleave = (): void => {
    if (this.#dismissing || !this.#paused || this.#remaining <= 0) return

    this.#startTime = Date.now()
    this.#paused = false
    this.#timer = setTimeout(() => this.#dismiss(), this.#remaining)

    this.#animate(this.#remaining, this.#progressWidth ?? "")
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)
    this.addEventListener("mouseenter", this.#onMouseenter)
    this.addEventListener("mouseleave", this.#onMouseleave)

    // setupToast's early return, on the instance instead of a Map lookup: a
    // toast moved in the DOM keeps the countdown it is already running.
    if (this.#started) return

    const root = this.#root()
    if (!root) return

    this.#started = true

    // Upstream's read, default and all -- an absent or unparsable duration is
    // 3000 or NaN respectively, and only a positive one starts anything.
    const duration = parseInt(root.getAttribute(DURATION) || DEFAULT_DURATION)
    this.#remaining = duration
    this.#startTime = Date.now()

    if (duration > 0) {
      this.#animate(duration, "100%")
      this.#timer = setTimeout(() => this.#dismiss(), duration)
    }
  }

  /* The bar's run to empty, which is both the initial animation and the one
   * resumed after a hover: park it at a width, force the reflow that makes that
   * width the transition's start, then transition to nothing over what is left
   * of the countdown. */
  #animate(ms: number, from: string): void {
    const indicator = this.#indicator()
    if (!indicator) return

    indicator.style.width = from
    void indicator.offsetWidth
    indicator.style.transition = `width ${ms}ms linear`
    indicator.style.width = "0px"
  }

  /* dismissToast, unchanged but for what is removed: the fade is written on the
   * root box (the element itself is display:contents and paints nothing), and
   * what leaves after it is this element rather than that box -- see the file
   * comment. The pending auto-dismiss timer is deliberately not cancelled,
   * because upstream did not cancel it either. */
  #dismiss(): void {
    this.#dismissing = true

    const root = this.#root()
    if (root instanceof HTMLElement) {
      root.style.transition = FADE_TRANSITION
      root.style.opacity = "0"
      root.style.transform = FADE_TRANSFORM
    }

    setTimeout(() => this.remove(), FADE_MS)
  }

  /* What setupToast read once and closed over. Read per use instead, so markup
   * swapped in under the element is picked up -- the listeners are on `this`
   * and outlive any particular box or bar. */
  #root(): Element | null {
    return this.querySelector(ROOT)
  }

  #indicator(): HTMLElement | null {
    return this.querySelector<HTMLElement>(INDICATOR)
  }
}

customElements.define(contract.element, OhToast)
