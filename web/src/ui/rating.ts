/* Rating, on the authoring model in README.md: one custom element wrapping the markup
 * ui/rating/rating.odin already emits, widening the clipped copy of
 * each symbol to show how much of the row is filled -- following the pointer
 * while it is over the row, and committing a value when one is clicked.
 *
 * The width is the reason any of this is scripted. rating.odin draws every
 * symbol twice, the filled copy in a box that is `w-0`, so a rendered page shows
 * a row of dim symbols and nothing else: the value is in the markup (the
 * initial-value attribute, and the hidden input that posts it) but the *fill* is
 * only ever an inline width, like progress's bar.
 *
 * ## What changed from the document-delegating rating.js
 *
 * Where the listeners live, and where the committed value lives. rating.js hung
 * five listeners on `document` -- click, mouseover, mouseout, input and reset --
 * matched each event by climbing from e.target to a [data-tui-rating-component],
 * and swept the document for those components at DOMContentLoaded and again on
 * an "htmx:after:init" event no htmx version emits. Four of the five are on
 * `this` here (all four events bubble, so a symbol swapped in later is covered),
 * the sweep is gone -- an element initialises itself when it connects, which is
 * what the sweep was reaching for -- and the fifth is the one exception below.
 *
 * ## The reset listener, which is the whole of the teardown inventory
 *
 * A form's `reset` event is fired at the form and bubbles *up*, so a rating
 * inside that form never sees it: this is the one behaviour an element boundary
 * cannot narrow, and it is on `this.ownerDocument` with a matching
 * removeEventListener in disconnectedCallback (sidebar's shape, and the
 * checklist's "document/window listeners" case). Upstream reset every rating the
 * form contained; the handler here asks the same question of one element
 * (`form.contains(this)`).
 *
 * The platform does have an answer -- `static formAssociated` plus
 * `formResetCallback`, which needs no listener and no teardown -- and it is not
 * taken, because it would make the wrapper a *listed* form control: it would
 * appear in `form.elements`, in the form's validity, and in its disabled
 * propagation, none of which the component being ported was. That is a design
 * change, not a port.
 *
 * The rest of the inventory is empty. No timers, no observers, no rAF, no
 * module registry: the other four listeners are on `this` and die with the node,
 * and the patched `value` setter below is on an input inside this element and
 * dies with it too. So disconnectedCallback removes exactly one thing.
 *
 * ## The committed value
 *
 * rating.js kept it in a data-tui-rating-current attribute it wrote onto the
 * component div, because a delegating document handler has nowhere else to put
 * per-node state -- the same reason toast.js kept a module Map, and it goes the
 * same way: a private field, seeded once per instance from the initial-value
 * attribute the server renders. The attribute is gone rather than moved. Nothing
 * else ever read it: the server does not render it, no stylesheet matches it,
 * and the value a form posts is the hidden input's, as before.
 *
 * The one behavioural delta that follows: an htmx swap that replaces the root
 * div *inside* a surviving <oh-rating> keeps the value this element committed,
 * where upstream's attribute went with the div and the row fell back to the
 * server's number. A swap of the whole element gives a new instance and so the
 * server's number, exactly as before.
 *
 * ## Upstream's oddities, kept
 *
 * The hover preview is not a value: mouseover paints from the symbol under the
 * pointer, mouseout repaints from the committed one, and nothing in between is
 * written anywhere. The restore is keyed on `displayValue > 0`, so a preview and
 * "no preview" are the same argument -- which works only because items are
 * numbered from 1.
 *
 * A partial fill is reachable only from a fractional committed value (a
 * precision below 1, or a fractional value from the server): the preview is
 * always a whole symbol, since it is that symbol's own number. Clicking the
 * symbol a whole value already sits on steps *down* by one precision, which is
 * how a half star is reached at all and how the row is cleared.
 *
 * A read-only rating ignores clicks and previews and has its cursor written back
 * to `default` on connect -- over the `cursor-pointer` class rating.odin renders
 * on every item, read-only included. There is no disabled mode; read-only is the
 * only one.
 *
 * The clamps are upstream's: 0..max, where max is the largest number any symbol
 * carries (at least 1), read from the markup rather than configured.
 *
 * And the two writes to the hidden input are upstream's too. Committing sets
 * `input.value`, which the patched setter announces with an `input` event, and
 * then dispatches `input` and `change` again by hand -- so a commit fires two
 * `input` events, and the first of them re-enters this element's own input
 * handler, which re-clamps to the number just written and repaints. It
 * terminates because that handler writes nothing back.
 *
 * rating.contract.json names everything this class reads from the markup;
 * rating_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./rating.contract.json"

const ROOT = contract.selectors.root
const ITEM = contract.selectors.item
const FILL = contract.selectors.fill
const INPUT = contract.selectors.input
const INITIAL_VALUE = contract.attributes.initialValue
const PRECISION = contract.attributes.precision
const READONLY = contract.attributes.readonly
const NAME = contract.attributes.name
const ONLY_INTEGER = contract.attributes.onlyInteger
const ITEM_VALUE = contract.attributes.itemValue
const ENABLED = contract.enabled

/* Upstream's event name. It is not in the manifest: nothing on the Odin side
 * renders or matches it, so there is no agreement to test -- the checklist's
 * aria-expanded case. */
