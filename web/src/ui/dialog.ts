/* Dialog, on the authoring model in README.md: one custom element wrapping the group
 * ui/dialog/dialog.odin emits -- and very little of it, because the
 * <dialog> was largely native already. What the element does: open and close
 * (showModal() is the only way into the top layer, so a server-opened dialog
 * needs the one-shot initial-open consumed at connect), the click-away on the
 * backdrop, and disable-esc as a preventDefault on the browser's `cancel`.
 *
 * What moving onto the platform deleted from upstream's dialog.js: the close timer and the
 * data-tui-dialog-closing/-open attribute machinery -- the CSS keys on the
 * native `open` attribute now, with @starting-style for the way in and
 * discrete display/overlay transitions holding the node visible through the
 * way out, so close() simply closes and the fade happens; the per-dialog
 * trigger-state attributes nothing styled; the init-marker dance and both
 * htmx re-init hooks (upgrade is the platform's); and window.tui.dialog,
 * which had no callers and is replaced by nothing.
 *
 * `cancel` and `close` do not bubble; capture on `this` reaches them where
 * needed. Listeners live on `this` and die with the node; the one exception
 * is the module-level click listener below for triggers that sit *outside*
 * the dialog they act on (for_/data-oh-dialog-target) -- a coordinator
 * installed once, per the checklist, since no element contains those.
 *
 * dialog.contract.json names everything this class reads from the markup;
 * dialog_test.odin renders the Odin side and asserts it is all there. */

import contract from "./dialog.contract.json"

const DIALOG = contract.selectors.dialog
const TRIGGER = contract.selectors.trigger
const CLOSE = contract.selectors.close
const DISABLE_CLICK_AWAY = contract.attributes.disableClickAway
const DISABLE_ESC = contract.attributes.disableEsc
const INITIAL_OPEN = contract.attributes.initialOpen
const SHOW_MODAL = contract.attributes.showModal
const TARGET = contract.attributes.target

class OhDialog extends HTMLElement {
  #onClick = (event: MouseEvent): void => {
    const target = event.target
    if (!(target instanceof Element)) return

    const trigger = target.closest(TRIGGER)
    if (trigger && this.#owns(trigger) && !trigger.hasAttribute(TARGET)) {
      this.toggle()
      return
    }

    const close = target.closest(CLOSE)
    if (close && this.#owns(close) && !close.hasAttribute(TARGET)) {
      this.close()
      return
    }

    // A click that targets the <dialog> element itself landed on the
    // backdrop (or the panel's own padding -- upstream's behaviour too).
    if (target === this.#dialog() && !this.hasAttribute(DISABLE_CLICK_AWAY)) {
      this.close()
    }
  }

  #onCancel = (event: Event): void => {
    if (event.target === this.#dialog() && this.hasAttribute(DISABLE_ESC)) {
      event.preventDefault()
    }
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)
    this.addEventListener("cancel", this.#onCancel, true)

    // One-shot: consumed so a later re-connect never re-opens a dialog the
    // user has closed.
    const dialog = this.#dialog()
    if (dialog?.getAttribute(INITIAL_OPEN) === "true") {
      dialog.removeAttribute(INITIAL_OPEN)
      this.open()
    }
  }

  open(): void {
    const dialog = this.#dialog()
    if (!dialog || dialog.open) return

    if (dialog.getAttribute(SHOW_MODAL) === "true") {
      dialog.showModal()
    } else {
      dialog.show()
    }
  }

  close(): void {
    const dialog = this.#dialog()
    if (dialog?.open) dialog.close()
  }

  toggle(): void {
    this.#dialog()?.open ? this.close() : this.open()
  }

  /* This group's own, not a nested dialog's -- the closest guard is what the
   * old getDialog's ownership filter did. */
  #owns(el: Element): boolean {
    return el.closest(contract.element) === this
  }

  #dialog(): HTMLDialogElement | null {
    for (const el of this.querySelectorAll<HTMLDialogElement>(DIALOG)) {
      if (this.#owns(el)) return el
    }
    return null
  }
}

customElements.define(contract.element, OhDialog)

/* Remote triggers and closes: for_ renders data-oh-dialog-target with the
 * dialog root's id, and the element that carries it can sit anywhere in the
 * page -- outside every oh-dialog, which is why no element listener can hear
 * it. One delegated listener, installed once and never uninstalled. */
document.addEventListener("click", (event) => {
  const target = event.target
  if (!(target instanceof Element)) return

  const remote = target.closest(`${TRIGGER}[${TARGET}], ${CLOSE}[${TARGET}]`)
  if (!remote) return

  const group = document.getElementById(remote.getAttribute(TARGET) ?? "")
  if (!(group instanceof OhDialog)) return

  if (remote.matches(CLOSE)) {
    group.close()
  } else {
    group.toggle()
  }
})
