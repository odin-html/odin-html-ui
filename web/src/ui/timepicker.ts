/* Time picker, on the authoring model in README.md: one custom element wrapping the
 * composition ui/timepicker/timepicker.odin emits. The widget logic
 * -- hour/minute/period selection, validity against min/max, the formatted
 * caption -- is upstream's, moved from document delegation onto `this`.
 *
 * The chosen hour and minute were dataset entries on the trigger
 * (data-tui-timepicker-current-*); they are fields now, per the checklist:
 * view state, initialised from the hidden input, dying with the element (the
 * rating precedent -- its committed value made the same move).
 *
 * Scroll-to-selected-on-open was a MutationObserver on the whole body,
 * watching for popover.js to write its open attribute. That attribute is
 * gone; the platform announces opening with a `toggle` event on the content,
 * which does not bubble -- but capture on `this` reaches it, so the observer
 * is deleted and nothing needs teardown for it. The Done button closes
 * through the content's own hidePopover(), the platform's call.
 *
 * reset fires on the form, outside this element: document-level listener,
 * removed on disconnect (the rating precedent).
 *
 * timepicker.contract.json names everything this class reads from the markup;
 * timepicker_test.odin renders the Odin side and asserts it is all there. */

import contract from "./timepicker.contract.json"
import { enableValueBinding } from "./value-binding.ts"

const TRIGGER = contract.selectors.trigger
const DISPLAY = contract.selectors.display
const HIDDEN_INPUT = contract.selectors.hiddenInput
const POPUP = contract.selectors.popup
const HOUR_LIST = contract.selectors.hourList
const MINUTE_LIST = contract.selectors.minuteList
const DONE = contract.selectors.done
const POPOVER_CONTENT = contract.selectors.popoverContent
const USE_12_HOURS = contract.attributes.use12Hours
const STEP = contract.attributes.step
const MIN_TIME = contract.attributes.minTime
const MAX_TIME = contract.attributes.maxTime
const PLACEHOLDER = contract.attributes.placeholder
const HOUR = contract.attributes.hour
const MINUTE = contract.attributes.minute
const PERIOD = contract.attributes.period
const SELECTED = contract.attributes.selected
const ACTIVE = contract.attributes.active

interface Hm {
  hour: number
  minute: number
}

function parseTime(text: string | null): Hm | null {
  const match = text?.match(/^(\d{1,2}):(\d{2})$/)
  if (!match) return null

  const hour = Number(match[1])
  const minute = Number(match[2])
  return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 ? { hour, minute } : null
}

function formatTime(hour: number, minute: number, use12Hours: boolean): string {
  const pad = (n: number) => n.toString().padStart(2, "0")

  if (use12Hours) {
    const h = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour
    return `${pad(h)}:${pad(minute)} ${hour >= 12 ? "PM" : "AM"}`
  }
  return `${pad(hour)}:${pad(minute)}`
}

function isValidTime(hour: number, minute: number, min: Hm | null, max: Hm | null): boolean {
  const t = hour * 60 + minute
  if (min && t < min.hour * 60 + min.minute) return false
  if (max && t > max.hour * 60 + max.minute) return false
  return true
}

class OhTimepicker extends HTMLElement {
  // The chosen time -- view state, null meaning unset.
  #hour: number | null = null
  #minute: number | null = null

  #onClick = (event: MouseEvent): void => {
    const target = event.target
    if (!(target instanceof HTMLElement) || !this.contains(target)) return

    if (target.matches(`[${HOUR}]`) && !(target as HTMLButtonElement).disabled) {
      this.#pickHour(Number(target.getAttribute(HOUR)))
      return
    }

    if (target.matches(`[${MINUTE}]`) && !(target as HTMLButtonElement).disabled) {
      const minute = Number(target.getAttribute(MINUTE))
      if (this.#hour === null || isValidTime(this.#hour, minute, this.#min(), this.#max())) {
        this.#setState(this.#hour, minute)
      }
      return
    }

    if (target.matches(`[${PERIOD}]`)) {
      this.#pickPeriod(target.getAttribute(PERIOD) ?? "")
      return
    }

