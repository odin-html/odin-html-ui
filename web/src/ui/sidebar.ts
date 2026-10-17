/* Sidebar, on the authoring model in README.md: one custom element wrapping the markup
 * ui/sidebar/sidebar.odin already emits, collapsing and expanding a
 * sidebar -- by its trigger, or by ctrl/cmd and the letter the markup declares
 * -- remembering which it was in a cookie, and moving the sidebar's content into
 * the mobile sheet below 768px and back out above it.
 *
 * Almost none of that is this file. The state is one attribute on the wrapper
 * and every part of the sidebar reads it through `group-data-` rules, so
 * collapsing is a single setAttribute; what the script really does is the
 * portal, because moving a subtree between two containers is the one thing CSS
 * cannot express.
 *
 * ## Why the element is on layout()
 *
 * The wrapper sidebar() renders is a Tailwind `peer` and inset() reads its state
 * through `peer-data-`, which is a sibling selector -- so an <oh-sidebar> around
 * sidebar() would push the wrapper a level down and silently stop the page
 * beside it from responding. The layout is the boundary that changes no
 * relationship, and it is also the boundary the handlers want: a trigger is
 * routinely rendered in the page rather than inside the sidebar (which is why
 * sidebar.js delegated its click from `document` at all), and the triggers, the
 * wrappers and the mobile portals of every sidebar in a page are all inside the
 * layout they were written in. The full argument, and the cost -- a sidebar()
 * with no layout() around it has no behaviour -- is in sidebar.odin's comment.
 *
 * ## What changed from the document-delegating sidebar.js
 *
 * The click delegation is on `this` instead of `document`, and it reaches the
 * same triggers by being on the element that contains them. The portal sweep
 * that ran once at module load, on every resize, and on an "htmx:after:init"
 * event no htmx version emits is now: once per element on connect, and on
 * resize. The connect pass is what the load sweep and the dead htmx hook were
 * both reaching for, and it is strictly better than either -- a layout swapped
 * in below 768px portals its content immediately, where upstream's module-load
 * sweep had already run and its htmx hook never fired.
 *
 * The three document-wide lookups are gone with it. A wrapper is found by id
 * *inside this element* rather than in the document, so two layouts on a page
 * cannot answer for each other's sidebars; upstream's could, and would have
 * toggled whichever came first in document order.
 *
 * Upstream's own fixes are kept as they stand. The keyboard handler walks every
 * wrapper rather than the first (a second sidebar's shortcut used to do
 * nothing), the shortcut is matched against the wrapper's own
 * data-oh-sidebar-id, and the cookie carries the id in its name so two sidebars
 * do not overwrite each other's state.
 *
 * ## What outlives the node
 *
 * The inventory, per the checklist: no timers, no intervals, no rAF, no
 * observers, no module registry -- and two listeners that are not on `this`.
 *
 * **The window `resize` listener is the only one in the kit**, and it is the
 * reason this is the second component (after checkbox and label) to need a
 * disconnectedCallback. It is installed in connectedCallback and removed in
 * disconnectedCallback, and the removal is what stops a removed layout from
 * dragging its whole detached subtree through a portal move on every resize for
 * the life of the page -- which is exactly what sidebar.js did, its handler
 * being a module-level function that nothing ever removed. Re-installing is
 * safe: the handler is a field, so the reference is stable across the connects a
 * move produces, and addEventListener de-duplicates by reference.
 *
 * The document `keydown` listener is torn down the same way and for the same
 * reason. It cannot move to `this`: a keydown with nothing focused targets the
 * body and never reaches an element inside it, so the shortcut would only work
 * while focus happened to be in the sidebar. This is the checklist's
 * "document/window listeners" case, taken deliberately and paid for in
 * disconnectedCallback.
 *
 * matchMedia is called for its `.matches` and never subscribed to, exactly as
 * upstream called it, so it adds nothing to the inventory. The query below is
 * the other half of the `md:` breakpoint the markup is written against
 * (`hidden md:block` on the wrapper, `md:hidden` on the sheet): the two have to
 * agree or the portal and the stylesheet disagree about where the content is.
 *
 * ## Ported as they stand
 *
 * The cookie is written and read by nobody. sidebar.js said why, and it still
 * holds: the read belongs on the server, which gets the cookie with the request
 * and can render data-oh-sidebar-state into the wrapper directly, where doing it
 * from script would paint the sidebar expanded and then collapse it. The name
 * here is that contract, which is why it is a constant with a comment rather
 * than a literal -- and why it is not in the manifest, there being nothing on
 * the Odin side yet to agree with it.
 *
 * A collapsible="none" sidebar ignores both the trigger and the shortcut, and
 * the trigger's click is still swallowed by preventDefault. A trigger whose
 * data-oh-sidebar-target names no sidebar in this layout does nothing and looks
 * fine. And the mobile sheet is dialog.js's, not this element's: below 768px the
 * desktop trigger is display:none and the sheet's own trigger is what opens it.
 *
 * sidebar.contract.json names everything this class reads from the markup;
 * sidebar_test.odin renders the Odin side and asserts it is all there. Read the
 * names from the contract here, so the declaration and the code cannot quietly
 * diverge.
 */

import contract from "./sidebar.contract.json"

