/* Calendar, on the authoring model in README.md: one custom element wrapping the month
 * view ui/calendar/calendar.odin emits. The grid is this element's
 * to fill -- the server renders the header, the selects, and two empty grids,
 * because the day layout depends on the locale and the viewed month, and both
 * change without a round trip.
 *
 * The viewed month and year, and the hover end of a range preview, were
 * dataset entries on the container; they are fields now, per the checklist:
 * view state, initialised from the rendered initial-* attributes (or the
 * selected date, or the browser's clock), dying with the element. The
 * *selection* stays in the container's attributes: the server renders it,
 * this element updates it, and the tick styles read it -- it is the one piece
 * of state both sides must agree on, which is what the contract manifests.
 *
 * The captions are found by role attribute (data-oh-calendar-month-value/-
 * year-value) where calendar.js built `#${id}-month-value` selectors -- the
 * throwing-selector hazard its file comment warned about is gone with them.
 *
 * Listeners live on `this` (click, change, mouseover; mouseleave does not
 * bubble, so capture). reset fires on the form, outside this element:
 * document-level, removed on disconnect (the rating precedent).
 *
 * calendar.contract.json names everything this class reads from the markup;
 * calendar_test.odin renders the Odin side and asserts it is all there. The
 * day-cell attributes written below (data-oh-calendar-day and friends) are
 * this class's own output, matched by nothing server-side, so they stay out
 * of the manifest. */

import contract from "./calendar.contract.json"

const CONTAINER = contract.selectors.container
const WEEKDAYS = contract.selectors.weekdays
const DAYS = contract.selectors.days
const PREV = contract.selectors.prev
const NEXT = contract.selectors.next
const MONTH_SELECT = contract.selectors.monthSelect
const YEAR_SELECT = contract.selectors.yearSelect
const MONTH_VALUE = contract.selectors.monthValue
const YEAR_VALUE = contract.selectors.yearValue
const HIDDEN_INPUT = contract.selectors.hiddenInput
const HIDDEN_END_INPUT = contract.selectors.hiddenEndInput
const MODE = contract.attributes.mode
const LOCALE = contract.attributes.localeTag
const INITIAL_MONTH = contract.attributes.initialMonth
const INITIAL_YEAR = contract.attributes.initialYear
const SELECTED_DATE = contract.attributes.selectedDate
const END_DATE = contract.attributes.endDate
const START_OF_WEEK = contract.attributes.startOfWeek

// This class's own grid vocabulary -- written here, read here, not rendered.
const DAY = "data-oh-calendar-day"
const DAY_ISO = "data-oh-calendar-day-iso"

function parseISODate(iso: string | null): Date | null {
  if (!iso) return null

  const parts = iso.split("-")
  if (parts.length !== 3) return null

  const year = parseInt(parts[0], 10)
  const month = parseInt(parts[1], 10) - 1
  const day = parseInt(parts[2], 10)
  const date = new Date(Date.UTC(year, month, day))

  const valid =
    date.getUTCFullYear() === year && date.getUTCMonth() === month && date.getUTCDate() === day
  return valid ? date : null
}

function toISODate(date: Date | null): string {
  if (!date) return ""
  return date.toISOString().split("T")[0]
}

function monthNames(locale: string): string[] {
  try {
    return Array.from({ length: 12 }, (_, i) =>
      new Intl.DateTimeFormat(locale, { month: "short", timeZone: "UTC" }).format(
        new Date(Date.UTC(2000, i, 1)),
      ),
    )
  } catch {
    return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  }
}

function dayNames(locale: string, startOfWeek: number): string[] {
  try {
    return Array.from({ length: 7 }, (_, i) =>
      new Intl.DateTimeFormat(locale, { weekday: "short", timeZone: "UTC" }).format(
        new Date(Date.UTC(2000, 0, i + 2 + startOfWeek)),
      ),
    )
  } catch {
    return ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
  }
}

class OhCalendar extends HTMLElement {
  // The viewed month (0-11) and year -- view state, seeded in connectedCallback.
  #month = 0
  #year = 2000
  // The hovered end of a range being picked, as ISO, or null.
  #hoverEnd: string | null = null

  #onClick = (event: MouseEvent): void => {
    const target = event.target
    if (!(target instanceof Element) || !this.contains(target)) return

    if (target.closest(PREV)) {
      this.#shiftMonth(-1)
      return
    }
    if (target.closest(NEXT)) {
      this.#shiftMonth(1)
      return
    }

