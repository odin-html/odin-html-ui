/* Carousel, on the authoring model in README.md: one custom element wrapping the markup
 * ui/carousel/carousel.odin already emits -- a clipped frame over a
 * flex track of full-width slides -- and moving that track: by the two arrows,
 * by a dot, by dragging or swiping it, and by a clock when the caller asked for
 * autoplay.
 *
 * Everything the element does is one transform on the track plus the bookkeeping
 * around it, because the frame is `overflow-hidden` and each slide is exactly
 * its width: slide n is shown by translating the track -n * 100%. Nothing in the
 * markup does that, so an unscripted page shows the first slide and the arrows
 * and dots are inert -- carousel.odin says so, and this class is what makes them
 * mean anything.
 *
 * ## What changed from the document-delegating carousel.js
 *
 * Where the state and the listeners are, not what a carousel does. carousel.js
 * kept a module-level `Map` from carousel to its autoplay interval id and a
 * module-level `dragState` (one drag at a time, page-wide), listened for click,
 * mousedown/mousemove/mouseup/mouseleave and touchstart/touchmove/touchend on
 * `document`, and swept the document for [data-tui-carousel] at DOMContentLoaded
 * and again on an "htmx:after:init" event no htmx version emits, adding each one
 * to a shared IntersectionObserver behind a WeakSet guard.
 *
 * Here the interval id and the drag are two fields, the sweep and its WeakSet
 * are gone (an element observes itself when it connects, which is what the sweep
 * was reaching for), the click and touch listeners are on `this`, and the
 * observer is one per element watching this carousel's own root. The
 * "already initialised" marker carousel.js wrote into the DOM
 * (data-tui-carousel-initialized) is a field too, so it no longer appears in the
 * markup -- and, being a field, it is not in the manifest either.
 *
 * The Map's `has` check and the WeakSet were both the same guard -- "have I set
 * this one up?" -- which is what one upgrade per node gives for free.
 *
 * ## What outlives the node
 *
 * The inventory, per the checklist, and this is the richest one in the kit:
 *
 * - **The autoplay `setInterval`. It outlives the node and is cleared in
 *   disconnectedCallback.** A timer is not attached to anything: a carousel
 *   removed by an htmx swap would keep ticking for the life of the page, keep
 *   navigating a detached track, and keep its whole subtree alive through the
 *   closure. carousel.js half-knew this -- its callback opened with
 *   `if (!document.contains(carousel)) stopAutoplay()`, which stops it up to a
 *   whole interval late and only if it fires at all. That guard is gone: the
 *   lifecycle callback is what it was approximating, and it is exact. This is
 *   the checklist's timer principle coming out the other way from copybutton's
 *   -- the callback does not restore state outside the element, it *drives* the
 *   element, and a driver with nothing to drive must stop.
 * - **The `IntersectionObserver`. It is not torn down.** It is created by this
 *   instance and observes this element's own root div -- a node inside the
 *   element -- so the browser delivers nothing once that node leaves the
 *   document, and element, observer and target are one unreachable group when
 *   the subtree is dropped. That is the checklist's rule ("an observer owned by
 *   the instance and observing `this`"), read for a descendant rather than for
 *   `this` itself, and the removal check measures it rather than trusting it.
 *   It observes the root and not `this`, because `this` is display:contents and
 *   generates no box for an intersection to be computed against.
 * - **The drag's three document listeners. They are installed when a drag
 *   starts and removed when it ends**, which is the checklist's "install on
 *   open, not on connect" -- so the usual state of a page full of carousels is
 *   no document listeners at all, where carousel.js had six for the life of the
 *   page. disconnectedCallback removes them too, for the one case the drag's own
 *   end cannot cover: a carousel swapped out mid-drag. mousemove and mouseup
 *   have to be on the document, because a drag that leaves the frame -- which is
 *   most of them -- has nowhere else to be seen. touchmove and touchend do not:
 *   a touch sequence stays targeted at the node it started on, so those two
 *   bubble through `this` and live there with the click handler.
 * - No rAF, no module registry, and no listener on `this` that needs anything.
 *
 * ## Ported as it stands
 *
 * The oddities are upstream's, and each is visible in the browser check.
 *
 * **A dot ignores loop and bounds.** The arrows clamp (or wrap, with loop) and a
 * dot jumps straight to its index, so a dot beyond the last slide translates the
 * track into empty space. carousel.odin cannot count the slides -- they are the
 * caller's children -- so this is the caller's error to avoid, as documented
 * there.
 *
 * **Autoplay pauses on hover by skipping ticks, not by stopping.** The interval
 * keeps running and each tick returns early while the pointer is over the root
 * or a drag is live, so a carousel hovered for an hour advances on the first
 * tick after the pointer leaves rather than immediately.
 *
 * **Autoplay after a mouse drag usually does not come back.** endDrag restarts
 * it only when the pointer is *not* over the carousel, and after dragging the
 * frame it almost always is. Until the carousel leaves and re-enters the
 * viewport -- which is what actually restarts it, through the observer -- it
 * stays stopped. A swipe on a touchscreen leaves nothing hovering, so that one
 * does resume.
 *
 * **The stop is per-carousel and one-way at the edges.** Without loop the arrows
 * disable themselves at either end (and dim, `opacity-50`), while autoplay's own
 * `navigate(+1)` simply clamps and sits on the last slide forever.
 *
 * **A non-numeric interval is `setInterval(fn, NaN)`, which is
 * `setInterval(fn, 0)`** -- a carousel spinning as fast as the timer clamp
 * allows. carousel.odin always writes a number.
 *
 * **The document `mouseleave` listener is upstream's, dead as written.**
 * `mouseleave` does not bubble and it is fired at `documentElement`, so a
 * listener on `document` never sees the event its own target check is looking
 * for. It is ported unchanged rather than repaired or dropped: repairing it is a
 * behaviour change, and dropping it would hide that the pointer leaving the
 * window does not end a drag. A mouseup anywhere does, which is why it does not
 * matter much.
 *
 * The one deviation, and it is tabs' exactly: a carousel nested inside another
 * carousel's slide keeps its own parts. carousel.js reached its track, slides,
 * dots and arrows with `carousel.querySelectorAll(...)`, which descends into a
 * nested carousel and counts its slides as the outer one's, while the click it
 * delegated from `document` did *not* -- `closest()` gave the inner carousel the
 * click for free. #own below is the same guard applied to both halves: a part
 * belongs to the nearest <oh-carousel> above it.
 *
 * carousel.contract.json names everything this class reads from the markup;
 * carousel_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./carousel.contract.json"

const ELEMENT = contract.element
const ROOT = contract.selectors.root
const TRACK = contract.selectors.track
const ITEM = contract.selectors.item
const PREVIOUS = contract.selectors.previous
const NEXT = contract.selectors.next
const INDICATOR = contract.selectors.indicator
const CURRENT = contract.attributes.current
const AUTOPLAY = contract.attributes.autoplay
const INTERVAL = contract.attributes.interval
const LOOP = contract.attributes.loop
const INDICATOR_INDEX = contract.attributes.indicatorIndex
const INDICATOR_ACTIVE = contract.attributes.indicatorActive
const ON = contract.flags.on
const OFF = contract.flags.off
const ACTIVE_DOT = contract.classes.indicatorActive
const INACTIVE_DOT = contract.classes.indicatorInactive
const INITIAL_INDEX = contract.initialIndex
const DEFAULT_INTERVAL = contract.defaultInterval

/* Upstream's two thresholds for "that was a swipe, not a wobble": 50 pixels, or
 * half a pixel per millisecond however short the gesture was. */