const CHANGE_EVENT = "rating-change"

/* getConfig, unchanged including its coercions: parseFloat of a missing
 * attribute is NaN and `|| 0` (or `|| 1`) catches it, so a hand-written rating
 * with no precision steps by whole symbols rather than by nothing. */
type Config = {
  value: number
  precision: number
  readonly: boolean
  name: string
  onlyInteger: boolean
}

const config = (root: Element): Config => ({
  value: parseFloat(root.getAttribute(INITIAL_VALUE) ?? "") || 0,
  precision: parseFloat(root.getAttribute(PRECISION) ?? "") || 1,
  readonly: root.getAttribute(READONLY) === ENABLED,
  name: root.getAttribute(NAME) || "",
  onlyInteger: root.getAttribute(ONLY_INTEGER) === ENABLED,
})

/* enableReactiveBinding, ported as checkbox.ts ported its twin: the guard is a
 * WeakSet rather than a flag property on the input, and the patch is the same
 * one -- a `value` setter that announces itself, so that a framework writing
 * input.value in code is seen by the input handler below. The oddity is
 * upstream's: the comparison is `old !== v`, on whatever type the caller passed,
 * so writing the number 3 over the string "3.00" counts as a change. */
const patched = new WeakSet<HTMLInputElement>()

const descriptor = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value")

const bindValue = (input: HTMLInputElement): void => {
  if (patched.has(input)) return

  const get = descriptor?.get
  const set = descriptor?.set
  if (!get || !set) return

  patched.add(input)
  Object.defineProperty(input, "value", {
    get,
    set(this: HTMLInputElement, value: string) {
      const old = get.call(this)
      set.call(this, value)
      if (old !== value) {
        this.dispatchEvent(new Event("input", { bubbles: true }))
      }
    },
    configurable: true,
  })
}

class OhRating extends HTMLElement {
  /* The committed value -- what rating.js kept in data-tui-rating-current. View
   * state: it dies with the element, and null means "not committed yet", which
   * is what makes getCurrentValue's fall back to the initial-value attribute the
   * same one line it was. */
  #current: number | null = null

  /* Listeners on `this` cover symbols swapped in later and die with the element.
   * The fields hold the handlers rather than bound methods so the references are
   * stable -- connectedCallback runs again on every move, and addEventListener
   * de-duplicates by reference. */
  #onClick = (event: Event): void => {
    const parts = this.#parts(event.target)
    if (!parts?.item) return

    const { root, item } = parts
    const conf = config(root)
    if (conf.readonly) return

    const itemValue = parseInt(item.getAttribute(ITEM_VALUE) ?? "", 10)
    if (isNaN(itemValue)) return

    const current = this.#value(root)
    const max = this.#max()

    // Upstream's arithmetic, branch for branch: an integer rating rounds (which
    // does nothing to a whole symbol's own number), and a fractional one steps
    // down by one precision when the symbol clicked is the whole value already
    // showing -- otherwise it snaps to the precision grid.
    let newValue = itemValue
    if (conf.onlyInteger) {
      newValue = Math.round(newValue)
    } else if (current === newValue && newValue % 1 === 0) {
      newValue = Math.max(0, newValue - conf.precision)
    } else {
      newValue = Math.round(newValue / conf.precision) * conf.precision
    }

    this.#commit(Math.max(0, Math.min(max, newValue)))
    this.#paint(root, 0)

