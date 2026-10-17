/* Copy button, on the authoring model in README.md: one custom element wrapping the
 * markup ui/copybutton/copybutton.odin already emits, writing another
 * element's text to the clipboard when the button is clicked and showing a tick
 * for two seconds afterwards.
 *
 * What changed from the document-delegating copybutton.js is where the handler
 * lives and how the button finds the pieces around it, not what it does: one
 * click listener on `this` instead of one on `document`, and the two icons are
 * looked up inside this element rather than inside whatever
 * `closest("[data-copy-button]")` returned. The copy *source* is still resolved
 * the same way -- by id, through the document -- because a copy button's subject
 * is deliberately somewhere else on the page (the `<pre>` above it, a field
 * beside it); that is label's case again, and the one lookup an element boundary
 * cannot narrow.
 *
 * Upstream's source reading is kept as it stands, oddities included: `value` if
 * the target has one and textContent otherwise, so an input, a textarea and a
 * <pre> all work without the caller saying which it is, and the result is
 * trimmed. The one narrowing this port adds is a type test -- upstream took any
 * `value !== undefined`, which on an element whose `value` is a number (a
 * `<progress>`, an `<li>`) reached `.trim()` on a number and threw; here a
 * non-string `value` falls through to textContent instead.
 *
 * The clipboard fallback is kept whole, including the branch that reaches it:
 * navigator.clipboard on a secure context, and otherwise -- or on a rejected
 * write -- the off-screen textarea and document.execCommand("copy"). It is
 * deprecated and it is what a non-secure origin has.
 *
 * ## The tooltip rewrite, and the wrapper class that used to carry it
 *
 * copybutton.js found the caption to overwrite with "Copied!" by climbing from
 * the button to `closest(".inline-block")` -- which was always the component's
 * own wrapper div -- and then two parents up. <oh-copybutton> now sits exactly
 * where that div sat in the tree, so the climb starts from `this` and the two
 * hops land on the same ancestor as before. The Tailwind utility stops being a
 * script hook and goes back to being layout, which is the one thing about this
 * component the port improves rather than moves.
 *
 * `data-copy-tooltip-text` is templui's tooltip contract, and nothing in this
 * kit renders it -- our tooltip is popover-based. The read is ported as it
 * stands (with the vocabulary renamed like the rest) and stays *out* of the
 * manifest: nothing on the Odin side writes it, so there is no agreement to
 * test, per the rule in web/src/ui/README.md. So is "Copied!", which this class
 * writes and nothing matches.
 *
 * ## The timer, and why there is still no disconnectedCallback
 *
 * The checklist lists timers among the things a disconnectedCallback exists
 * for, and this is the argued exception. The pending timeout touches three
 * nodes: the two icon spans, which are this element's own children -- writing
 * `style.display` on a detached node is inert, and if the element is still in
 * the page it is exactly the revert that has to happen -- and the tooltip
 * caption, which lives *outside* the element and would otherwise be left
 * reading "Copied!" forever by a button removed mid-feedback. Cancelling it on
 * disconnect would therefore trade a bounded 2s retention of the element's own
 * subtree for a permanently wrong caption. Nothing else survives: no interval,
 * no document listener, no registry, and the click listener is on `this` and
 * dies with the element.
 *
 * copybutton.contract.json names everything this class reads from the markup;
 * copybutton_test.odin renders the Odin side and asserts it is all there. Read
 * the names from the contract here, so the declaration and the code cannot
 * quietly diverge.
 */

import contract from "./copybutton.contract.json"

const ROOT = contract.selectors.root
const ICON_CLIPBOARD = contract.selectors.iconClipboard
const ICON_CHECK = contract.selectors.iconCheck
const TARGET = contract.attributes.target

// Not in the manifest: neither name is rendered or matched by the Odin side.
const TOOLTIP_TEXT = "[data-oh-copybutton-tooltip-text]"
const COPIED_TEXT = "Copied!"

// Upstream's 2000, named.
const FEEDBACK_MS = 2000