const SWIPE_DISTANCE = 50
const SWIPE_VELOCITY = 0.5

/* Written by this class and rendered by nobody: the dimming of an arrow with
 * nowhere to go. Tailwind reads this file, so the utility is generated -- but
 * carousel.odin never writes it, so there is nothing on the Odin side to agree
 * with and it stays out of the manifest (the checklist's aria-expanded case). */
const DISABLED_ARROW = "opacity-50"

/* Where the pointer is, for the two event families upstream handled with one
 * pair of functions. A touchend carries no `touches`, which is why its handler
 * reads `changedTouches` instead -- see #onDragEnd. */
const pointerX = (event: MouseEvent | TouchEvent): number =>
  "touches" in event ? event.touches[0].clientX : event.clientX

/* dragState, per element rather than per page. View state: it dies with the
 * element, and a drag cannot outlive the node it started on. */
type Drag = {
  track: HTMLElement
  startX: number
  currentX: number
  startTime: number
}

class OhCarousel extends HTMLElement {
  #drag: Drag | null = null

  /* THE thing that outlives the node -- see the file comment. Cleared in
   * disconnectedCallback. */
  #autoplay: ReturnType<typeof setInterval> | null = null

  // The Map's `has` and the WeakSet, which were both this question.
  #initialised = false

  /* Upstream's shared observer, one per element and watching this carousel's
   * root: it initialises the display on first observation and runs autoplay only
   * while the carousel is on screen. Owned by the instance and observing a node
   * inside the element, so it needs no teardown. */
  #onIntersect = (entries: IntersectionObserverEntry[]): void => {
    const root = this.#root()
    if (!root) return

