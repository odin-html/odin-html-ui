/* Tags input, on the authoring model in README.md: one custom element wrapping the
 * markup ui/tagsinput/tagsinput.odin already emits -- a box of chips
 * over a text field -- turning what is typed into a chip and a hidden input,
 * taking chips back off, and driving the suggestions popover as the field is
 * typed in.
 *
 * The tags the server was given are already chips and already hidden inputs, so
 * the field posts its list with or without this class. What needs the script is
 * adding and removing them.
 *
 * ## The popover coupling, on the platform
 *
 * The suggestions list is a popover with {kind = .Manual}: its open and close
 * are tagsinput behaviour (typing filters, focus leaves), so light dismiss
 * and Escape must not fight them -- this root is manual by design. The old window.tui.popover global is gone; this class drives the
 * content through the platform's own calls, showPopover()/hidePopover()/
 * matches(":popover-open"), on the content element itself.
 *
 * The two names borrowed from popover -- its element tag and its content role
 * -- stay out of tagsinput.contract.json: the manifest declares what
 * tagsinput.odin and this class must agree on, and those are popover.odin's
 * to render and popover's contract to declare. tagsinput_test.odin pins the
 * composition (a manual popover, addressed by id), which is where the
 * coupling is checked.
 *
 * The id is the seam: tagsinput.odin writes the popover root's id into
 * data-oh-tagsinput-suggestions-id -- its own attribute, and in the manifest --
 * and that string is what the lookup uses. The list's width is
 * anchor-size(width) now, which retired the --trigger-width variable this
 * class used to measure and write on every open.
 *
 * ## What changed from the document-delegating tagsinput.js
 *
 * Where the listeners live, not what they do. tagsinput.js hung six listeners on
 * `document` (focusin, focusout, input, mousedown, click, keydown), each opening
 * with a closest() to a text input or a suggestion and then a climb to the
 * enclosing [data-tui-tagsinput]. All six are on `this` here, and the climb is
 * gone with them: whatever the event came from is inside this element, so this
 * element is the container. The suggestion list is inside it too -- popover
 * content in the top layer keeps its place in the DOM, so a mousedown on a
 * suggestion still bubbles here.
 *
 * The two document-wide lookups are narrowed. The popover root is still found by
 * id, but it must also be inside this element, so two tags inputs sharing an id
 * cannot answer for each other; and the mousedown handler's
 * `document.querySelector([data-tui-tagsinput-suggestions-id="..."])` -- the
 * climb back from a suggestion to its container -- is just `this`.
 *
 * ## What outlives the node
 *
 * The inventory, per the checklist: no timers (nothing here is debounced --
 * every keystroke filters the list synchronously, as upstream did), no
 * intervals, no rAF, no observers, no module registry, and no document or window
 * listeners now the six have moved to `this`. Nothing outlives the node, so
 * there is no disconnectedCallback -- adding one would only tear down listeners
 * that die with the element anyway.
 *
 * A removed tags input takes its open suggestions popover with it: the
 * content is a descendant, the browser drops a disconnected popover out of
 * the top layer on its own, and there is no positioning loop to stop any more
 * -- CSS anchors do not tick. Nothing to own, nothing to tear down.
 *
 * ## Ported as it stands
 *
 * data-oh-tagsinput-form is rendered by the Odin side and read by nobody -- the
 * hidden inputs are written without a form attribute, so a tags input outside
 * its form posts nothing. Upstream had the same hole; it is not in the manifest
 * because this class does not read it.
 *
 * data-oh-tagsinput-suggestions-content is likewise rendered and unread: the
 * content is found through the popover root, the way tagsinput.js found it.
 * That marker is the obvious way to stop reading popover's
 * attributes at all -- but swapping to it now would change what the class reads
 * without changing what it does.
 *
 * The highlight is the bare Tailwind utility upstream used, `bg-accent`, which
 * is not in the manifest either: nothing on the Odin side renders or matches it
 * (the suggestion's own class list has hover:bg-accent, a different generated
 * class), so there is no agreement for tagsinput_test.odin to assert. The chip's
 * label is found as `span`, upstream's own structural lookup rather than a
 * declared role, and stays out for the same reason -- giving it a role attribute
 * would be a redesign rather than a port.
 *
 * Behaviour is upstream's, oddities included: a chip is matched to its hidden
 * input by value, so two tags differing only in case cannot both exist (the
 * duplicate check lowercases) and the first input with a matching value is the
 * one that goes; the comma key adds a tag and never reaches the field; Enter
 * adds the highlighted suggestion or the raw text; Backspace on an empty field
 * takes the last chip whether or not it was the last one added; and the
 * suggestion list is filtered by substring, unanchored.
 *
 * ## Two stated deviations
 *
 * tagsinput.js built the chip with innerHTML and the typed value interpolated
 * into it, which executes markup a suggestion or a paste can carry. The chip
 * here is built with createElement and the value goes in as textContent -- same
 * DOM for every value that is not an attack, and no script for the ones that
 * are. The remove button's svg is still innerHTML, being a constant with nothing
 * interpolated into it.
 *
 * The hidden input to drop was likewise found with an interpolated selector,
 * `input[value="${val}"]`, which throws on a tag containing a quote. The loop
 * below compares values instead and takes the first match, which is what
 * querySelector did for every value that parsed.
 *
 * tagsinput.contract.json names everything this class reads from the markup;
 * tagsinput_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./tagsinput.contract.json"

const ROOT = contract.selectors.root
const CHIPS = contract.selectors.chips
const CHIP = contract.selectors.chip
const REMOVE = contract.selectors.remove
const HIDDEN_INPUTS = contract.selectors.hiddenInputs
const TEXT_INPUT = contract.selectors.textInput
const SUGGESTION = contract.selectors.suggestion
const NAME = contract.attributes.name
const SUGGESTIONS_ID = contract.attributes.suggestionsId
const SUGGESTION_VALUE = contract.attributes.suggestionValue
const CHIP_ATTR = contract.attributes.chip
const REMOVE_ATTR = contract.attributes.remove

/* popover's vocabulary, not this component's -- the seam, isolated here per
 * the borrowed-vocabulary rule. */