const WRAPPER = contract.selectors.wrapper
const CONTENT = contract.selectors.content
const TRIGGER = contract.selectors.trigger
const DESKTOP_CONTAINER = contract.selectors.desktopContainer
const ID = contract.attributes.id
const STATE = contract.attributes.state
const COLLAPSIBLE = contract.attributes.collapsible
const SHORTCUT = contract.attributes.shortcut
const TARGET = contract.attributes.target
const PORTAL = contract.attributes.portal
const CONTENT_ID = contract.attributes.content
const EXPANDED = contract.states.expanded
const COLLAPSED = contract.states.collapsed
const COLLAPSIBLE_OFF = contract.collapsibleOff
const MOBILE_QUERY = contract.mobileQuery

/* Upstream's two cookie constants. One cookie per sidebar, the id in the name;
 * seven days. Nothing reads them yet -- see the file comment. */
const COOKIE_PREFIX = "sidebar_state_"
const COOKIE_MAX_AGE = 60 * 60 * 24 * 7

class OhSidebar extends HTMLElement {
  /* Listeners. The click one is on `this` and dies with the element; the other
   * two are on window and document and are removed in disconnectedCallback. All
   * three are fields rather than bound methods so the references are stable --
   * connectedCallback runs again on every move, and addEventListener
   * de-duplicates by reference. */
  #onClick = (event: Event): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    const trigger = target.closest(TRIGGER)
    if (!trigger || !this.contains(trigger)) return

    // Upstream preventDefaults for any trigger, target or not.
    event.preventDefault()

    const id = trigger.getAttribute(TARGET)
    if (id) this.#toggle(id)
  }

  /* Ctrl/cmd and a single character, matched against every wrapper's own
   * declared shortcut -- upstream's loop, narrowed to this layout. */
  #onKeydown = (event: KeyboardEvent): void => {
    if (!(event.ctrlKey || event.metaKey) || event.key.length !== 1) return

    for (const wrapper of this.querySelectorAll(WRAPPER)) {
      const shortcut = wrapper.getAttribute(SHORTCUT)
      if (!shortcut || shortcut.toLowerCase() !== event.key.toLowerCase()) continue

      const id = wrapper.getAttribute(ID)
      if (!id) continue

      event.preventDefault()
      this.#toggle(id)
    }
  }

  // THE window listener. See the file comment; removed in disconnectedCallback.
  #onResize = (): void => {
    this.#syncPortals()
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)
    window.addEventListener("resize", this.#onResize)
    this.ownerDocument.addEventListener("keydown", this.#onKeydown)

    // setupMobilePortals' initial call, narrowed to this layout: a layout
    // rendered or swapped in below the breakpoint portals its content now
    // rather than at the next resize.
    this.#syncPortals()
  }

  /* Required, and only for these two: everything else here is a listener on
   * `this` or a query, and dies with the element. */
  disconnectedCallback(): void {
    window.removeEventListener("resize", this.#onResize)
    this.ownerDocument.removeEventListener("keydown", this.#onKeydown)
  }

  /* setupMobilePortals, unchanged in what it moves: below the breakpoint the
   * content goes into the sheet's portal, above it back into the aside's inner
   * div. Both ends are inside this element -- which is the other reason the
   * boundary is the layout: the content has to stay within the element that
   * moves it, or the next sweep would not find it. */
  #syncPortals(): void {
    const isMobile = window.matchMedia(MOBILE_QUERY).matches

    for (const content of this.querySelectorAll(CONTENT)) {
      const id = content.getAttribute(CONTENT_ID)
      if (id === null) continue

      const portal = this.querySelector(`[${PORTAL}="${id}"]`)
      if (!portal) continue

      if (isMobile && content.parentElement !== portal) {
        portal.appendChild(content)
      } else if (!isMobile && content.parentElement === portal) {
        const desktop = this.querySelector(
          `${WRAPPER}[${ID}="${id}"] ${DESKTOP_CONTAINER}`,
        )
        if (desktop) desktop.appendChild(content)
      }
    }
  }

  // toggleSidebar, unchanged: no sidebar or a non-collapsible one is a no-op.
  #toggle(id: string): void {
    const wrapper = this.#wrapper(id)
    if (!wrapper) return
    if (wrapper.getAttribute(COLLAPSIBLE) === COLLAPSIBLE_OFF) return

    const state = wrapper.getAttribute(STATE) === EXPANDED ? COLLAPSED : EXPANDED
    this.#setState(id, state)
  }

  /* setSidebarState, kept as its own step rather than folded into the toggle:
   * it is the operation "put this sidebar in that state", and the only reason
   * nothing else calls it is that the server-side cookie read does not exist
   * yet. Its wrapper lookup and collapsible guard repeat the toggle's, as
   * upstream's did. */
  #setState(id: string, state: string): void {
    const wrapper = this.#wrapper(id)
    if (!wrapper) return
    if (wrapper.getAttribute(COLLAPSIBLE) === COLLAPSIBLE_OFF) return

    wrapper.setAttribute(STATE, state)
    this.#save(id, state === EXPANDED ? "true" : "false")
  }

  #save(id: string, value: string): void {
    const name = COOKIE_PREFIX + encodeURIComponent(id)
    this.ownerDocument.cookie = `${name}=${value}; path=/; max-age=${COOKIE_MAX_AGE}`
  }

  /* The wrapper this id names, looked up per use rather than closed over, so a
   * sidebar swapped in under the layout is picked up. Document-wide in upstream;
   * this element's own subtree here. */
  #wrapper(id: string): Element | null {
    return this.querySelector(`${WRAPPER}[${ID}="${id}"]`)
  }
}

customElements.define(contract.element, OhSidebar)
