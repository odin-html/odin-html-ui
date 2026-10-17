/* Label, on the authoring model in README.md: one custom element wrapping the markup
 * ui/label/label.odin already emits, dimming the caption while the
 * control its `for` names is disabled -- by adding the classes the markup
 * carries in data-oh-label-disabled-style, and removing them again when the
 * control is re-enabled.
 *
 * This is the one component so far whose subject lives *outside* the element.
 * A label's target is the control with that id, which is a sibling at best and
 * anywhere in the document at worst, so the observer here watches a node this
 * element does not own -- the checklist's "observers watching nodes outside the
 * element" case, and the reason this is the first class with a
 * disconnectedCallback. Nothing announces a `disabled` write, so an observer it
 * has to be; there is no event to listen for instead.
 *
 * What changed from the document-delegating label.js is the scope of both
 * halves. Upstream kept a document.body subtree observer filtered to `disabled`
 * plus a set of the ids worth reacting to, and filled that set from a
 * document-wide querySelectorAll driven by DOMContentLoaded and an
 * "htmx:after:init" event no htmx version emits. Here each label resolves its
 * own target when it connects, styles itself once from that control's current
 * state -- setupLabels' initial pass, narrowed to one label -- and observes
 * that control alone. A label swapped in by htmx settles itself on connect,
 * which is what the two document-level hooks were reaching for and, because the
 * event they hung on is dead, what upstream in fact stopped doing after the
 * first paint.
 *
 * Two deltas, both stated rather than papered over. A label that connects
 * before its target exists observes nothing and stays undimmed until it
 * connects again (an htmx swap of the label, or a move); upstream reached the
 * same outcome by a different route, its sweep having already run, save for one
 * accident -- a *second* label for an id some earlier label had registered got
 * picked up by the document-wide requery on the next toggle. And a label whose
 * control is replaced under it keeps watching the node it attached to rather
 * than following the id, where upstream's body-wide observer followed the id.
 * Closing either would mean a document-scoped watcher, which the checklist
 * rules out and which is not worth reintroducing for the two shapes above.
 *
 * label.contract.json names everything this class reads from the markup;
 * label_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./label.contract.json"

const LABEL = contract.selectors.label
const FOR = contract.attributes.for
const DISABLED_STYLE = contract.attributes.disabledStyle

/* The `for` attribute is the browser's own association and has to sit on the
 * <label>, not on the wrapper -- so unlike the usual configuration-rides-the-
 * element rule, both names this class reads are read off the descendant the
 * component renders. */
class OhLabel extends HTMLElement {
  /* The control the label points at, resolved on connect. Held because the
   * observer needs a node to be disconnected from, and because the state it
   * reports is read off it: one node, watched and read, for the life of this
   * connection. View state, dying with the element -- and dropped on disconnect
   * so a removed label retains nothing of the page it was in. */
  #target: Element | null = null

  #observer = new MutationObserver(() => this.#update())

  connectedCallback(): void {
    const id = this.querySelector(LABEL)?.getAttribute(FOR)
    this.#target = id ? this.ownerDocument.getElementById(id) : null

    // setupLabels' initial pass: the state is applied before anything changes,
    // because a control already disabled at render time fires no mutation.
    this.#update()

    if (!this.#target) return

    this.#observer.observe(this.#target, {
      attributes: true,
      attributeFilter: contract.observed,
    })
  }

  /* Required here and only here: the observer watches a node outside this
   * element, so removing the label would otherwise leave it running against a
   * control that is still in the page. */
  disconnectedCallback(): void {
    this.#observer.disconnect()
    this.#target = null
  }

  /* updateLabelStyle, unchanged in what it does: the classes come from the
   * markup rather than from here, so which look a disabled field gets is the
   * component's decision and not this file's. No target or no classes is a
   * no-op, leaving whatever the server rendered -- upstream's early return. */
  #update(): void {
    const label = this.querySelector(LABEL)
    if (!label || !this.#target) return

    const classes = (label.getAttribute(DISABLED_STYLE) ?? "")
      .split(" ")
      .filter(Boolean)
    if (classes.length === 0) return

    // The property, as upstream read it: `disabled` is a boolean on a form
    // control and undefined on anything else, which reads as "not disabled".
    const disabled = (this.#target as { disabled?: unknown }).disabled === true

    if (disabled) {
      label.classList.add(...classes)
    } else {
      label.classList.remove(...classes)
    }
  }
}

customElements.define(contract.element, OhLabel)
