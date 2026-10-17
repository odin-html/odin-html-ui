/* Checkbox, on the authoring model in README.md: one custom element wrapping the markup
 * ui/checkbox/checkbox.odin already emits, keeping a parent box in
 * step with the children of its group -- ticked when all of them are, dashed
 * when only some are -- and ticking or unticking the whole set when the parent
 * is clicked.
 *
 * The dash is the reason any of this is scripted: `indeterminate` is a DOM
 * property with no HTML attribute behind it, so a partly-ticked group cannot be
 * rendered at all and is correct only once this class has run.
 *
 * What changed from the document-delegating checkbox.js is how a parent finds
 * its children, not what gets written. checkbox.js matched them by scanning the
 * document for a shared string on every event; a group here is a module
 * registry keyed by that same string, joined in connectedCallback and left in
 * disconnectedCallback (the checklist's coordination rule). The element is one
 * checkbox, not one group -- checkbox() takes no children, so there is no
 * wrapper spanning the set -- which is why this is the first ported component
 * with a registry and the first with a disconnectedCallback: the registry is
 * module state and would otherwise retain removed nodes. Everything else that
 * outlives nothing stays untorn-down: the change listener is on `this` and dies
 * with the element.
 *
 * The change handler is on `this` instead of on `document`, and the recompute
 * that checkbox.js ran for every group from DOMContentLoaded and an
 * "htmx:after:init" event no htmx version emits runs on connect instead, once
 * per member joining. Upstream's guard is what makes that converge: a parent
 * connecting before any child sees no children and returns, and each child
 * connecting recomputes.
 *
 * enableReactiveBinding is ported as it stands, oddities included. It replaces
 * the `checked` setter on child boxes -- never the parent's -- so that setting
 * the property in code fires a change event, which is what lets the parent
 * catch up when something other than a click ticks a child. The consequence
 * upstream also had: toggling the parent writes every child, so every child
 * dispatches change, so the parent is recomputed once per child. And the patch
 * fires on any value the old one is `!==` to, not just a changed boolean.
 *
 * checkbox.contract.json names everything this class reads from the markup;
 * checkbox_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./checkbox.contract.json"

const BOX = contract.selectors.box
const GROUP = contract.attributes.group
const PARENT = contract.attributes.parent

/* The groups on the page: the string in data-oh-checkbox-group to the elements
 * carrying it. This is what checkbox.js got from a document querySelectorAll per
 * event, and the reason disconnectedCallback exists -- a set left holding a
 * removed element would keep it alive and let it answer for a group it is no
 * longer in. Members are elements rather than inputs, so an htmx swap *inside*
 * one is picked up: the box is looked up again on every use. */
const groups = new Map<string, Set<OhCheckbox>>()

/* The members of a group, minus the ones on their way out. An outerHTML swap
 * runs the incoming element's connectedCallback *before* the outgoing element's
 * disconnectedCallback (measured, not assumed), so for the length of a swap the
 * registry holds both -- and the departing one must not answer for the group,
 * or the recount the incoming element runs on connect would land on the node
 * that is being thrown away. */
const members = (group: string): OhCheckbox[] =>
  [...(groups.get(group) ?? [])].filter((member) => member.isConnected)

/* The parent of a group, and its children: upstream's two selectors, read off
 * the registry instead of the document. First parent wins, as
 * document.querySelector's did. */
const parentBox = (group: string): HTMLInputElement | null => {
  for (const member of members(group)) {
    const box = member.box
    if (box?.hasAttribute(PARENT)) return box
  }
  return null
}

const childBoxes = (group: string): HTMLInputElement[] => {
  const boxes: HTMLInputElement[] = []
  for (const member of members(group)) {
    const box = member.box
    if (box && !box.hasAttribute(PARENT)) boxes.push(box)
  }
  return boxes
}

/* updateParent, unchanged: all ticked is ticked, some ticked is the dash, and a
 * group missing either half is left alone -- which is also what makes the
 * per-connect recompute safe while a group is still arriving. */
const updateParent = (group: string): void => {
  const parent = parentBox(group)
  const children = childBoxes(group)
  if (!parent || children.length === 0) return

  let checked = 0
  for (const child of children) if (child.checked) checked++

  parent.checked = checked === children.length
  parent.indeterminate = checked > 0 && checked < children.length
}

/* toggleChildren, unchanged. The parent's own box is never patched, so writing
 * it above dispatches nothing; writing a child here dispatches change from each,
 * exactly as upstream did. */
const toggleChildren = (group: string, checked: boolean): void => {
  for (const child of childBoxes(group)) child.checked = checked
}

/* enableReactiveBinding's guard, per input rather than a flag property on it:
 * the boxes are descendants of the elements that patched them, so a weak set
 * retains nothing a removed element would not. */
const patched = new WeakSet<HTMLInputElement>()

const descriptor = Object.getOwnPropertyDescriptor(
  HTMLInputElement.prototype,
  "checked",
)

const bindChecked = (input: HTMLInputElement): void => {
  if (patched.has(input)) return

  const get = descriptor?.get
  const set = descriptor?.set
  if (!get || !set) return

  patched.add(input)
  Object.defineProperty(input, "checked", {
    get,
    set(this: HTMLInputElement, value: boolean) {
      const old = get.call(this)
      set.call(this, value)
      if (old !== value) {
        this.dispatchEvent(new Event("change", { bubbles: true }))
      }
    },
    configurable: true,
  })
}

class OhCheckbox extends HTMLElement {
  /* The group this element joined, held so it leaves the one it is actually in
   * even if the attribute changed while it was connected. View state: it dies
   * with the element, and connectedCallback reads it again on every move. */
  #joined: string | null = null

  /* A listener on `this` covers a box swapped in later and dies with the
   * element. The field holds the handler rather than a bound method so the
   * reference is stable -- connectedCallback runs again on every move, and
   * addEventListener de-duplicates by reference. */
  #onChange = (event: Event): void => {
    const box = this.box
    if (!box || box !== event.target) return

    const group = this.#joined
    if (!group) return

    /* Upstream's branch: the parent drives the set, a child asks for the set to
     * be re-counted. */
    if (box.hasAttribute(PARENT)) {
      toggleChildren(group, box.checked)
    } else {
      updateParent(group)
    }
  }

  /* This element's box. checkbox() takes no children, so the one input inside
   * is always its own. */
  get box(): HTMLInputElement | null {
    return this.querySelector<HTMLInputElement>(BOX)
  }

  connectedCallback(): void {
    this.addEventListener("change", this.#onChange)

    const box = this.box
    const group = box?.getAttribute(GROUP)
    if (!box || !group) return

    this.#joined = group
    let set = groups.get(group)
    if (!set) {
      set = new Set()
      groups.set(group, set)
    }
    set.add(this)

    // init(), narrowed to this member: children get the reactive setter, and
    // the group is re-counted now that one more of it is here.
    if (!box.hasAttribute(PARENT)) bindChecked(box)
    updateParent(group)
  }

  /* Required, and only for this: the registry is module state that outlives the
   * node. The listener is on `this` and needs nothing. The group is dropped when
   * its last member leaves, so a page that swapped a group away holds no key for
   * it. */
  disconnectedCallback(): void {
    const group = this.#joined
    if (!group) return

    this.#joined = null
    const set = groups.get(group)
    if (!set) return

    set.delete(this)
    if (set.size === 0) groups.delete(group)
  }
}

customElements.define(contract.element, OhCheckbox)
