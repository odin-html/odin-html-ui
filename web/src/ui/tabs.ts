/* Tabs, on the authoring model in README.md: one custom element wrapping the markup
 * ui/tabs/tabs.odin already emits, switching which trigger looks
 * active and which panel is shown when a trigger is clicked.
 *
 * Two things move per switch, as upstream moved them: the state attribute on
 * every trigger and every panel in the group -- which TRIGGER_BASE in tabs.odin
 * matches as `data-[oh-tabs-state=active]:...` to draw the active tab -- and the
 * `hidden` class on the panels, which is the only thing that actually hides
 * one. Both names come from the manifest here and are asserted against the
 * rendered markup by tabs_test.odin.
 *
 * What changed from the document-delegating tabs.js is where the handler lives
 * and how a trigger finds its panels, not what gets written. The click listener
 * is on `this` instead of on `document`, and the pass that makes the initially
 * active trigger (or the first one, when the server marked none) take effect
 * runs in connectedCallback for this element's own group, instead of a
 * document-wide querySelectorAll driven by DOMContentLoaded and an
 * "htmx:after:init" event no htmx version emits. A tabs group inserted by a
 * swap settles itself when it connects, which is what those two hooks were
 * reaching for.
 *
 * The pairing is the one real difference. Nothing in a tabs group is nested in
 * the DOM sense -- a trigger and the panel it opens are siblings -- so tabs.js
 * paired them by a shared string, data-tui-tabs-id, and scanned the document
 * for it. <oh-tabs> is that grouping now: the element is the boundary, and a
 * trigger switches the panels inside the nearest one above it. tabs.odin still
 * renders data-oh-tabs-id as the group's name, but nothing here reads it, so it
 * is not in the manifest -- and a group without one, which tabs.js skipped
 * outright, works. The nearest-element guard is what a group nested inside
 * another group's panel needs, and it is what document delegation got for free
 * from closest().
 *
 * window.tui.tabs.setActive is gone rather than ported: no caller needed it,
 * and the only callers
 * inside tabs.js were its own two code paths, which are #activate below.
 *
 * Two of upstream's behaviours are kept as they are. The initial pass is
 * unguarded, so a group whose chosen trigger carries no value activates the
 * empty value and hides every panel -- which is what a valueless trigger, an
 * error the component renders a message for, already means. And nothing
 * re-runs that pass when markup is swapped *inside* the element: the click
 * listener covers new triggers, but panels arriving mid-life are left as the
 * server rendered them, exactly as before.
 *
 * tabs.contract.json names everything this class reads from the markup;
 * tabs_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./tabs.contract.json"

const ELEMENT = contract.element
const TRIGGER = contract.selectors.trigger
const CONTENT = contract.selectors.content
const VALUE = contract.attributes.value
const STATE = contract.attributes.state
const ACTIVE = contract.states.active
const INACTIVE = contract.states.inactive
const HIDDEN = contract.classes.hidden

class OhTabs extends HTMLElement {
  /* A listener on `this` covers descendants swapped in later and dies with the
   * element, so there is nothing to tear down: no disconnectedCallback, per the
   * checklist. The field holds the handler rather than a bound method so the
   * reference is stable -- connectedCallback runs again on every move, and
   * addEventListener de-duplicates by reference. */
  #onClick = (event: MouseEvent): void => {
    const trigger = this.#nearest(event.target)
    if (!trigger) return

    /* Upstream required a value before switching -- with the group id gone,
     * that guard is the value alone. A valueless trigger stays inert. */
    const value = trigger.getAttribute(VALUE)
    if (value) this.#activate(value)
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)

    /* setupInitialStates, narrowed to this element: the trigger the server
     * rendered active, or the first one when it rendered none, decides what the
     * group shows. The attribute is always written by tabs.odin, so the ?? ""
     * is for markup written by hand. */
    const triggers = this.#own(TRIGGER)
    const active =
      triggers.find((trigger) => trigger.getAttribute(STATE) === ACTIVE) ??
      triggers[0]
    if (active) this.#activate(active.getAttribute(VALUE) ?? "")
  }

  /* setActiveTab, minus the group id: every trigger and panel in this group is
   * rewritten, matched on the value, and a panel is hidden by the class rather
   * than by the state attribute -- which is why a panel is visible until this
   * runs. */
  #activate(value: string): void {
    for (const trigger of this.#own(TRIGGER)) {
      const isActive = trigger.getAttribute(VALUE) === value
      trigger.setAttribute(STATE, isActive ? ACTIVE : INACTIVE)
    }

    for (const content of this.#own(CONTENT)) {
      const isActive = content.getAttribute(VALUE) === value
      content.setAttribute(STATE, isActive ? ACTIVE : INACTIVE)
      content.classList.toggle(HIDDEN, !isActive)
    }
  }

  /* The parts of this group: descendants matching the role whose nearest
   * <oh-tabs> is this one, so a tabs group nested in a panel keeps its own. */
  #own(selector: string): Element[] {
    return [...this.querySelectorAll(selector)].filter(
      (part) => part.closest(ELEMENT) === this,
    )
  }

  /* Upstream's e.target.closest(trigger), plus the nesting guard document
   * delegation had for free: a trigger belongs to the nearest element above it,
   * and only that element switches for it. */
  #nearest(target: EventTarget | null): Element | null {
    if (!(target instanceof Element)) return null

    const trigger = target.closest(TRIGGER)
    return trigger && trigger.closest(ELEMENT) === this ? trigger : null
  }
}

customElements.define(ELEMENT, OhTabs)