/* Upstream's smart detection: `value` when the target has one, textContent
 * otherwise -- see the file comment for the type test around it. */
const sourceText = (target: Element): string => {
  const value = (target as { value?: unknown }).value
  return typeof value === "string" ? value : (target.textContent ?? "")
}

/* The fallback for a non-secure context or a rejected write, unchanged: an
 * off-screen textarea, selected, copied by the deprecated command, and removed
 * again whether or not it worked. */
const fallbackCopy = (text: string, copied: () => void): void => {
  const area = document.createElement("textarea")
  area.value = text
  area.style.position = "fixed"
  area.style.top = "-9999px"
  area.style.left = "-9999px"
  document.body.appendChild(area)
  area.focus()
  area.select()

  try {
    if (document.execCommand("copy")) {
      copied()
    } else {
      console.error("CopyButton: Fallback copy failed")
    }
  } catch (err) {
    console.error("CopyButton: Fallback copy error", err)
  }

  document.body.removeChild(area)
}

class OhCopybutton extends HTMLElement {
  /* A listener on `this` covers descendants swapped in later and dies with the
   * element, so there is nothing to tear down: no disconnectedCallback, per the
   * checklist and the timer argument in the file comment. The field holds the
   * handler rather than a bound method so the reference is stable --
   * connectedCallback runs again on every move, and addEventListener
   * de-duplicates by reference. */
  #onClick = (event: Event): void => {
    const source = event.target
    if (!(source instanceof Element)) return

    /* Upstream's e.target.closest("[data-copy-button]"), narrowed to this
     * element: the button's root is the only thing inside one, so this is the
     * same match with the document scan gone. */
    const root = source.closest(ROOT)
    if (!root || !this.contains(root)) return

    const id = root.getAttribute(TARGET)
    if (!id) {
      console.error("CopyButton: No target-id specified")
      return
    }

    // The subject is elsewhere on the page by design, so this is the one lookup
    // that still goes through the document.
    const target = this.ownerDocument.getElementById(id)
    if (!target) {
      console.error(`CopyButton: Element with id '${id}' not found`)
      return
    }

    const iconClipboard = root.querySelector<HTMLElement>(ICON_CLIPBOARD)
    const iconCheck = root.querySelector<HTMLElement>(ICON_CHECK)
    if (!iconClipboard || !iconCheck) return

    const text = sourceText(target).trim()
    const copied = (): void => this.#showCopied(iconClipboard, iconCheck)

    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard
        .writeText(text)
        .then(copied)
        .catch((err: unknown) => {
          console.error("CopyButton: Failed to copy text", err)
          fallbackCopy(text, copied)
        })
    } else {
      fallbackCopy(text, copied)
    }
  }

  connectedCallback(): void {
    this.addEventListener("click", this.#onClick)
  }

  /* showCopied, unchanged in what it writes: the icons swap by inline display
   * -- which is why the `hidden` class the server renders on the tick is stale
   * after the first copy, and the inline style is what decides from then on --
   * and the caption, if there is one, says "Copied!" until the timer restores
   * what it said before.
   *
   * Upstream's two behaviours on a second click during feedback are kept: a new
   * timer is started rather than the running one restarted, so the first revert
   * lands early, and the caption's "original" text is whatever it reads at click
   * time, which for a second click is "Copied!". */
  #showCopied(iconClipboard: HTMLElement, iconCheck: HTMLElement): void {
    iconClipboard.style.display = "none"
    iconCheck.style.display = "inline"

    // Two parents up from the element, which is where the wrapper div stood
    // when copybutton.js climbed to it with closest(".inline-block").
    const caption = this.parentElement?.parentElement?.querySelector(
      TOOLTIP_TEXT,
    )
    const original = caption?.textContent
    if (caption) caption.textContent = COPIED_TEXT

    setTimeout(() => {
      iconClipboard.style.display = "inline"
      iconCheck.style.display = "none"
      if (caption && original) caption.textContent = original
    }, FEEDBACK_MS)
  }
}

customElements.define(contract.element, OhCopybutton)