    /* Dispatched from the root rather than from `this`: the caller's own
     * attributes (an hx-trigger, say) land on the root div, so an event that
     * skipped it would skip them. It bubbles through this element either way. */
    root.dispatchEvent(
      new CustomEvent(CHANGE_EVENT, {
        bubbles: true,
        detail: { name: conf.name, value: newValue, maxValue: max },
      }),
    )
  }

  // The preview: the symbol under the pointer, painted and not written down.
  #onMouseover = (event: Event): void => {
    const parts = this.#parts(event.target)
    if (!parts?.item) return
    if (config(parts.root).readonly) return

    const previewValue = parseInt(parts.item.getAttribute(ITEM_VALUE) ?? "", 10)
    if (!isNaN(previewValue)) this.#paint(parts.root, previewValue)
  }

  /* And the restore, on the way out of the component as a whole -- upstream's
   * `!ratingElement.contains(e.relatedTarget)`, asked of this element instead.
   * The wrapper is display:contents and so generates no box of its own, which is
   * why the two questions have the same answer. */
  #onMouseout = (event: Event): void => {
    const parts = this.#parts(event.target)
    if (!parts) return
    if (config(parts.root).readonly) return

    const related = (event as MouseEvent).relatedTarget
    if (related instanceof Node && this.contains(related)) return

    this.#paint(parts.root, 0)
  }

  /* The hidden input as an input: something outside wrote a value (by hand, or
   * through the patched setter above), so the row catches up. Nothing is written
   * back, which is what stops the commit -> input -> repaint chain. */
  #onInput = (event: Event): void => {
    const target = event.target
    if (!(target instanceof HTMLInputElement) || !target.matches(INPUT)) return

    const root = this.#root()
    if (!root) return

    const value = parseFloat(target.value) || 0
    this.#current = Math.max(0, Math.min(this.#max(), value))
    this.#paint(root, 0)
  }

  /* THE one listener that is not on `this`: a form's reset is fired at the form
   * and bubbles up, past every rating inside it. Removed in
   * disconnectedCallback. */
  #onReset = (event: Event): void => {
    const form = event.target
    if (!(form instanceof HTMLFormElement) || !form.contains(this)) return

    const root = this.#root()
    if (!root) return

    /* Upstream's two lines. The browser resets the hidden input to its own
     * `value` content attribute a moment later, which is the same number this
     * writes -- rating.odin renders both from the same prop -- so the two do not
     * fight. A read-only rating is reset too, as upstream reset it. */
    this.#commit(config(root).value)
    this.#paint(root, 0)
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)
    this.addEventListener("mouseover", this.#onMouseover)
    this.addEventListener("mouseout", this.#onMouseout)
    this.addEventListener("input", this.#onInput)
    this.ownerDocument.addEventListener("reset", this.#onReset)

    const root = this.#root()
    if (!root) return

    // initializeRatings, narrowed to this element.
    const input = this.#input()
    if (input) bindValue(input)

    const conf = config(root)
    if (this.#current === null) {
      const value = Math.max(0, Math.min(this.#max(), conf.value))
      this.#commit(Math.round(value / conf.precision) * conf.precision)
    }

    this.#paint(root, 0)

    /* Upstream's cursor override, which is how a read-only rating stops looking
     * clickable: rating.odin renders `cursor-pointer` on every symbol, read-only
     * included, and this writes over it. Symbols swapped in afterwards keep the
     * class -- upstream's sweep had the same hole, and closing it would mean
     * watching the subtree for a cosmetic. */
    if (conf.readonly) {
      if (root instanceof HTMLElement) root.style.cursor = "default"
      for (const item of this.#items()) item.style.cursor = "default"
    }
  }

  /* Required, and only for this: the reset listener is on the document and would
   * otherwise keep answering for -- and keep alive -- a rating that has left the
   * page. The other four are on `this` and go with it. */
  disconnectedCallback(): void {
    this.ownerDocument.removeEventListener("reset", this.#onReset)
  }

  /* updateItemStyles, unchanged. `displayValue > 0 ? displayValue : current` is
   * upstream's way of saying "preview, or the committed value" in one argument;
   * a symbol's number is never 0, so nothing collides. */
  #paint(root: Element, displayValue: number): void {
    const compare = displayValue > 0 ? displayValue : this.#value(root)

    for (const item of this.#items()) {
      const itemValue = parseInt(item.getAttribute(ITEM_VALUE) ?? "", 10)
      if (isNaN(itemValue)) continue

      const fill = item.querySelector<HTMLElement>(FILL)
      if (!fill) continue

      const filled = itemValue <= Math.floor(compare)
      const partial = !filled && itemValue - 1 < compare && compare < itemValue
      const percentage = partial ? (compare - Math.floor(compare)) * 100 : 0

      fill.style.width = filled ? "100%" : partial ? `${percentage}%` : "0%"
    }
  }

  /* setCurrentValue: the field instead of the attribute, and then the hidden
   * input, which is where a form reads the value from. Both events are
   * upstream's, and the patched setter adds a third -- see the file comment. */
  #commit(value: number): void {
    this.#current = value

    const input = this.#input()
    if (!input) return

    input.value = value.toFixed(2)
    input.dispatchEvent(new Event("input", { bubbles: true }))
    input.dispatchEvent(new Event("change", { bubbles: true }))
  }

  // getCurrentValue: the committed value, or the one the server rendered.
  #value(root: Element): number {
    return this.#current ?? config(root).value
  }

  /* getMaxValue: the largest number any symbol carries, and at least 1 -- the
   * row's length is markup, not configuration. */
  #max(): number {
    let max = 0
    for (const item of this.#items()) {
      const value = parseInt(item.getAttribute(ITEM_VALUE) ?? "", 10)
      if (!isNaN(value) && value > max) max = value
    }
    return Math.max(1, max)
  }

  /* What the delegating handlers got by climbing from e.target. The root is
   * looked up per use rather than closed over, so markup swapped in under this
   * element is picked up; `item` is null for the events that do not need one. */
  #parts(target: EventTarget | null): { root: Element; item: Element | null } | null {
    const root = this.#root()
    if (!root) return null

    if (!(target instanceof Element)) return { root, item: null }

    const item = target.closest(ITEM)
    return { root, item: item && this.contains(item) ? item : null }
  }

  #root(): Element | null {
    return this.querySelector(ROOT)
  }

  #items(): HTMLElement[] {
    return [...this.querySelectorAll<HTMLElement>(ITEM)]
  }

  #input(): HTMLInputElement | null {
    return this.querySelector<HTMLInputElement>(INPUT)
  }
}

customElements.define(contract.element, OhRating)