    if (target instanceof HTMLElement && target.matches(`[${DAY}]`)) {
      this.#pickDay(parseInt(target.getAttribute(DAY) ?? "", 10))
    }
  }

  #onChange = (event: Event): void => {
    const target = event.target
    if (!(target instanceof HTMLSelectElement)) return

    if (target.matches(MONTH_SELECT)) {
      const month = parseInt(target.value, 10)
      if (!isNaN(month)) {
        this.#month = month
        this.#render()
      }
      return
    }

    if (target.matches(YEAR_SELECT)) {
      const year = parseInt(target.value, 10)
      if (!isNaN(year)) {
        this.#year = year
        this.#render()
      }
    }
  }

  /* Range hover preview: while only the start is set, hovering a day shows
   * what the range would look like if completed there. */
  #onMouseover = (event: MouseEvent): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    const dayBtn = target.closest(`[${DAY}]`)
    if (!dayBtn || this.#mode() !== "range") return

    const { start, end } = this.#selection()
    if (!start || end) return

    const iso = dayBtn.getAttribute(DAY_ISO)
    if (iso === this.#hoverEnd) return

    this.#hoverEnd = iso
    this.#render()
  }

  // mouseleave does not bubble; capture on `this` reaches the container's.
  #onMouseleave = (event: Event): void => {
    const target = event.target
    if (!(target instanceof Element) || !target.matches(CONTAINER)) return
    if (this.#mode() !== "range" || this.#hoverEnd === null) return

    this.#hoverEnd = null
    this.#render()
  }

  /* reset fires on the form, which is outside this element -- document-level,
   * removed on disconnect. */
  #onReset = (event: Event): void => {
    if (!(event.target instanceof HTMLFormElement) || !event.target.contains(this)) return

    const container = this.#container()
    if (!container) return

    const hidden = this.querySelector<HTMLInputElement>(HIDDEN_INPUT)
    if (hidden) hidden.value = ""
    const hiddenEnd = this.querySelector<HTMLInputElement>(HIDDEN_END_INPUT)
    if (hiddenEnd) hiddenEnd.value = ""

    container.removeAttribute(SELECTED_DATE)
    container.removeAttribute(END_DATE)
    this.#hoverEnd = null

    const today = new Date()
    this.#month = today.getMonth()
    this.#year = today.getFullYear()
    this.#render()
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)
    this.addEventListener("change", this.#onChange)
    this.addEventListener("mouseover", this.#onMouseover)
    this.addEventListener("mouseleave", this.#onMouseleave, true)
    document.addEventListener("reset", this.#onReset)

    const container = this.#container()
    if (!container) return

    // The view: the selected date wins, then the initial attributes, then
    // the browser's clock -- month and year decided separately.
    const now = new Date()
    const selected = parseISODate(container.getAttribute(SELECTED_DATE))
    const initialMonth = parseInt(container.getAttribute(INITIAL_MONTH) ?? "", 10)
    const initialYear = parseInt(container.getAttribute(INITIAL_YEAR) ?? "", 10)
    this.#month = selected ? selected.getUTCMonth() : !isNaN(initialMonth) ? initialMonth : now.getMonth()
    this.#year = selected
      ? selected.getUTCFullYear()
      : !isNaN(initialYear) && initialYear > 0
        ? initialYear
        : now.getFullYear()

    // Localise the month options -- English until here, per the server.
    const names = monthNames(this.#locale())
    const monthSelect = this.querySelector(MONTH_SELECT)
    if (monthSelect) {
      monthSelect.querySelectorAll("option").forEach((option, index) => {
        if (names[index]) option.textContent = names[index]
      })
    }

    this.#render()
  }

  disconnectedCallback(): void {
    document.removeEventListener("reset", this.#onReset)
  }

  #shiftMonth(delta: number): void {
    let month = this.#month + delta
    if (month < 0) {
      month = 11
      this.#year--
    } else if (month > 11) {
      month = 0
      this.#year++
    }
    this.#month = month
    this.#render()
    this.#syncSelects()
  }

  /* State machine: a range needs two clicks. The second click completes it
   * (swapping if clicked before start). Any further click resets. */
  #pickDay(day: number): void {
    const clicked = new Date(Date.UTC(this.#year, this.#month, day))

    if (this.#mode() === "range") {
      const { start, end } = this.#selection()
      if (start && !end) {
        if (clicked.getTime() < start.getTime()) {
          this.#setSelection(clicked, start)
        } else {
          this.#setSelection(start, clicked)
        }
      } else {
        this.#setSelection(clicked, null)
      }
    } else {
      this.#setSelection(clicked, null)
    }
  }

  #setSelection(start: Date | null, end: Date | null): void {
    const container = this.#container()
    if (!container) return

    const startISO = toISODate(start)
    const endISO = toISODate(end)

    if (startISO) {
      container.setAttribute(SELECTED_DATE, startISO)
    } else {
      container.removeAttribute(SELECTED_DATE)
    }
    if (endISO) {
      container.setAttribute(END_DATE, endISO)
    } else {
      container.removeAttribute(END_DATE)
    }
    this.#hoverEnd = null

    // Absent when embedded (datepicker owns its own inputs and hears the
    // event instead).
    const hidden = this.querySelector<HTMLInputElement>(HIDDEN_INPUT)
    if (hidden) hidden.value = startISO
    const hiddenEnd = this.querySelector<HTMLInputElement>(HIDDEN_END_INPUT)
    if (hiddenEnd) hiddenEnd.value = endISO

    container.dispatchEvent(
      new CustomEvent("calendar-selected", {
        bubbles: true,
        detail: { mode: this.#mode(), start, end },
      }),
    )

    this.#render()
  }

  #render(): void {
    const container = this.#container()
    const weekdays = this.querySelector(WEEKDAYS)
    const days = this.querySelector(DAYS)
    if (!container || !weekdays || !days) return

    const locale = this.#locale()
    const startOfWeek = parseInt(container.getAttribute(START_OF_WEEK) ?? "", 10) || 1

    const mode = this.#mode()
    const { start, end } = this.#selection()

    // While picking the second date, preview the range against the hovered day.
    let visualStart = start
    let visualEnd = end ?? (mode === "range" && start ? parseISODate(this.#hoverEnd) : null)
    if (visualStart && visualEnd && visualEnd.getTime() < visualStart.getTime()) {
      ;[visualStart, visualEnd] = [visualEnd, visualStart]
    }

    const names = monthNames(locale)
    const monthValue = this.querySelector(MONTH_VALUE)
    if (monthValue) monthValue.textContent = names[this.#month]
    const yearValue = this.querySelector(YEAR_VALUE)
    if (yearValue) yearValue.textContent = String(this.#year)

    if (!weekdays.children.length) {
      weekdays.innerHTML = dayNames(locale, startOfWeek)
        .map((day) => `<div class="text-center text-xs text-muted-foreground font-medium">${day}</div>`)
        .join("")
    }

    const firstDay = new Date(Date.UTC(this.#year, this.#month, 1))
    const startOffset = (((firstDay.getUTCDay() - startOfWeek) % 7) + 7) % 7
    const daysInMonth = new Date(Date.UTC(this.#year, this.#month + 1, 0)).getUTCDate()

    const today = new Date()
    const todayUTC = new Date(Date.UTC(today.getFullYear(), today.getMonth(), today.getDate()))

    const cells: string[] = []
    for (let i = 0; i < startOffset; i++) {
      cells.push('<div class="h-(--cell-size) w-(--cell-size)"></div>')
    }

    for (let day = 1; day <= daysInMonth; day++) {
      const date = new Date(Date.UTC(this.#year, this.#month, day))
      const t = date.getTime()

      const isStart = visualStart !== null && t === visualStart.getTime()
      const isEnd = mode === "range" && visualEnd !== null && t === visualEnd.getTime()
      const isInRange =
        mode === "range" &&
        visualStart !== null &&
        visualEnd !== null &&
        t > visualStart.getTime() &&
        t < visualEnd.getTime()
      const isToday = t === todayUTC.getTime()

      let classes =
        "inline-flex h-[var(--cell-size)] w-[var(--cell-size)] items-center justify-center rounded-md text-sm font-medium focus:outline-none focus:ring-1 focus:ring-ring"

      if (isStart || isEnd) {
        classes += " bg-primary text-primary-foreground hover:bg-primary/90"
      } else if (isInRange) {
        classes += " bg-primary/20 text-foreground hover:bg-primary/30"
      } else if (isToday) {
        classes += " bg-accent text-accent-foreground"
      } else {
        classes += " hover:bg-accent hover:text-accent-foreground"
      }

      const attrs = [
        `${DAY}="${day}"`,
        `${DAY_ISO}="${toISODate(date)}"`,
        isToday ? 'data-oh-calendar-today="true"' : "",
        isStart ? 'data-oh-calendar-range-start="true"' : "",
        isEnd && !isStart ? 'data-oh-calendar-range-end-day="true"' : "",
        isInRange ? 'data-oh-calendar-in-range="true"' : "",
      ]
        .filter(Boolean)
        .join(" ")

      cells.push(`<button type="button" class="${classes}" ${attrs}>${day}</button>`)
    }

    days.innerHTML = cells.join("")
  }

  #syncSelects(): void {
    const monthSelect = this.querySelector<HTMLSelectElement>(MONTH_SELECT)
    if (monthSelect) monthSelect.value = String(this.#month)
    const yearSelect = this.querySelector<HTMLSelectElement>(YEAR_SELECT)
    if (yearSelect) yearSelect.value = String(this.#year)
  }

  /* Scoped to the wrapper's own container: a datepicker's calendar is a
   * oh-calendar of its own, so `this` is always the right boundary. */
  #container(): Element | null {
    return this.querySelector(CONTAINER)
  }

  #mode(): string {
    return this.#container()?.getAttribute(MODE) === "range" ? "range" : "single"
  }

  #locale(): string {
    return this.#container()?.getAttribute(LOCALE) ?? "en-US"
  }

  #selection(): { start: Date | null; end: Date | null } {
    const container = this.#container()
    return {
      start: parseISODate(container?.getAttribute(SELECTED_DATE) ?? null),
      end: parseISODate(container?.getAttribute(END_DATE) ?? null),
    }
  }
}

customElements.define(contract.element, OhCalendar)
