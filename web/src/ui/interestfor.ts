/* The interest-invoker shim (README.md, "Popovers, and hover"): tooltip, hovercard
 * and dropdown submenus emit the standard vocabulary -- interestfor naming a
 * popover by id, interest-delay-start/-end as inline style on the invoker --
 * and this module emulates exactly that where the browser does not.
 *
 * What "self-retires" means here, precisely (and the one place the shim does
 * more than fill a gap): native interest invokers are
 * buttons and links. Dropdown's submenu trigger is a component-owned button,
 * so it runs native in Chromium 142+ and this module skips it there. Tooltip
 * and hovercard put the attribute on popover's wrapper span, because the
 * button underneath is the caller's and the component cannot reach into it --
 * and a span is not a native invoker in any browser, so those two are driven
 * from here even where support exists. If the spec grows span invokers, the
 * skip below is the only line that changes.
 *
 * Delays are parsed from the style attribute's text, not from the CSSOM: a
 * browser without the feature drops the unknown properties from computed
 * style, but the attribute string survives. The property names are emitted by
 * popover.odin's interest_delays -- one place per side.
 *
 * One module-level coordinator, installed at import and never uninstalled --
 * the checklist's sanctioned shape for document-wide concerns, and the timers
 * are per-invoker in a WeakMap so nothing outlives what it belongs to.
 * Explicitly not claimed, as the README records: touch long-press and the
 * spec's full a11y affordances. The current hover popovers lack them too.
 *
 * Behaviour: interest gained on the invoker (mouse enter, or keyboard focus)
 * shows the target after interest-delay-start; interest lost hides it after
 * interest-delay-end; moving onto the shown target holds interest, exactly as
 * the native feature and the old hover machinery both do. */

const native = "interestForElement" in HTMLButtonElement.prototype

/* Elements the browser will drive itself -- skip them or the popover would be
 * toggled twice. */
function nativelyHandled(invoker: Element): boolean {
  return (
    native &&
    (invoker instanceof HTMLButtonElement ||
      invoker instanceof HTMLAnchorElement ||
      invoker instanceof HTMLAreaElement)
  )
}

interface Timers {
  show?: ReturnType<typeof setTimeout>
  hide?: ReturnType<typeof setTimeout>
}

const timers = new WeakMap<Element, Timers>()
// The invoker behind each currently shown target, so hovering the target
// holds interest.
const shownBy = new WeakMap<Element, Element>()

function delay(invoker: Element, property: string): number {
  const style = invoker.getAttribute("style") ?? ""
  const match = style.match(new RegExp(`${property}:\\s*([\\d.]+)ms`))
  return match ? parseFloat(match[1]) : 0
}

function target(invoker: Element): HTMLElement | null {
  const id = invoker.getAttribute("interestfor")
  return id ? invoker.ownerDocument.getElementById(id) : null
}

function gain(invoker: Element): void {
  const t = timers.get(invoker) ?? {}
  clearTimeout(t.hide)
  clearTimeout(t.show)
  t.show = setTimeout(() => {
    timers.delete(invoker)
    const el = target(invoker)
    if (el?.isConnected && !el.matches(":popover-open")) {
      try {
        el.showPopover()
        shownBy.set(el, invoker)
      } catch {
        // not a popover, or in a state that refuses; nothing to do
      }
    }
  }, delay(invoker, "interest-delay-start"))
  timers.set(invoker, t)
}

function lose(invoker: Element): void {
  const t = timers.get(invoker) ?? {}
  clearTimeout(t.show)
  clearTimeout(t.hide)
  t.hide = setTimeout(() => {
    timers.delete(invoker)
    const el = target(invoker)
    if (el?.isConnected && el.matches(":popover-open")) {
      try {
        el.hidePopover()
      } catch {
        // already closed by other means
      }
    }
  }, delay(invoker, "interest-delay-end"))
  timers.set(invoker, t)
}

/* The invoker an event belongs to: the [interestfor] ancestor of the event's
 * target, or the invoker of the shown popover the pointer is inside. */
function invokerFrom(node: EventTarget | null): Element | null {
  if (!(node instanceof Element)) return null

  const invoker = node.closest("[interestfor]")
  if (invoker) return nativelyHandled(invoker) ? null : invoker

  const shown = node.closest("[popover]")
  return shown ? (shownBy.get(shown) ?? null) : null
}

// Crossing within the invoker/target pair is not a leave.
function stillInside(invoker: Element, related: EventTarget | null): boolean {
  if (!(related instanceof Node)) return false
  return invoker.contains(related) || (target(invoker)?.contains(related) ?? false)
}

document.addEventListener("pointerover", (event) => {
  if (event.pointerType !== "mouse") return
  const invoker = invokerFrom(event.target)
  if (invoker && !stillInside(invoker, event.relatedTarget)) gain(invoker)
})

document.addEventListener("pointerout", (event) => {
  if (event.pointerType !== "mouse") return
  const invoker = invokerFrom(event.target)
  if (invoker && !stillInside(invoker, event.relatedTarget)) lose(invoker)
})

// Keyboard a11y, as the old hover machinery had: focus shows, blur hides.
document.addEventListener("focusin", (event) => {
  const invoker = invokerFrom(event.target)
  if (invoker) gain(invoker)
})

document.addEventListener("focusout", (event) => {
  const invoker = invokerFrom(event.target)
  if (invoker && !stillInside(invoker, event.relatedTarget)) lose(invoker)
})
