/* Input OTP, on the authoring model in README.md: one custom element wrapping the markup
 * ui/inputotp/inputotp.odin already emits -- a row of one-character
 * boxes -- making the row behave like a single field: typing walks focus
 * forward, Backspace walks it back, a paste spreads across the boxes, and the
 * hidden input beside them is kept holding the code the form posts.
 *
 * The boxes are real inputs and are typeable without any of this. What needs the
 * script is that they are *one* value: nothing in the markup joins six
 * one-character fields into the string a form sends, and nothing moves the caret
 * from one to the next.
 *
 * ## What changed from the document-delegating inputotp.js
 *
 * Where the listeners live, not what they do. inputotp.js hung six listeners on
 * `document` (input, keydown, focus in the capture phase, paste, click, reset),
 * each opening with a match or a closest() to a slot and then a climb to the
 * enclosing [data-tui-inputotp]. Four of the six are on `this` here and the climb
 * is gone with them: whatever the event came from is inside this element, so this
 * element is the container. Two cannot move, and are the whole teardown
 * inventory -- see below.
 *
 * The document sweep goes too. initializeInputOTPs() -- spreading a
 * server-rendered value across the slots, and honouring `autofocus` -- is what
 * connectedCallback does for one element, which is what the sweep was reaching
 * for. With it go the DOMContentLoaded call and the "htmx:after:init" listener
 * (an event no htmx version emits); the local comment explaining why the
 * DOMContentLoaded call had to be added at all retires with them, since an
 * element needs no help to run when it is inserted.
 *
 * `focus` was listened for on the document *in the capture phase*, because focus
 * does not bubble and a delegating handler has no other way to see it. On `this`
 * that is `focusin`, which does bubble -- the checklist's named exception.
 *
 * ## What outlives the node
 *
 * Two listeners, both on `this.ownerDocument`, both removed in
 * disconnectedCallback:
 *
 * - **click**, for a `<label for>` pointing at the hidden input. `input
 *   type="hidden"` is not a labelable element, so the browser forwards nothing
 *   and upstream implemented the forwarding by hand; the label sits outside the
 *   component, so the click never passes through this element. Narrowed to this
 *   element by `this.contains(hidden)`, where upstream took whatever
 *   getElementById returned.
 * - **reset**, for a form. A form fires `reset` at itself and it bubbles *up*, so
 *   an input OTP inside the form never sees it -- rating.ts's case exactly.
 *   Upstream cleared every container the form held; this asks the same question
 *   of one element (`form.contains(this)`).
 *
 * The rest of the inventory is empty, and deliberately not torn down. There is no
 * interval, no observer, no module registry. There *are* timers -- `focusSlot`
 * ends in `setTimeout(() => slot.select(), 0)`, upstream's way of selecting after
 * the focus has landed -- and one `requestAnimationFrame`, the autofocus on
 * connect. Both follow the checklist's principle rather than a blanket rule: each
 * callback touches only an input inside this element, and `focus()` or `select()`
 * on a detached input is a no-op. Cancelling them would be teardown for something
 * that already dies harmlessly, so they are left alone and the removal check
 * measures that they stop.
 *
 * ## Ported as it stands
 *
 * The slots are ordered by `data-oh-inputotp-index`, not by document order, so a
 * mis-numbered row scrambles the code without looking wrong. Everything below
 * that walks the row -- next, previous, first empty, the paste's starting point,
 * the assembled value -- uses that order. `parseInt` of a missing index is NaN,
 * which sorts unpredictably; that is upstream's, and the Odin side always writes
 * the attribute.
 *
 * The other oddities, kept: a slot holding a single space is emptied rather than
 * counted (typing a space is how a box is cleared without Backspace); a slot with
 * more than one character keeps the *last*, so typing over a full box replaces
 * it; Backspace on a filled box clears it and stays put, and only on an empty box
 * moves back -- clearing the box it moves to, so one keystroke can destroy two
 * characters; a paste starts at the box the pointer is in and runs forward,
 * dropping whatever does not fit and leaving anything before it alone; and after
 * a paste focus goes to the first *empty* box anywhere in the row, which may be
 * behind where the paste landed.
 *
 * Focusing any box redirects to the first empty one, so a half-filled row cannot
 * be edited in the middle by clicking -- the arrow keys are the way in. That is
 * upstream's, and it is the reason ArrowLeft/ArrowRight exist at all.
 *
 * And one found by measuring rather than reading, kept because a port is a
 * port: in Chromium `input.select()` *focuses* the input it selects, and both
 * `focusSlot` and the focusin handler defer a `select()` by a 0ms timeout. One
 * box at a time that is inert -- the deferred select runs while the box is still
 * focused, so it changes nothing and fires no further focusin. But two focus
 * moves inside one 4ms window leave two live select chains, and from then on
 * each steals the caret back from the other, re-firing focusin and re-arming
 * itself: the caret oscillates between the two boxes at the nested-timeout clamp
 * until the element leaves the document. inputotp.js has the identical pair of
 * deferred selects, so this is not something the port introduced, and real input
 * does not reach it (key auto-repeat is an order of magnitude slower than the
 * clamp) -- but it is why the removal check measures the timers rather than
 * reasoning about them.
 *
 * One stated deviation: upstream read `(e.clipboardData || window.clipboardData)`,
 * the second being IE's. `event.clipboardData` alone is read here -- the fallback
 * is dead in every browser that has custom elements to run this in.
 *
 * inputotp.contract.json names everything this class reads from the markup;
 * inputotp_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./inputotp.contract.json"

const ROOT = contract.selectors.root
const SLOT = contract.selectors.slot
const VALUE_TARGET = contract.selectors.valueTarget
const VALUE = contract.attributes.value
const INDEX = contract.attributes.index

/* Upstream's own two names, and neither is this component's vocabulary: a
 * `<label for>` is the platform's, and `autofocus` is a plain HTML attribute a
 * caller passes through to the root. inputotp.odin renders neither, so there is
 * nothing for inputotp_test.odin to assert and they stay out of the manifest --
 * the checklist's aria-expanded case. */