const POPOVER_ROOT = "oh-popover"
const POPOVER_CONTENT = "[data-oh-popover-content]"

// The highlighted suggestion.
const HIGHLIGHT = "bg-accent"

/* The chip tagsinput.js writes for a tag added in the browser. Not badge's
 * class list, which is what tagsinput.odin renders for a tag the server was
 * given -- upstream's two do not match either, and matching them up is a change
 * to what the component looks like rather than to what it does. */
const CHIP_CLASS =
  "inline-flex items-center gap-2 rounded-md border px-2.5 py-0.5 text-xs " +
  "font-semibold border-transparent bg-primary text-primary-foreground"
const REMOVE_CLASS = "ml-1 hover:text-destructive cursor-pointer"
const REMOVE_ICON =
  `<svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" ` +
  `stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" ` +
  `d="M6 18L18 6M6 6l12 12"/></svg>`

// The chip's label, upstream's structural lookup -- see the file comment.
const CHIP_LABEL = "span"

class OhTagsinput extends HTMLElement {
  /* Six listeners, all on `this`: they cover chips, suggestions and a field
   * swapped in later, and they die with the element -- which is the whole
   * teardown inventory, hence no disconnectedCallback. The fields hold the
   * handlers rather than bound methods so the references are stable --
   * connectedCallback runs again on every move, and addEventListener
   * de-duplicates by reference. */

  // focus does not bubble; focusin does. Upstream listened for focusin too.
  #onFocusin = (event: FocusEvent): void => {
    const input = this.#fieldFrom(event.target)
    if (!input) return

