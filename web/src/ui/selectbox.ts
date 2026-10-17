/* Select box, on the authoring model in README.md: one custom element wrapping the
 * markup ui/selectbox/selectbox.odin emits -- a button dressed as an
 * input over a popover of rows. The widget logic (selection, the mirrored
 * caption, pills, the fuzzy search, keyboard navigation, clear) is
 * upstream's, moved from document delegation onto `this`.
 *
 * What moving onto the platform deleted rather than moved: opening and dismissal (the
 * popover is auto -- popover.ts toggles, the browser dismisses), the
 * measured-width sync (the content is w-[anchor-size(width)] now), the
 * init-marker scan and both re-init hooks (upgrade is the platform's), and
 * the old class hooks (.select-container and friends), which became
 * data-oh-selectbox-* roles.
 *
 * The one scoped survivor of the old dismissal machinery is
 * Escape-to-search-first: with text in the search box, the first Escape
 * belongs to the field, so the keydown is preventDefault()ed -- which was
 * measured to cancel the native close -- and only an
 * Escape on an empty field falls through to the browser. Escape on a focused
 * row returns to the search box the same way. That is all that is left of
 * disable_esc: about four lines.
 *
 * The clear control keeps upstream's two-phase suppression: pointerdown in
 * capture clears the value and stops the press reaching popover.ts's toggle;
 * the marker attribute then swallows the click that follows.
 *
 * reset fires on the form, outside this element: document-level listener,
 * removed on disconnect (the rating precedent). Everything else lives on
 * `this` and dies with the node.
 *
 * selectbox.contract.json names everything this class reads from the markup;
 * selectbox_test.odin renders the Odin side and asserts it is all there. */

import contract from "./selectbox.contract.json"
import { enableValueBinding } from "./value-binding.ts"

const TRIGGER = contract.selectors.trigger
const HIDDEN_INPUT = contract.selectors.hiddenInput
const DISPLAY = contract.selectors.display
const CONTENT = contract.selectors.content
const ITEM = contract.selectors.item
const ITEM_TEXT = contract.selectors.itemText
const SEARCH = contract.selectors.search
const CLEAR = contract.selectors.clear
const CHEVRON = contract.selectors.chevron
const MULTIPLE = contract.attributes.multiple
const SHOW_PILLS = contract.attributes.showPills
const COUNT_TEXT = contract.attributes.countText
const VALUE = contract.attributes.value
const SELECTED = contract.attributes.selected
const DISABLED = contract.attributes.disabled
const PLACEHOLDER = contract.attributes.placeholder

// The clear press marks the trigger so the click that follows is swallowed.
const SUPPRESS_CLICK = "data-oh-selectbox-suppress-click"

function normalize(value: string | null | undefined): string {
  return (value ?? "").toLowerCase().trim().replace(/\s+/g, " ")
}

function fuzzyMatch(searchTerm: string, candidate: string): boolean {
  const needle = normalize(searchTerm).replace(/\s+/g, "")
  const haystack = normalize(candidate).replace(/\s+/g, "")

  if (!needle) return true
  if (!haystack) return false
  if (haystack.includes(needle)) return true

  let i = 0
  for (const ch of haystack) {
    if (ch === needle[i]) i++
    if (i === needle.length) break
  }
  return i === needle.length
}

class OhSelectbox extends HTMLElement {
  /* Clear, before anything else can act on the press: capture phase, so
   * neither popover.ts's toggle nor the trigger button hears it. */
  #onPointerdownCapture = (event: Event): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    const clear = target.closest(CLEAR)
    if (!clear || !this.contains(clear)) return

    event.preventDefault()
    event.stopPropagation()

