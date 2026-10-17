/* Collapsible, on the authoring model in README.md: one custom element wrapping the
 * markup ui/collapsible/collapsible.odin already emits, opening and
 * closing the content when the trigger is clicked -- or pressed with space or
 * enter, since the trigger is a div and has no button behaviour of its own.
 *
 * Two things move per toggle, as upstream moved them: the state attribute on
 * the root, which is the source of truth read back on the next toggle, and the
 * open class on the content, which is what the grid selector in
 * collapsible.odin matches to animate the row from 0fr to 1fr. The class and
 * that selector are one mechanism; both names come from the manifest here and
 * are asserted against the rendered markup by collapsible_test.odin.
 *
 * What changed from the document-delegating collapsible.js is where the
 * handlers live, not what they do: click and keydown are listened for on `this`
 * instead of on `document`, and the catch-up pass that gives a root rendered
 * open its content class runs in connectedCallback for this element's own root,
 * instead of a document-wide querySelectorAll driven by DOMContentLoaded and an
 * "htmx:after:init" event no htmx version emits. A collapsible inserted by a
 * swap settles itself when it connects, which is what the two document-level
 * hooks were reaching for.
 *
 * Nesting is the one place the move costs something. Document delegation got
 * "innermost wins" for free -- one listener, and closest() from the event's
 * target found the nearest trigger and the nearest root. A listener per element
 * sees the same click at every ancestor, so the guard is explicit: the nearest
 * <oh-collapsible> above the trigger is the only one that acts on it. The
 * content is found by upstream's findDirectContent for the same reason, a
 * nested collapsible's content being a descendant of this one's too.
 *
 * Three of upstream's behaviours are kept as they are, all visible before the
 * element ever runs. aria-expanded is written on toggle and never on the
 * catch-up pass, so a collapsible rendered open says nothing about being
 * expanded until someone closes it; the trigger is not focusable unless the
 * caller makes it so, which leaves the keyboard path reachable only through a
 * caller's tabindex or a <button> inside the trigger; and the server renders
 * the state attribute but not the open class, so an open collapsible is drawn
 * closed until this class connects. All three are the port's inheritance, not
 * its decisions -- fixing the last one means rendering the class server-side,
 * which is a change to the component rather than to its script.
 *
 * collapsible.contract.json names everything this class reads from the markup;
 * collapsible_test.odin renders the Odin side and asserts it is all there. Read
 * the names from the contract here, so the declaration and the code cannot
 * quietly diverge.
 */

import contract from "./collapsible.contract.json"

const ELEMENT = contract.element
const ROOT = contract.selectors.root
const TRIGGER = contract.selectors.trigger
const CONTENT = contract.selectors.content
const STATE = contract.attributes.state
const OPEN = contract.states.open
const CLOSED = contract.states.closed
const OPEN_CLASS = contract.classes.open

/* findDirectContent, unchanged: a nested collapsible's content matches from
 * here too, so the candidates are filtered to the one whose nearest root is
 * this root. */
const directContent = (root: Element): HTMLElement | null => {
  for (const content of root.querySelectorAll<HTMLElement>(CONTENT)) {
    if (content.closest(ROOT) === root) return content
  }
  return null
}

class OhCollapsible extends HTMLElement {
  /* Listeners on `this` cover descendants swapped in later and die with the
   * element, so there is nothing to tear down: no disconnectedCallback, per the
   * checklist. The fields hold the handlers rather than bound methods so the
   * references are stable -- connectedCallback runs again on every move, and
   * addEventListener de-duplicates by reference. */
  #onClick = (event: MouseEvent): void => {
    const trigger = this.#triggerFor(event.target)
    if (!trigger) return

    event.preventDefault()
    this.#toggle(trigger)
  }

  #onKeydown = (event: KeyboardEvent): void => {
    if (event.key !== " " && event.key !== "Enter") return

    const trigger = this.#triggerFor(event.target)
    if (!trigger) return

    event.preventDefault()
    this.#toggle(trigger)
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)
    this.addEventListener("keydown", this.#onKeydown)

    /* initializeCollapsibles, narrowed to this element: the open class is the
     * script's to write, so a root the server rendered open has to be caught up
     * here -- nothing announces it, and there is no event to wait for. */
    const root = this.#root()
    const content = root ? directContent(root) : null
    if (root && content) {
      content.classList.toggle(OPEN_CLASS, root.getAttribute(STATE) === OPEN)
    }
  }

  /* The root this element wraps: the first one inside it that is not a nested
   * collapsible's. */
  #root(): Element | null {
    const root = this.querySelector(ROOT)
    return root && root.closest(ELEMENT) === this ? root : null
  }

  /* Upstream's e.target.closest(trigger), plus the nesting guard document
   * delegation had for free: a trigger belongs to the nearest element above it,
   * and only that element toggles for it. */
  #triggerFor(target: EventTarget | null): Element | null {
    if (!(target instanceof Element)) return null

    const trigger = target.closest(TRIGGER)
    return trigger && trigger.closest(ELEMENT) === this ? trigger : null
  }

  /* toggle, unchanged in what it writes: the state attribute is read back as
   * the current state, so whatever else sets it -- the server, htmx -- decides
   * which way the next toggle goes. aria-expanded is written and never read,
   * which is why it is not in the manifest: nothing on the Odin side renders
   * it. */
  #toggle(trigger: Element): void {
    const root = this.#root()
    if (!root) return

    const isOpen = root.getAttribute(STATE) === OPEN
    root.setAttribute(STATE, isOpen ? CLOSED : OPEN)
    trigger.setAttribute("aria-expanded", String(!isOpen))
    directContent(root)?.classList.toggle(OPEN_CLASS, !isOpen)
  }
}

customElements.define(ELEMENT, OhCollapsible)