const LABEL = "label[for]"
const AUTOFOCUS = "autofocus"

/* focusSlot, unchanged including the timer: `select()` is deferred to the next
 * task so it runs after the focus has actually landed, which is what makes
 * typing over a filled box replace it. The timeout touches one input inside the
 * element and is not cancelled on disconnect -- see the file comment. */
const focusSlot = (slot: HTMLInputElement | null | undefined): void => {
  if (!slot) return

  slot.focus()
  setTimeout(() => slot.select(), 0)
}

class OhInputotp extends HTMLElement {
  /* Four listeners on `this` cover slots swapped in later and die with the
   * element; two on the document do not, and are removed below. The fields hold
   * the handlers rather than bound methods so the references are stable --
   * connectedCallback runs again on every move, and addEventListener
   * de-duplicates by reference. */

  #onInput = (event: Event): void => {
    const slot = this.#slotFrom(event.target)
    if (!slot) return

    // A space is how a box is cleared without Backspace: nothing advances.
    if (slot.value === " ") {
      slot.value = ""
      return
    }

    // Typing into a full box replaces it, rather than being dropped by
    // maxlength -- the input arrives with two characters and the last wins.
    if (slot.value.length > 1) {
      slot.value = slot.value.slice(-1)
    }

    if (slot.value) {
      focusSlot(this.#next(slot))
    }

    this.#assemble()
  }

  #onKeydown = (event: KeyboardEvent): void => {
    const slot = this.#slotFrom(event.target)
    if (!slot) return

    if (event.key === "Backspace") {
      event.preventDefault()

      if (slot.value) {
        slot.value = ""
        this.#assemble()
        return
      }

      /* Upstream's flow, kept: from an empty box, Backspace moves back *and*
       * clears what it moves to, so the keystroke destroys the previous
       * character rather than only the caret's position. */
      const prev = this.#prev(slot)
      if (prev) {
        prev.value = ""
        this.#assemble()
        focusSlot(prev)
      }
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      focusSlot(this.#prev(slot))
    } else if (event.key === "ArrowRight") {
      event.preventDefault()
      focusSlot(this.#next(slot))
    }
  }

  /* focus does not bubble; focusin does -- which is what upstream's capture-phase
   * document listener was working around. Landing on any box sends the caret to
   * the first empty one, so a row is filled left to right. */
  #onFocusin = (event: FocusEvent): void => {
    const slot = this.#slotFrom(event.target)
    if (!slot) return

    const firstEmpty = this.#firstEmpty()
    if (firstEmpty && firstEmpty !== slot) {
      focusSlot(firstEmpty)
      return
    }

    setTimeout(() => slot.select(), 0)
  }

  /* A paste anywhere in the row spreads from the box it landed in. closest()
   * rather than matches(), as upstream had it: the event's target can be the
   * input itself, and a closest() also catches a paste aimed at something inside
   * one. */
  #onPaste = (event: ClipboardEvent): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    const slot = target.closest<HTMLInputElement>(SLOT)
    if (!slot || !this.contains(slot)) return

    event.preventDefault()

    const chars = (event.clipboardData?.getData("text") ?? "").replace(/\s/g, "").split("")
    const slots = this.#slots()
    const startIndex = slots.indexOf(slot)

    for (let i = 0; i < chars.length && startIndex + i < slots.length; i++) {
      slots[startIndex + i].value = chars[i]
    }

    this.#assemble()

    /* Focus the first empty box *anywhere* in the row, which may be behind where
     * the paste landed -- upstream's, and the reason a partial paste into the
     * middle of a half-filled row jumps backwards. */
    focusSlot(this.#firstEmpty() ?? slots[Math.min(startIndex + chars.length, slots.length - 1)])
  }

