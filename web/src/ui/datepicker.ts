/* Date picker, on the authoring model in README.md: one custom element wrapping the
 * composition ui/datepicker/datepicker.odin emits. The calendar
 * inside owns the grid and fires calendar-selected; this element owns the
 * hidden inputs and the formatted caption, and closes the popover when a
 * selection completes.
 *
 * The close is the platform's call on the platform's element:
 * content.hidePopover() on the [popover] inside this element -- which is what
 * retired window.tui.popover.closeNearest, this component having been its
 * only caller.
 *
 * What moved from datepicker.js: three document listeners
 * (calendar-selected, input, reset) onto `this` -- except reset, which fires
 * on the form and never reaches a listener inside it, so it stays
 * document-level and is removed in disconnectedCallback (the rating
 * precedent). The DOMContentLoaded/htmx re-init pair deleted; upgrade is the
 * platform's.
 *
 * datepicker.contract.json names everything this class reads from the markup;
 * datepicker_test.odin renders the Odin side and asserts it is all there. */

import contract from "./datepicker.contract.json"
import { enableValueBinding } from "./value-binding.ts"

const TRIGGER = contract.selectors.trigger
const DISPLAY = contract.selectors.display
const START_INPUT = contract.selectors.hiddenInput
const END_INPUT = contract.selectors.hiddenEndInput
const POPOVER_CONTENT = contract.selectors.popoverContent
const FORMAT = contract.attributes.displayFormat
const LOCALE = contract.attributes.localeTag
const PLACEHOLDER = contract.attributes.placeholder
const MODE = contract.attributes.mode
const END_PLACEHOLDER = contract.attributes.endPlaceholder

function parseISODate(iso: string | null): Date | null {
  if (!iso) return null

  const parts = iso.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (!parts) return null

  const year = parseInt(parts[1], 10)
  const month = parseInt(parts[2], 10) - 1
  const day = parseInt(parts[3], 10)
  const date = new Date(Date.UTC(year, month, day))

  const valid =
    date.getUTCFullYear() === year && date.getUTCMonth() === month && date.getUTCDate() === day
  return valid ? date : null
}

function toISODate(date: Date | null | undefined): string {
  if (!date || isNaN(date.getTime())) return ""
  return date.toISOString().split("T")[0]
}

const FORMAT_STYLES: Record<string, "short" | "long" | "full" | "medium"> = {
  "locale-short": "short",
  "locale-long": "long",
  "locale-full": "full",
  "locale-medium": "medium",
}

function formatDate(date: Date, format: string, locale: string): string {
  if (isNaN(date.getTime())) return ""

  try {
    return new Intl.DateTimeFormat(locale, {
      timeZone: "UTC",
      dateStyle: FORMAT_STYLES[format] ?? "medium",
    }).format(date)
  } catch {
    return toISODate(date)
  }
}

class OhDatepicker extends HTMLElement {
  /* Calendar fires this for both single and range modes; this element owns
   * the hidden inputs and writes them here. */
  #onCalendarSelected = (event: Event): void => {
    const detail = (event as CustomEvent<{ mode?: string; start?: Date; end?: Date }>).detail ?? {}
    const start = this.#startInput()
    if (!start) return

    start.value = toISODate(detail.start)
    const end = this.#endInput()
    if (end) end.value = toISODate(detail.end)

    this.#updateDisplay()

    // Close on completion: always for single, only with both ends for range.
    if (detail.mode === "single" || (detail.mode === "range" && detail.end)) {
      this.#content()?.hidePopover()
    }
  }

  // Programmatic writes to the hidden inputs, heard via the value binding.
  #onInput = (event: Event): void => {
    const target = event.target
    if (!(target instanceof Element)) return
    if (target.matches(START_INPUT) || target.matches(END_INPUT)) {
      this.#updateDisplay()
    }
  }

  /* reset fires on the form, which is outside this element -- document-level,
   * removed on disconnect. */
  #onReset = (event: Event): void => {
    if (!(event.target instanceof HTMLFormElement) || !event.target.contains(this)) return

    const start = this.#startInput()
    if (start) start.value = ""
    const end = this.#endInput()
    if (end) end.value = ""
    this.#updateDisplay()
  }

  connectedCallback(): void {
    this.addEventListener("calendar-selected", this.#onCalendarSelected)
    this.addEventListener("input", this.#onInput)
    document.addEventListener("reset", this.#onReset)

    const start = this.#startInput()
    if (start) {
      enableValueBinding(start)
      const end = this.#endInput()
      if (end) enableValueBinding(end)
      this.#updateDisplay()
    }
  }

  disconnectedCallback(): void {
    document.removeEventListener("reset", this.#onReset)
  }

  #updateDisplay(): void {
    const trigger = this.querySelector(TRIGGER)
    const display = this.querySelector(DISPLAY)
    const startInput = this.#startInput()
    if (!trigger || !display || !startInput) return

    const format = trigger.getAttribute(FORMAT) ?? "locale-medium"
    const locale = trigger.getAttribute(LOCALE) ?? "en-US"
    const placeholder = trigger.getAttribute(PLACEHOLDER) ?? "Select a date"

    const start = parseISODate(startInput.value)
    const startText = start ? formatDate(start, format, locale) : placeholder

    if (trigger.getAttribute(MODE) === "range") {
      const endPlaceholder = trigger.getAttribute(END_PLACEHOLDER) || "End date"
      const endValue = this.#endInput()?.value ?? ""
      const end = parseISODate(endValue)
      const endText = end ? formatDate(end, format, locale) : endPlaceholder
      display.textContent = `${startText} – ${endText}`
    } else {
      display.textContent = startText
    }

    display.classList.toggle("text-muted-foreground", start === null)
  }

  #startInput(): HTMLInputElement | null {
    return this.querySelector<HTMLInputElement>(START_INPUT)
  }

  #endInput(): HTMLInputElement | null {
    return this.querySelector<HTMLInputElement>(END_INPUT)
  }

  #content(): HTMLElement | null {
    return this.querySelector<HTMLElement>(POPOVER_CONTENT)
  }
}

customElements.define(contract.element, OhDatepicker)