    for (const entry of entries) {
      if (!this.#initialised) {
        this.#initialised = true
        this.#update(parseInt(root.getAttribute(CURRENT) || INITIAL_INDEX))
      }

      if (root.getAttribute(AUTOPLAY) !== ON) continue

      if (entry.isIntersecting) this.#startAutoplay()
      else this.#stopAutoplay()
    }
  }

  #observer = new IntersectionObserver(this.#onIntersect)

  /* The click, the drag's start, and the touch half of the drag are on `this`:
   * they cover descendants swapped in later and die with the element. The fields
   * hold the handlers rather than bound methods so the references are stable --
   * connectedCallback runs again on every move, addEventListener de-duplicates
   * by reference, and removeEventListener needs the same function object. */
  #onClick = (event: Event): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    // Upstream's three closest() tests in order, each returning rather than
    // falling through to the next.
    if (this.#nearest(target, PREVIOUS)) {
      this.#navigate(-1)
      return
    }

    if (this.#nearest(target, NEXT)) {
      this.#navigate(1)
      return
    }

    const dot = this.#nearest(target, INDICATOR)
    if (dot) {
      // Straight to the index, loop and bounds ignored -- see the file comment.
      const index = parseInt(dot.getAttribute(INDICATOR_INDEX) ?? "")
      if (!isNaN(index)) this.#update(index)
    }
  }

  /* startDrag. The document's mousemove and mouseup are installed here rather
   * than on connect, so a page of carousels sitting still has none of them. */
  #onDragStart = (event: MouseEvent | TouchEvent): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    const track = this.#nearest(target, TRACK)
    if (!(track instanceof HTMLElement)) return

    // Upstream preventDefaults a drag on the track: on mousedown that is what
    // stops the frame's images being dragged off or its text selected.
    event.preventDefault()

    const x = pointerX(event)
    this.#drag = { track, startX: x, currentX: x, startTime: Date.now() }

    track.style.cursor = "grabbing"
    track.style.transition = "none"
    this.#stopAutoplay()

    const doc = this.ownerDocument
    doc.addEventListener("mousemove", this.#onDragMove)
    doc.addEventListener("mouseup", this.#onDragEnd)
    doc.addEventListener("mouseleave", this.#onDocumentMouseleave)
  }

  /* doDrag: the track follows the finger, offset from wherever the current
   * slide has it, in per-cent of the track's own width. */
  #onDragMove = (event: MouseEvent | TouchEvent): void => {
    const drag = this.#drag
    if (!drag) return

    const x = pointerX(event)
    drag.currentX = x

    const diff = x - drag.startX
    const offset = -this.#current() * 100 + (diff / drag.track.offsetWidth) * 100
    drag.track.style.transform = `translateX(${offset}%)`
  }

  /* endDrag: far enough or fast enough is a slide, anything less snaps back.
   * `event.clientX || drag.currentX` is upstream's, and it treats a mouseup at
   * x=0 as "no coordinate" -- kept, since a drag ending at the screen's left
   * edge snapping back is what upstream does. */
  #onDragEnd = (event: MouseEvent | TouchEvent): void => {
    const drag = this.#drag
    if (!drag) return

    this.#removeDocumentDragListeners()

    const x =
      "changedTouches" in event
        ? event.changedTouches[0].clientX
        : event.clientX || drag.currentX

    drag.track.style.cursor = ""
    drag.track.style.transition = ""

    const diff = drag.startX - x
    const velocity = Math.abs(diff) / (Date.now() - drag.startTime)

    if (Math.abs(diff) > SWIPE_DISTANCE || velocity > SWIPE_VELOCITY) {
      this.#navigate(diff > 0 ? 1 : -1)
    } else {
      this.#update(this.#current())
    }

    // Cleared before the restart, as upstream cleared it: the tick's own
    // "a drag is live" test must not see the drag that has just ended.
    this.#drag = null

    const root = this.#root()
    if (root?.getAttribute(AUTOPLAY) === ON && !root.matches(":hover")) {
      this.#startAutoplay()
    }
  }

  /* Upstream's guard against a drag lost off the top of the window. Ported as it
   * stands and dead as written -- mouseleave does not bubble, so this listener
   * on the document never runs. See the file comment. */
  #onDocumentMouseleave = (event: MouseEvent): void => {
    if (event.target === this.ownerDocument.documentElement) this.#onDragEnd(event)
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)
    this.addEventListener("mousedown", this.#onDragStart)
    this.addEventListener("touchstart", this.#onDragStart, { passive: false })
    this.addEventListener("touchmove", this.#onDragMove, { passive: false })
    this.addEventListener("touchend", this.#onDragEnd, { passive: false })

    /* observeCarousels, narrowed to this element. Re-observing is what makes a
     * re-connect deliver an initial entry again -- observe() on a target already
     * being watched delivers nothing -- so a carousel moved back into the page
     * picks its autoplay up from the observer, exactly as it did the first
     * time. */
    const root = this.#root()
    if (!root) return

    this.#observer.disconnect()
    this.#observer.observe(root)
  }

  /* Required, and for exactly two things: the interval, which is not attached to
   * anything and would otherwise drive a carousel that has left the page, and
   * the drag's document listeners in the case the drag's own end cannot reach --
   * a carousel swapped out with the button still down. The observer is not
   * disconnected and the listeners on `this` are not removed: both die with the
   * node, per the checklist. */
  disconnectedCallback(): void {
    this.#stopAutoplay()
    this.#removeDocumentDragListeners()
  }

  /* navigate: one step either way from the attribute, wrapping when the caller
   * asked to loop and clamping when it did not. */
  #navigate(direction: number): void {
    const count = this.#own(ITEM).length
    if (count === 0) return

    const next = this.#current() + direction
    const loop = this.#root()?.getAttribute(LOOP) === ON

    this.#update(
      loop ? ((next % count) + count) % count : Math.max(0, Math.min(next, count - 1)),
    )
  }

  /* updateCarousel: the index is the state, written back to the root, and
   * everything else is drawn from it -- the track's transform, each dot, and
   * whether an arrow has anywhere to go. */
  #update(index: number): void {
    const root = this.#root()
    if (!root) return

    const count = this.#own(ITEM).length
    root.setAttribute(CURRENT, String(index))

    const track = this.#own(TRACK)[0]
    if (track instanceof HTMLElement) {
      track.style.transform = `translateX(-${index * 100}%)`
    }

    /* A dot's position in the row decides which slide it is drawn active for,
     * not the index it declares -- upstream indexed the NodeList, and so does
     * this. The two agree in anything carousel.odin renders. */
    this.#own(INDICATOR).forEach((dot, i) => {
      dot.setAttribute(INDICATOR_ACTIVE, i === index ? ON : OFF)
      dot.classList.toggle(ACTIVE_DOT, i === index)
      dot.classList.toggle(INACTIVE_DOT, i !== index)
    })

    const loop = root.getAttribute(LOOP) === ON
    this.#disable(PREVIOUS, !loop && index === 0)
    this.#disable(NEXT, !loop && index === count - 1)
  }

  #disable(selector: string, disabled: boolean): void {
    const button = this.#own(selector)[0]
    if (!(button instanceof HTMLButtonElement)) return

    button.disabled = disabled
    button.classList.toggle(DISABLED_ARROW, disabled)
  }

  /* startAutoplay: the interval id is the field the module Map held, and
   * stopping first is upstream's way of never running two. */
  #startAutoplay(): void {
    const root = this.#root()
    if (root?.getAttribute(AUTOPLAY) !== ON) return

    this.#stopAutoplay()

    const ms = parseInt(root.getAttribute(INTERVAL) || DEFAULT_INTERVAL)
    this.#autoplay = setInterval(() => this.#tick(), ms)
  }

  #stopAutoplay(): void {
    if (this.#autoplay !== null) clearInterval(this.#autoplay)
    this.#autoplay = null
  }

  /* The tick. Upstream's `!document.contains(carousel)` guard is gone:
   * disconnectedCallback is what it was approximating, and it is exact. The
   * pause conditions are its other two, unchanged -- the pointer over the
   * carousel, or a drag in progress, skips a tick rather than stopping the
   * clock. */
  #tick(): void {
    const root = this.#root()
    if (!root) return
    if (root.matches(":hover") || this.#drag) return

    this.#navigate(1)
  }

  #removeDocumentDragListeners(): void {
    const doc = this.ownerDocument
    doc.removeEventListener("mousemove", this.#onDragMove)
    doc.removeEventListener("mouseup", this.#onDragEnd)
    doc.removeEventListener("mouseleave", this.#onDocumentMouseleave)
  }

  /* What the module functions took as an argument, resolved per use instead, so
   * markup swapped in under the element is picked up -- the listeners are on
   * `this` and outlive any particular frame, track or row of dots. */
  #root(): Element | null {
    return this.querySelector(ROOT)
  }

  #current(): number {
    return parseInt(this.#root()?.getAttribute(CURRENT) || INITIAL_INDEX)
  }

  /* The parts of this carousel: descendants matching the role whose nearest
   * <oh-carousel> is this one, so a carousel nested in a slide keeps its own --
   * tabs' guard, and what upstream's delegated clicks got for free from
   * closest() while its querySelectorAll calls did not. */
  #own(selector: string): Element[] {
    return [...this.querySelectorAll(selector)].filter(
      (part) => part.closest(ELEMENT) === this,
    )
  }

  /* Upstream's e.target.closest(role), with the same guard: the part an event
   * came from belongs to the nearest carousel above it, and only that one acts
   * on it. */
  #nearest(target: Element, selector: string): Element | null {
    const part = target.closest(selector)
    return part && part.closest(ELEMENT) === this ? part : null
  }
}

customElements.define(contract.element, OhCarousel)