    const trigger = this.#trigger()
    if (trigger) {
      // The clear icon may disappear before click fires; swallow that click.
      trigger.setAttribute(SUPPRESS_CLICK, "true")
      this.#clear()
    }
  }

  // The follow-up click after a clear press, swallowed in capture.
  #onClickCapture = (event: Event): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    if (target.closest(CLEAR) && this.contains(target)) {
      event.preventDefault()
      event.stopPropagation()
      return
    }

    const trigger = target.closest(TRIGGER)
    if (trigger && this.contains(trigger) && trigger.getAttribute(SUPPRESS_CLICK) === "true") {
      trigger.removeAttribute(SUPPRESS_CLICK)
      event.preventDefault()
      event.stopPropagation()
    }
  }

  #onClick = (event: MouseEvent): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    // Pill remove buttons live in the caption the class itself built.
    if (target.matches("[data-oh-selectbox-pill-remove]")) {
      event.stopPropagation()
      const item = this.#items().find(
        (el) => el.getAttribute(VALUE) === target.getAttribute(VALUE),
      )
      if (item) this.#toggleItem(item)
      return
    }

    const item = target.closest<HTMLElement>(ITEM)
    if (item && this.contains(item)) {
      event.preventDefault()
      this.#toggleItem(item)
    }
  }

  /* The popover opened (popover.ts's toggle, or the typeahead below): focus
   * the search box, or the first row. toggle does not bubble; capture does. */
  #onToggle = (event: Event): void => {
    if ((event as ToggleEvent).newState !== "open") return
    if (!(event.target instanceof Element) || !event.target.matches(CONTENT)) return

    const search = this.#search()
    if (search) {
      search.focus()
    } else {
      this.#items()[0]?.focus()
    }
  }

  #onInput = (event: Event): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    if (target.matches(SEARCH)) {
      this.#filterItems()
      return
    }

    // Programmatic writes to the hidden input, heard via the value binding.
    if (target.matches(HIDDEN_INPUT)) {
      this.#syncSelectionsFromValue()
      this.#updateDisplay()
    }
  }

  #onKeydown = (event: KeyboardEvent): void => {
    const active = this.ownerDocument.activeElement

    // Typing on the trigger opens the list and lands in the search box.
    if (active instanceof HTMLElement && active.matches(TRIGGER) && this.contains(active)) {
      if (event.key.length === 1 || event.key === "Backspace") {
        event.preventDefault()
        const content = this.#content()
        if (content && !content.matches(":popover-open")) content.showPopover()

        const search = this.#search()
        if (search) {
          search.focus()
          if (event.key !== "Backspace") search.value = event.key
          this.#filterItems()
        }
      }
      return
    }

    if (!(active instanceof HTMLElement) || !this.contains(active)) return
    const content = this.#content()
    if (!content || !content.contains(active)) return

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const visible = this.#visibleItems()
      if (!visible.length) return

      const current = active.matches(ITEM) ? visible.indexOf(active) : -1
      const next =
        event.key === "ArrowDown"
          ? (current + 1) % visible.length
          : (current - 1 + visible.length) % visible.length
      visible[next].focus()
      return
    }

    if (event.key === "Enter" && active.matches(ITEM)) {
      event.preventDefault()
      this.#toggleItem(active)
      return
    }

    if (event.key === "Escape") {
      const search = this.#search()
      if (active.matches(ITEM) && search) {
        // Back to the search box -- and not out of the popover.
        event.preventDefault()
        search.focus()
        return
      }

      if (search && active === search && search.value !== "") {
        /* The scoped survivor: the first Escape clears the field, and the
         * preventDefault cancels the native close (measured). An
         * empty field falls through and the browser closes one level. */
        event.preventDefault()
        search.value = ""
        this.#filterItems()
      }
    }
  }

  /* reset fires on the form, which is outside this element -- document-level,
   * removed on disconnect. */
  #onReset = (event: Event): void => {
    if (!(event.target instanceof HTMLFormElement) || !event.target.contains(this)) return

    for (const item of this.#items()) {
      item.setAttribute(SELECTED, "false")
    }

    const search = this.#search()
    if (search) {
      search.value = ""
      this.#filterItems()
    }

    this.#updateDisplay()
  }

  connectedCallback(): void {
    this.addEventListener("pointerdown", this.#onPointerdownCapture, true)
    this.addEventListener("click", this.#onClickCapture, true)
    this.addEventListener("click", this.#onClick)
    this.addEventListener("toggle", this.#onToggle, true)
    this.addEventListener("input", this.#onInput)
    this.addEventListener("keydown", this.#onKeydown)
    document.addEventListener("reset", this.#onReset)

    const hidden = this.#hiddenInput()
    if (hidden) enableValueBinding(hidden)
    this.#updateDisplay()
  }

  disconnectedCallback(): void {
    document.removeEventListener("reset", this.#onReset)
  }

  #toggleItem(item: HTMLElement): void {
    if (item.getAttribute(DISABLED) === "true") return

    const multiple = this.#isMultiple()
    const wasSelected = item.getAttribute(SELECTED) === "true"

    if (!multiple) {
      for (const el of this.#items()) {
        el.setAttribute(SELECTED, "false")
      }
    }
    item.setAttribute(SELECTED, String(!wasSelected))

    this.#updateDisplay()

    const hidden = this.#hiddenInput()
    hidden?.dispatchEvent(new Event("change", { bubbles: true }))

    if (!multiple) {
      const content = this.#content()
      if (content?.matches(":popover-open")) content.hidePopover()
      this.#trigger()?.focus()
    }
  }

  #syncSelectionsFromValue(): void {
    const hidden = this.#hiddenInput()
    if (!hidden) return

    const values = hidden.value
      ? this.#isMultiple()
        ? hidden.value.split(",")
        : [hidden.value]
      : []

    for (const item of this.#items()) {
      const should = values.includes(item.getAttribute(VALUE) ?? "")
      if (should !== (item.getAttribute(SELECTED) === "true")) {
        item.setAttribute(SELECTED, String(should))
      }
    }
  }

  #updateDisplay(): void {
    const display = this.querySelector<HTMLElement>(DISPLAY)
    const hidden = this.#hiddenInput()
    this.#updateClearState()
    if (!display) return

    const selected = this.#items().filter((el) => el.getAttribute(SELECTED) === "true")

    if (selected.length === 0) {
      display.textContent = display.getAttribute(PLACEHOLDER) ?? "Select..."
      display.classList.add("text-muted-foreground")
      if (hidden) hidden.value = ""
      this.#updateClearState()
      return
    }

    display.classList.remove("text-muted-foreground")

    if (this.#isMultiple()) {
      if (this.#trigger()?.getAttribute(SHOW_PILLS) === "true") {
        this.#renderPills(display, selected)
      } else {
        display.textContent = this.#countText(selected.length)
      }
      if (hidden) {
        hidden.value = selected.map((el) => el.getAttribute(VALUE) ?? "").join(",")
      }
    } else {
      display.textContent = selected[0].querySelector(ITEM_TEXT)?.textContent ?? ""
      if (hidden) hidden.value = selected[0].getAttribute(VALUE) ?? ""
    }

    this.#updateClearState()
  }

  #renderPills(display: HTMLElement, selected: HTMLElement[]): void {
    display.textContent = ""
    const container = this.ownerDocument.createElement("div")
    container.className = "flex flex-wrap gap-1 items-center min-h-[1.5rem]"

    for (const item of selected) {
      const pill = this.ownerDocument.createElement("span")
      pill.className =
        "inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded-md bg-primary text-primary-foreground"

      const text = this.ownerDocument.createElement("span")
      text.textContent = item.querySelector(ITEM_TEXT)?.textContent ?? ""
      pill.appendChild(text)

      const remove = this.ownerDocument.createElement("button")
      remove.className = "ml-0.5 hover:text-destructive focus:outline-none"
      remove.type = "button"
      remove.textContent = "×"
      remove.setAttribute("data-oh-selectbox-pill-remove", "")
      remove.setAttribute(VALUE, item.getAttribute(VALUE) ?? "")
      pill.appendChild(remove)

      container.appendChild(pill)
    }
    display.appendChild(container)

    // If the pills overflow and there are more than three, fall back to the
    // count -- measured after they render.
    requestAnimationFrame(() => {
      if (container.scrollWidth > display.offsetWidth - 10 && selected.length > 3) {
        display.textContent = this.#countText(selected.length)
      }
    })
  }

  #countText(count: number): string {
    const template = this.#trigger()?.getAttribute(COUNT_TEXT) || "{n} items selected"
    return template.replace("{n}", String(count))
  }

  #updateClearState(): void {
    const clear = this.querySelector<HTMLElement>(CLEAR)
    if (!clear) return

    const trigger = this.#trigger()
    const hasSelection = !!this.#hiddenInput()?.value && !trigger?.disabled

    clear.classList.toggle("hidden", !hasSelection)
    this.querySelector(CHEVRON)?.classList.toggle("hidden", hasSelection)
  }

  #clear(): void {
    const hidden = this.#hiddenInput()
    if (!hidden?.value) return

    hidden.value = ""
    hidden.dispatchEvent(new Event("input", { bubbles: true }))
    hidden.dispatchEvent(new Event("change", { bubbles: true }))
  }

  #filterItems(): void {
    const term = normalize(this.#search()?.value)

    for (const item of this.#items()) {
      const text = normalize(item.querySelector(ITEM_TEXT)?.textContent)
      const value = normalize(item.getAttribute(VALUE))
      const visible = !term || fuzzyMatch(term, text) || fuzzyMatch(term, value)
      item.style.display = visible ? "" : "none"
    }
  }

  #isMultiple(): boolean {
    return this.#trigger()?.getAttribute(MULTIPLE) === "true"
  }

  #trigger(): HTMLButtonElement | null {
    return this.querySelector<HTMLButtonElement>(TRIGGER)
  }

  #hiddenInput(): HTMLInputElement | null {
    return this.querySelector<HTMLInputElement>(HIDDEN_INPUT)
  }

  #content(): HTMLElement | null {
    return this.querySelector<HTMLElement>(CONTENT)
  }

  #search(): HTMLInputElement | null {
    return this.querySelector<HTMLInputElement>(SEARCH)
  }

  #items(): HTMLElement[] {
    return [...this.querySelectorAll<HTMLElement>(ITEM)]
  }

  #visibleItems(): HTMLElement[] {
    return this.#items().filter((el) => el.style.display !== "none")
  }
}

customElements.define(contract.element, OhSelectbox)