    if (target.closest(DONE)) {
      const content = target.closest<HTMLElement>(POPOVER_CONTENT)
      if (content?.matches(":popover-open")) content.hidePopover()
    }
  }

  // Programmatic writes to the hidden input, heard via the value binding.
  #onInput = (event: Event): void => {
    const target = event.target
    if (!(target instanceof HTMLInputElement) || !target.matches(HIDDEN_INPUT)) return

    const parsed = parseTime(target.value)
    if (parsed) {
      this.#setState(parsed.hour, parsed.minute)
    } else {
      this.#setState(null, null)
    }
  }

  /* The platform's announcement that the popover opened -- toggle does not
   * bubble, but capture reaches it. Scroll the chosen entries into view. */
  #onToggle = (event: Event): void => {
    if ((event as ToggleEvent).newState !== "open") return
    if (!(event.target instanceof Element) || !event.target.matches(POPOVER_CONTENT)) return

    requestAnimationFrame(() => {
      this.querySelector(`${HOUR_LIST} [${SELECTED}="true"]`)?.scrollIntoView({ block: "center" })
      this.querySelector(`${MINUTE_LIST} [${SELECTED}="true"]`)?.scrollIntoView({ block: "center" })
    })
  }

  /* reset fires on the form, which is outside this element -- document-level,
   * removed on disconnect. */
  #onReset = (event: Event): void => {
    if (!(event.target instanceof HTMLFormElement) || !event.target.contains(this)) return

    this.#setState(null, null)
    const input = this.#hiddenInput()
    if (input) input.value = ""
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)
    this.addEventListener("input", this.#onInput)
    this.addEventListener("toggle", this.#onToggle, true)
    document.addEventListener("reset", this.#onReset)

    const input = this.#hiddenInput()
    if (input) {
      const parsed = parseTime(input.value)
      if (parsed) {
        this.#hour = parsed.hour
        this.#minute = parsed.minute
      }
      enableValueBinding(input)
    }
    this.#updateDisplay()
  }

  disconnectedCallback(): void {
    document.removeEventListener("reset", this.#onReset)
  }

  #pickHour(listHour: number): void {
    let hour = listHour
    if (this.#use12Hours()) {
      const isPM = this.#hour !== null && this.#hour >= 12
      hour = hour === 0 ? (isPM ? 12 : 0) : isPM ? hour + 12 : hour
    }

    if (this.#minute !== null && !isValidTime(hour, this.#minute, this.#min(), this.#max())) {
      this.#setState(hour, this.#firstValidMinute(hour))
    } else {
      this.#setState(hour, this.#minute)
    }
  }

  #pickPeriod(period: string): void {
    if (this.#hour === null) return

    let hour = this.#hour
    if (period === "AM" && this.#hour >= 12) {
      hour = this.#hour === 12 ? 0 : this.#hour - 12
    } else if (period === "PM" && this.#hour < 12) {
      hour = this.#hour === 0 ? 12 : this.#hour + 12
    }
    if (hour === this.#hour) return

    if (this.#minute !== null && !isValidTime(hour, this.#minute, this.#min(), this.#max())) {
      this.#setState(hour, this.#firstValidMinute(hour))
    } else {
      this.#setState(hour, this.#minute)
    }
  }

  #firstValidMinute(hour: number): number | null {
    const step = this.#step()
    for (let m = 0; m < 60; m += step) {
      if (isValidTime(hour, m, this.#min(), this.#max())) return m
    }
    return null
  }

  #setState(hour: number | null, minute: number | null): void {
    this.#hour = hour
    this.#minute = minute
    this.#updateDisplay()
  }

  #updateDisplay(): void {
    const use12 = this.#use12Hours()

    const display = this.querySelector(DISPLAY)
    if (display) {
      const formatted =
        this.#hour !== null && this.#minute !== null
          ? formatTime(this.#hour, this.#minute, use12)
          : null
      display.textContent =
        formatted ?? this.#trigger()?.getAttribute(PLACEHOLDER) ?? "Select time"
      display.classList.toggle("text-muted-foreground", !formatted)
    }

    const input = this.#hiddenInput()
    if (input) {
      input.value =
        this.#hour !== null && this.#minute !== null
          ? formatTime(this.#hour, this.#minute, false)
          : ""
    }

    this.#updateSelections()
  }

  #updateSelections(): void {
    const popup = this.querySelector(POPUP)
    if (!popup) return

    const min = this.#min()
    const max = this.#max()
    const use12 = this.#use12Hours()

    for (const btn of popup.querySelectorAll<HTMLButtonElement>(`${HOUR_LIST} [${HOUR}]`)) {
      const hour = Number(btn.getAttribute(HOUR))
      let selected = false
      if (this.#hour !== null) {
        selected = use12
          ? hour === this.#hour ||
            (hour === 0 && this.#hour === 12) ||
            (hour === this.#hour - 12 && this.#hour > 12)
          : hour === this.#hour
      }
      btn.setAttribute(SELECTED, String(selected))

      let valid = false
      for (let m = 0; m < 60; m++) {
        if (isValidTime(hour, m, min, max)) {
          valid = true
          break
        }
      }
      btn.disabled = !valid
      btn.classList.toggle("opacity-50", !valid)
      btn.classList.toggle("cursor-not-allowed", !valid)
    }

    for (const btn of popup.querySelectorAll<HTMLButtonElement>(`${MINUTE_LIST} [${MINUTE}]`)) {
      const minute = Number(btn.getAttribute(MINUTE))
      const valid = this.#hour === null || isValidTime(this.#hour, minute, min, max)
      btn.setAttribute(SELECTED, String(minute === this.#minute))
      btn.disabled = !valid
      btn.classList.toggle("opacity-50", !valid)
      btn.classList.toggle("cursor-not-allowed", !valid)
    }

    const am = popup.querySelector(`[${PERIOD}="AM"]`)
    const pm = popup.querySelector(`[${PERIOD}="PM"]`)
    if (am && pm) {
      const isAM = this.#hour === null || this.#hour < 12
      am.setAttribute(ACTIVE, String(isAM))
      pm.setAttribute(ACTIVE, String(!isAM))
    }
  }

  #trigger(): Element | null {
    return this.querySelector(TRIGGER)
  }

  #hiddenInput(): HTMLInputElement | null {
    return this.querySelector<HTMLInputElement>(HIDDEN_INPUT)
  }

  #use12Hours(): boolean {
    return this.#trigger()?.getAttribute(USE_12_HOURS) === "true"
  }

  #step(): number {
    const step = Number(this.#trigger()?.getAttribute(STEP) ?? "1")
    return step > 0 ? step : 1
  }

  #min(): Hm | null {
    return parseTime(this.#trigger()?.getAttribute(MIN_TIME) ?? null)
  }

  #max(): Hm | null {
    return parseTime(this.#trigger()?.getAttribute(MAX_TIME) ?? null)
  }
}

customElements.define(contract.element, OhTimepicker)