    this.#showSuggestions(input.value)
  }

  /* Leaving the field for anything outside this element closes the list.
   * relatedTarget inside the popover content is covered by the first test --
   * the content is a descendant -- and upstream's second test is kept anyway,
   * since it is what makes the intent readable. */
  #onFocusout = (event: FocusEvent): void => {
    const input = this.#fieldFrom(event.target)
    if (!input) return

    const next = event.relatedTarget
    if (next instanceof Node && (this.contains(next) || this.#content()?.contains(next))) {
      return
    }

    this.#closeSuggestions()
  }

  #onInput = (event: Event): void => {
    const input = this.#fieldFrom(event.target)
    if (!input) return

    this.#showSuggestions(input.value)
  }

  /* mousedown rather than click, so the tag is added before the field's
   * focusout can close the list under the pointer. */
  #onMousedown = (event: MouseEvent): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    const suggestion = target.closest(SUGGESTION)
    if (!suggestion || !this.contains(suggestion)) return

    event.preventDefault() // Prevent focus change
    this.#addTag(suggestion.getAttribute(SUGGESTION_VALUE) ?? "")
    this.#showSuggestions("")
  }

  #onClick = (event: MouseEvent): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    // Re-clicking an already focused field reopens the list, which focusin
    // alone would not do.
    const input = this.#fieldFrom(target)
    if (input) {
      this.#showSuggestions(input.value)
      return
    }

    const remove = target.closest(REMOVE)
    if (remove && this.contains(remove)) {
      const chip = remove.closest(CHIP)
      if (chip) this.#removeTag(chip)
      return
    }

    // Anywhere else in the box focuses the field, so the whole thing behaves
    // like one input. Upstream's climb to the container is what `this` is.
    if (!target.closest("input")) this.#field()?.focus()
  }

  #onKeydown = (event: KeyboardEvent): void => {
    const input = this.#fieldFrom(event.target)
    if (!input) return

    const isOpen = this.#content()?.matches(":popover-open") === true

    if (event.key === "ArrowDown" && isOpen) {
      event.preventDefault()
      this.#moveSelection(1)
    } else if (event.key === "ArrowUp" && isOpen) {
      event.preventDefault()
      this.#moveSelection(-1)
    } else if (event.key === "Enter") {
      event.preventDefault()
      const highlighted = this.#visibleSuggestions().find((el) =>
        el.classList.contains(HIGHLIGHT),
      )
      this.#addTag(
        highlighted ? (highlighted.getAttribute(SUGGESTION_VALUE) ?? "") : input.value,
      )
      this.#showSuggestions("")
    } else if (event.key === ",") {
      event.preventDefault()
      this.#addTag(input.value)
      this.#showSuggestions("")
    } else if (event.key === "Escape" && isOpen) {
      event.preventDefault()
      this.#closeSuggestions()
    } else if (event.key === "Backspace" && input.value === "") {
      const last = this.querySelector(CHIPS)?.lastElementChild
      if (last) this.#removeTag(last)
    }
  }

  connectedCallback(): void {
    this.addEventListener("focusin", this.#onFocusin)
    this.addEventListener("focusout", this.#onFocusout)
    this.addEventListener("input", this.#onInput)
    this.addEventListener("mousedown", this.#onMousedown)
    this.addEventListener("click", this.#onClick)
    this.addEventListener("keydown", this.#onKeydown)
  }

  /* showSuggestions, unchanged in what it decides: a suggestion is shown when
   * it is not already a tag and contains what has been typed, the first shown
   * one is highlighted, and the popover is open exactly when something is left
   * to show. */
  #showSuggestions(query: string): void {
    const popup = this.#content()
    const input = this.#field()
    if (!popup || !input) return

    const selected = this.#selected()
    const q = query.toLowerCase().trim()
    let first: HTMLElement | null = null

    for (const el of popup.querySelectorAll<HTMLElement>(SUGGESTION)) {
      const val = (el.getAttribute(SUGGESTION_VALUE) ?? "").toLowerCase()
      const show = !selected.includes(val) && val.includes(q)
      el.style.display = show ? "" : "none"
      el.classList.remove(HIGHLIGHT)
      if (show && !first) first = el
    }

    // The platform's own calls, on a manual popover no light dismiss fights.
    if (first) {
      first.classList.add(HIGHLIGHT)
      if (!popup.matches(":popover-open")) popup.showPopover()
    } else {
      this.#closeSuggestions()
    }
  }

  #closeSuggestions(): void {
    const popup = this.#content()
    if (popup?.matches(":popover-open")) popup.hidePopover()
  }

  // moveSelection, unchanged: the highlight wraps at both ends.
  #moveSelection(step: number): void {
    const items = this.#visibleSuggestions()
    if (!items.length) return

    const current = items.findIndex((el) => el.classList.contains(HIGHLIGHT))
    for (const el of items) el.classList.remove(HIGHLIGHT)

    let next = current + step
    if (next >= items.length) next = 0
    if (next < 0) next = items.length - 1

    items[next].classList.add(HIGHLIGHT)
    items[next].scrollIntoView({ block: "nearest" })
  }

  /* addTag, unchanged but for how the chip is built -- see the file comment.
   * A blank value, a disabled field and a duplicate all do nothing but clear
   * what was typed. */
  #addTag(value: string): void {
    const input = this.#field()
    const val = value.trim()
    if (!val || !input || input.disabled) return

    if (this.#selected().includes(val.toLowerCase())) {
      input.value = ""
      return
    }

    const chips = this.querySelector(CHIPS)
    const hidden = this.querySelector(HIDDEN_INPUTS)
    if (!chips || !hidden) return

    const chip = this.ownerDocument.createElement("div")
    chip.className = CHIP_CLASS
    chip.setAttribute(CHIP_ATTR, "")

    const label = this.ownerDocument.createElement(CHIP_LABEL)
    label.textContent = val

    const button = this.ownerDocument.createElement("button")
    button.type = "button"
    button.className = REMOVE_CLASS
    button.setAttribute(REMOVE_ATTR, "")
    button.innerHTML = REMOVE_ICON

    chip.append(label, button)
    chips.appendChild(chip)

    // What the form actually sends: one hidden input per tag, all sharing the
    // name the Odin side wrote onto the root.
    const field = this.ownerDocument.createElement("input")
    field.type = "hidden"
    field.name = this.#root()?.getAttribute(NAME) ?? ""
    field.value = val
    hidden.appendChild(field)

    input.value = ""
  }

  /* The chip goes, and the hidden input carrying its text with it. Upstream's
   * two copies of this -- the remove button and Backspace -- are one here. */
  #removeTag(chip: Element): void {
    const val = chip.querySelector(CHIP_LABEL)?.textContent
    chip.remove()
    if (val == null) return

    const hidden = this.querySelector(HIDDEN_INPUTS)
    if (!hidden) return

    for (const field of hidden.querySelectorAll<HTMLInputElement>("input")) {
      if (field.value === val) {
        field.remove()
        return
      }
    }
  }

  /* What the module functions took a container argument for. Read per use
   * rather than closed over, so markup swapped in under the element is picked
   * up -- the listeners are on `this` and outlive any particular field, chip or
   * list. */
  #root(): Element | null {
    return this.querySelector(ROOT)
  }

  #field(): HTMLInputElement | null {
    return this.querySelector<HTMLInputElement>(TEXT_INPUT)
  }

  // The text field an event came from, or null: upstream's opening closest().
  #fieldFrom(target: EventTarget | null): HTMLInputElement | null {
    if (!(target instanceof Element)) return null

    const input = target.closest<HTMLInputElement>(TEXT_INPUT)
    return input && this.contains(input) ? input : null
  }

  #suggestionsId(): string | null {
    return this.#root()?.getAttribute(SUGGESTIONS_ID) || null
  }

  /* The popover root this tags input drives, by the id the Odin side minted --
   * and inside this element, which upstream's document.getElementById did not
   * require. */
  #suggestionsRoot(): Element | null {
    const id = this.#suggestionsId()
    if (!id) return null

    const root = this.ownerDocument.getElementById(id)
    return root?.matches(POPOVER_ROOT) && this.contains(root) ? root : null
  }

  #content(): HTMLElement | null {
    return this.#suggestionsRoot()?.querySelector<HTMLElement>(POPOVER_CONTENT) ?? null
  }

  // The tags already on the field, lowercased, from what the form would post.
  #selected(): string[] {
    return [
      ...this.querySelectorAll<HTMLInputElement>(`${HIDDEN_INPUTS} input`),
    ].map((input) => input.value.toLowerCase())
  }

  #visibleSuggestions(): HTMLElement[] {
    const popup = this.#content()
    if (!popup) return []

    return [...popup.querySelectorAll<HTMLElement>(SUGGESTION)].filter(
      (el) => el.style.display !== "none",
    )
  }
}

customElements.define(contract.element, OhTagsinput)
