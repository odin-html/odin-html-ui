/* Dropdown, on the authoring model in README.md: one custom element wrapping the menu
 * ui/dropdown/dropdown.odin emits. The old dropdown.js was sixteen
 * lines of document delegation; the element is the same one behaviour scoped
 * to itself -- a click on an item closes the popover around it, unless the
 * item says otherwise. Everything else a menu does (open on click, light
 * dismiss, Escape, one-menu-at-a-time, submenus on hover) is popover.ts, the
 * interestfor module, or the platform.
 *
 * A submenu item closes its own submenu only, as the delegation version did:
 * closest("[popover]") from the item is the submenu's content. Closing the
 * main menu closes any open submenu with it -- native, by containment.
 *
 * One listener on `this`, nothing outliving the node, no
 * disconnectedCallback.
 *
 * dropdown.contract.json names everything this class reads from the markup --
 * [popover] being the seam to popover's component, the platform's own
 * attribute -- and dropdown_test.odin renders the Odin side and asserts it is
 * all there. */

import contract from "./dropdown.contract.json"

const ITEM = contract.selectors.item
const POPOVER_CONTENT = contract.selectors.popoverContent
const SUBMENU_TRIGGER = contract.attributes.submenuTrigger
const PREVENT_CLOSE = contract.attributes.preventClose

class OhDropdown extends HTMLElement {
  #onClick = (event: MouseEvent): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    const item = target.closest(ITEM)
    if (!item || !this.contains(item)) return
    if (item.hasAttribute(SUBMENU_TRIGGER)) return
    if (item.getAttribute(PREVENT_CLOSE) === "true") return

    const content = item.closest<HTMLElement>(POPOVER_CONTENT)
    if (content?.matches(":popover-open")) {
      content.hidePopover()
    }
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)
  }
}

customElements.define(contract.element, OhDropdown)