  /* THE first of the two listeners that cannot live on `this`: the label is
   * outside the component, and `input type="hidden"` is not labelable, so the
   * browser forwards nothing on its own. */
  #onDocumentClick = (event: MouseEvent): void => {
    const target = event.target
    if (!(target instanceof Element) || !target.matches(LABEL)) return

    const id = target.getAttribute("for")
    if (!id) return

    const hidden = this.ownerDocument.getElementById(id)
    if (!hidden?.matches(VALUE_TARGET) || !this.contains(hidden)) return

    event.preventDefault()
    focusSlot(this.#slots()[0])
  }

  /* THE second: a form fires `reset` at itself and it bubbles up past every
   * input OTP inside it -- rating.ts's case, with the same answer. The browser
   * clears the slots and the hidden input a moment later anyway (none carries a
   * `value` content attribute), which is why the two do not fight. */
  #onReset = (event: Event): void => {
    const form = event.target
    if (!(form instanceof HTMLFormElement) || !form.contains(this)) return

    for (const slot of this.#slots()) slot.value = ""

    this.#assemble()
  }

  connectedCallback(): void {
    this.addEventListener("input", this.#onInput)
    this.addEventListener("keydown", this.#onKeydown)
    this.addEventListener("focusin", this.#onFocusin)
    this.addEventListener("paste", this.#onPaste)
    this.ownerDocument.addEventListener("click", this.#onDocumentClick)
    this.ownerDocument.addEventListener("reset", this.#onReset)

    // initializeInputOTPs, narrowed to this element.
    const root = this.#root()
    const slots = this.#slots()
    if (!root || slots.length === 0) return

    /* The server's value, spread across the boxes -- the markup renders them
     * empty, so an unscripted page shows nothing and posts nothing. Guarded on
     * the first box being empty, so a re-connect (a move, an htmx swap of an
     * ancestor) does not overwrite what has been typed. */
    const initial = root.getAttribute(VALUE)
    if (initial && !slots[0].value) {
      for (let i = 0; i < slots.length && i < initial.length; i++) {
        if (!slots[i].value) slots[i].value = initial[i]
      }
      this.#assemble()
    }

    /* autofocus on the root, which is a caller's own attribute rather than a
     * prop. The rAF is upstream's -- one frame, so the row is laid out before
     * the caret lands -- and the activeElement test is asked twice, before and
     * inside it, exactly as upstream asked it. */
    const active = this.ownerDocument.activeElement
    if (root.hasAttribute(AUTOFOCUS) && !slots.some((slot) => slot === active)) {
      requestAnimationFrame(() => {
        const now = this.ownerDocument.activeElement
        if (slots[0] && !slots.some((slot) => slot === now)) {
          focusSlot(slots[0])
        }
      })
    }
  }

  /* Required, and only for this: the two document-scoped listeners would
   * otherwise keep answering for -- and keep alive -- an input OTP that has left
   * the page. The four on `this` go with it, and the timers die harmlessly. */
  disconnectedCallback(): void {
    this.ownerDocument.removeEventListener("click", this.#onDocumentClick)
    this.ownerDocument.removeEventListener("reset", this.#onReset)
  }

  /* updateHiddenValue: the one field that posts, holding what the boxes spell.
   * Unchanged, guard included -- a row with no boxes leaves the hidden input
   * alone rather than blanking it. */
  #assemble(): void {
    const hidden = this.#hidden()
    const slots = this.#slots()
    if (hidden && slots.length) {
      hidden.value = slots.map((slot) => slot.value).join("")
    }
  }

  /* getSlots: index order, not document order -- see the file comment. Read per
   * use rather than closed over, so boxes swapped in under this element are
   * picked up; the listeners are on `this` and outlive any particular row. */
  #slots(): HTMLInputElement[] {
    return [...this.querySelectorAll<HTMLInputElement>(SLOT)].sort(
      (a, b) => parseInt(a.getAttribute(INDEX) ?? "") - parseInt(b.getAttribute(INDEX) ?? ""),
    )
  }

  #next(slot: HTMLInputElement): HTMLInputElement | null {
    const slots = this.#slots()
    const index = slots.indexOf(slot)
    return index >= 0 && index < slots.length - 1 ? slots[index + 1] : null
  }

  #prev(slot: HTMLInputElement): HTMLInputElement | null {
    const slots = this.#slots()
    const index = slots.indexOf(slot)
    return index > 0 ? slots[index - 1] : null
  }

  #firstEmpty(): HTMLInputElement | null {
    for (const slot of this.#slots()) {
      if (!slot.value) return slot
    }
    return null
  }

  // The box an event came from, or null: upstream's opening matches().
  #slotFrom(target: EventTarget | null): HTMLInputElement | null {
    if (!(target instanceof HTMLInputElement) || !target.matches(SLOT)) return null

    return this.contains(target) ? target : null
  }

  #root(): Element | null {
    return this.querySelector(ROOT)
  }

  #hidden(): HTMLInputElement | null {
    return this.querySelector<HTMLInputElement>(VALUE_TARGET)
  }
}

customElements.define(contract.element, OhInputotp)
