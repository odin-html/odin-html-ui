/* Slider, on the authoring model in README.md: one custom element wrapping the markup
 * ui/slider/slider.odin already emits, moving the thumb and repainting
 * the filled part of the track as the value changes -- by drag, by track click,
 * or by arrow key -- and writing the number into whatever readouts name this
 * slider's id.
 *
 * Everything the element paints, the server already painted once: the fill's
 * inset and each thumb's `left` are inline styles computed in slider.odin, so a
 * slider looks right before this class runs. What it cannot render is the
 * readout, which slider.odin deliberately leaves empty (the number would
 * otherwise live in two places and disagree the moment the thumb moves), so the
 * connect-time pass below is what first fills it in.
 *
 * What changed from the document-delegating slider.js is where the listeners
 * live, not what they do. slider.js scanned the document for
 * [data-tui-slider]:not([data-tui-slider-init]) from an "htmx:after:init" event
 * no htmx version emits (and once at load), attached a pointerdown and a keydown
 * listener per thumb plus a pointerdown on the track, and marked the root
 * data-tui-slider-init so the next sweep skipped it. Here the four listeners are
 * on `this` and the marker is gone: an element upgrades itself when it connects,
 * which is what the sweep and the marker together were reaching for, and
 * addEventListener de-duplicates by reference, so a slider moved in the DOM
 * re-runs connectedCallback without stacking handlers.
 *
 * The drag is the one mechanism that moved rather than shrank. slider.js added a
 * pointermove listener to the thumb on pointerdown and removed it on pointerup;
 * both live on `this` here, gated by #dragging, because a listener on `this`
 * covers the thumb whether or not it was there when the element connected. The
 * pointer capture is kept as it was: the events retarget to the thumb, which is
 * inside this element, so they bubble here even when the cursor has left the
 * page's slider entirely. That is also the whole of the teardown analysis --
 * there is nothing outside this element to tear down, and no
 * disconnectedCallback, per the checklist.
 *
 * Two deltas, both stated rather than papered over. slider.js cleared its move
 * listener on pointerup alone; #dragging is cleared on pointercancel too, so a
 * pointer lost to the system (a touch turning into a scroll) ends the drag
 * instead of leaving the thumb following the next move over the element. And
 * `+root.dataset.min` was NaN when the attribute was missing, where
 * Number(getAttribute(...)) is 0 -- a hand-written slider with no min lays out
 * from zero rather than nowhere. slider.odin always renders all three.
 *
 * Upstream's oddities are kept. The readouts are matched on the slider's id,
 * with "-min"/"-max" appended for a range, which means a slider with no id
 * matches the readouts whose `for` is empty -- the ones slider.odin renders an
 * error span beside. The clamping is one-directional per thumb, exactly as
 * written: the low thumb is capped at the high value only for a range, and the
 * second thumb is floored at the first unconditionally. setVal dispatches a
 * bubbling `input` event from the hidden input after repainting, which nothing
 * here listens for -- and because nothing does, an external write to
 * input.value repaints nothing until the next drag or key press, as before.
 *
 * slider.contract.json names everything this class reads from the markup;
 * slider_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./slider.contract.json"

const ROOT = contract.selectors.root
const TRACK = contract.selectors.track
const FILL = contract.selectors.fill
const THUMB = contract.selectors.thumb
const INPUT = contract.selectors.input
const MIN = contract.attributes.min
const MAX = contract.attributes.max
const STEP = contract.attributes.step
const VALUE_NOW = contract.attributes.valueNow
const DISABLED = contract.attributes.disabled
const VALUE_FOR = contract.attributes.valueFor
const DISABLED_VALUE = contract.disabledValue

// Upstream's four helpers, unchanged.
const pct = (val: number, min: number, max: number): number =>
  ((val - min) / (max - min)) * 100

const clamp = (val: number, min: number, max: number): number =>
  Math.min(max, Math.max(min, val))

const snap = (val: number, step: number): number => Math.round(val / step) * step

const fromPointer = (
  clientX: number,
  track: Element,
  min: number,
  max: number,
  step: number,
): number => {
  const { left, width } = track.getBoundingClientRect()
  return clamp(snap(min + ((clientX - left) / width) * (max - min), step), min, max)
}

/* What initSlider read once and closed over. Read per use instead, so markup
 * swapped in under the element is picked up -- the listeners are on `this` and
 * outlive any particular track, fill or thumb. */
type Parts = {
  root: Element
  track: Element
  fill: HTMLElement
  thumbs: HTMLElement[]
  inputs: HTMLInputElement[]
  min: number
  max: number
  step: number
  isRange: boolean
}

const arrows: Record<string, number> = {
  ArrowRight: 1,
  ArrowUp: 1,
  ArrowLeft: -1,
  ArrowDown: -1,
}

class OhSlider extends HTMLElement {
  /* The thumb a drag is moving, or null. View state: it dies with the element,
   * and a drag cannot outlive the node it started on. */
  #dragging: number | null = null

  /* Listeners on `this` cover descendants swapped in later and die with the
   * element, so there is nothing to tear down: no disconnectedCallback, per the
   * checklist. The fields hold the handlers rather than bound methods so the
   * references are stable -- connectedCallback runs again on every move, and
   * addEventListener de-duplicates by reference. */
  #onPointerdown = (event: PointerEvent): void => {
    const parts = this.#parts()
    if (!parts) return

    const target = event.target
    if (!(target instanceof Element)) return

    const thumb = target.closest<HTMLElement>(THUMB)
    if (thumb && this.contains(thumb)) {
      // The guard slider.js got by never attaching to a disabled thumb.
      if (thumb.getAttribute(DISABLED) === DISABLED_VALUE) return

      const index = parts.thumbs.indexOf(thumb)
      if (index < 0) return

      event.preventDefault()
      thumb.setPointerCapture(event.pointerId)
      for (const other of parts.thumbs) other.style.zIndex = "0"
      thumb.style.zIndex = "1"
      this.#dragging = index
      return
    }

    // Click on the track to jump to the position: the nearest thumb takes the
    // value for a range, and a slider with a disabled thumb ignores the click.
    const track = target.closest(TRACK)
    if (!track || !this.contains(track)) return
    if (parts.root.querySelector(`${THUMB}[${DISABLED}="${DISABLED_VALUE}"]`)) return

    const val = fromPointer(event.clientX, parts.track, parts.min, parts.max, parts.step)
    const index = !parts.isRange
      ? 0
      : Math.abs(val - Number(parts.inputs[0].value)) <=
          Math.abs(val - Number(parts.inputs[1].value))
        ? 0
        : 1
    this.#setVal(parts, index, val)
  }

  /* The thumb holds the pointer capture, so a move anywhere on the screen
   * retargets to it and bubbles here -- which is why this listener can sit on
   * the element and still follow a cursor that has left it. */
  #onPointermove = (event: PointerEvent): void => {
    if (this.#dragging === null) return

    const parts = this.#parts()
    if (!parts) return

    this.#setVal(
      parts,
      this.#dragging,
      fromPointer(event.clientX, parts.track, parts.min, parts.max, parts.step),
    )
  }

  // Upstream's { once: true } removal of the move listener. pointercancel is
  // this port's addition -- see the file comment.
  #onPointerup = (): void => {
    this.#dragging = null
  }

  #onKeydown = (event: KeyboardEvent): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    const thumb = target.closest<HTMLElement>(THUMB)
    if (!thumb || !this.contains(thumb)) return
    if (thumb.getAttribute(DISABLED) === DISABLED_VALUE) return

    const direction = arrows[event.key]
    if (direction === undefined) return

    const parts = this.#parts()
    if (!parts) return

    const index = parts.thumbs.indexOf(thumb)
    if (index < 0) return

    event.preventDefault()
    const delta = direction * parts.step
    this.#setVal(
      parts,
      index,
      clamp(snap(Number(parts.inputs[index].value) + delta, parts.step), parts.min, parts.max),
    )
  }

  connectedCallback(): void {
    this.addEventListener("pointerdown", this.#onPointerdown)
    this.addEventListener("pointermove", this.#onPointermove)
    this.addEventListener("pointerup", this.#onPointerup)
    this.addEventListener("pointercancel", this.#onPointerup)
    this.addEventListener("keydown", this.#onKeydown)

    // initSlider's closing update(), narrowed to this element: the positions
    // are already rendered, so what this actually does is fill the readouts,
    // which the server leaves empty.
    const parts = this.#parts()
    if (parts) this.#update(parts)
  }

  /* update(), unchanged in what it writes: each thumb's `left` and
   * aria-valuenow from its own input, the readouts keyed by the slider's id,
   * and the fill inset from the right -- and from the left as well when there
   * are two thumbs. */
  #update(parts: Parts): void {
    const { root, fill, thumbs, inputs, min, max, isRange } = parts

    thumbs.forEach((thumb, i) => {
      const input = inputs[i]
      if (!input) return

      const val = Number(input.value)
      thumb.style.left = `${pct(val, min, max)}%`
      thumb.setAttribute(VALUE_NOW, String(val))

      /* The readout is somewhere else on the page by design -- that is what
       * `for` means -- so this is the one lookup an element boundary cannot
       * narrow, as in copybutton and label. */
      const key = isRange ? root.id + (i === 0 ? "-min" : "-max") : root.id
      for (const el of this.ownerDocument.querySelectorAll(`[${VALUE_FOR}="${key}"]`)) {
        el.textContent = String(val)
      }
    })

    if (isRange) {
      fill.style.left = `${pct(Number(inputs[0].value), min, max)}%`
      fill.style.right = `${100 - pct(Number(inputs[1].value), min, max)}%`
    } else {
      fill.style.right = `${100 - pct(Number(inputs[0].value), min, max)}%`
    }
  }

  /* setVal, unchanged: the two clamps as upstream wrote them, the hidden input
   * as the value's home, a repaint, and a bubbling `input` event so a form or a
   * caller's handler sees the change. */
  #setVal(parts: Parts, i: number, value: number): void {
    const input = parts.inputs[i]
    if (!input) return

    let val = value
    if (i === 0 && parts.isRange) val = Math.min(val, Number(parts.inputs[1].value))
    if (i === 1) val = Math.max(val, Number(parts.inputs[0].value))

    input.value = String(val)
    this.#update(parts)
    input.dispatchEvent(new Event("input", { bubbles: true }))
  }

  /* What initSlider closed over, resolved per use. A slider without a root, a
   * track or a fill is not one this class can move, so it does nothing at
   * all. */
  #parts(): Parts | null {
    const root = this.querySelector(ROOT)
    if (!root) return null

    const track = root.querySelector(TRACK)
    const fill = root.querySelector<HTMLElement>(FILL)
    if (!track || !fill) return null

    const thumbs = [...root.querySelectorAll<HTMLElement>(THUMB)]
    return {
      root,
      track,
      fill,
      thumbs,
      inputs: [...root.querySelectorAll<HTMLInputElement>(INPUT)],
      min: Number(root.getAttribute(MIN)),
      max: Number(root.getAttribute(MAX)),
      // Upstream's `|| 1`, which also catches a zero step.
      step: Number(root.getAttribute(STEP)) || 1,
      isRange: thumbs.length === 2,
    }
  }
}

customElements.define(contract.element, OhSlider)
