# The component checklist

How a component under `ui/` acquires client behaviour, when it may, and what
keeps the two halves honest. This is the library's authoring model: every
component with a script follows it, and a new one is reviewed against it.

## The decision tree

```
new component "foo"
  │
  ├─ does it need client behaviour?
  │     no  → ui/foo/foo.odin only. Done.
  │           (the default, taken by the majority of the kit)
  │     yes → can the platform do it? popover="auto" light dismiss and
  │           Escape, <dialog>, :popover-open, CSS :has/:focus-within,
  │           CSS anchor positioning, @starting-style animations —
  │           use that first, then re-ask
  │
  ├─ ui/foo/foo.odin                wraps its existing output in <oh-foo>;
  │                                 the markup inside is unchanged
  ├─ web/src/ui/foo.ts              one class, registered "oh-foo"
  ├─ web/src/ui/foo.contract.json   what the class reads from the markup
  └─ ui/foo/foo_test.odin           renders the component, asserts the
                                    contract (see below)
```

A component whose server side is not in the kit — one an application writes
for itself — follows the same shape from wherever it lives: its Odin package
emits the wrapper and carries the contract test, and its class and manifest sit
beside the bundle that ships them.

## The rules

- **The prefix is `oh-`, fixed and not configurable** (the owner,
  2026-10-17). Every element is `oh-<name>` and every role or configuration
  attribute is `data-oh-<name>-*`, including inside Tailwind variants
  (`data-[oh-tabs-state=active]:…`) and the class names the elements write
  (`oh-collapsible-open`). The TypeScript classes are `Oh<Name>`. The reason:
  `oh-` (odin-html) names where an element comes from, and keeps the
  library's names out of a consumer's own namespace — an application's own
  elements and attributes are its to name, and cannot collide with the kit's.

- **The support floor is current evergreen browsers, as policy.** Build against the platform as it is — anchor positioning,
  `popover="auto"`, `@starting-style` are all in bounds; compatibility
  machinery for older engines is out of scope. A shim is justified only for
  a gap in *current* browsers (the `interestfor` shim), and it retires as
  they ship.

- **The wrapper carries an explicit display utility** — `class="contents"` to
  vanish, `class="block"` to be a box. An unknown element defaults to
  `display: inline`, which breaks layout precisely in the pre-upgrade window,
  invisibly on a fast machine. Per component; there is no blanket rule,
  because CSS cannot express one (`oh-*` is not a selector). The deciding
  question is whether the component *already renders its own layout box*: if
  its markup starts with one (`<div class="relative w-full">`, …), the
  wrapper is `contents` so no second box appears between the caller and it;
  a component whose markup has no single root box gets `block` (or whatever
  box it should be).

- **A non-passive `wheel` listener goes on a painted element, never on a
  `contents` wrapper.** Chrome derives the compositor's blocking
  wheel-handler region from layout boxes, and `display: contents` produces
  none: the listener is called, but with `cancelable: false`, so
  `preventDefault()` is silently a no-op and the browser scrolls anyway.
  Nothing else in the checklist notices — pointer events are hit-tested
  against the markup and bubble through the wrapper as usual — so the
  failure reads as "dragging works, scrolling does not", and only on a
  gesture device (Magic Mouse, trackpad), because a discrete notch on a page
  with nothing to scroll cancels nothing visible. Bind it to the element the
  gesture is *over*, and rebind it per swap if that element is swapped.
  Measured in Chromium 151 with `Input.synthesizeScrollGesture`.
- **Markup works before upgrade.** The element enhances; it never supplies.
  Whatever the page must show without JavaScript is rendered by the server.
- **The attribute vocabulary is split by role.** The roles of descendants the
  handlers match are `data-oh-*`. Configuration on a component designed fresh
  rides plain attributes on `<oh-foo>` itself; on a *ported* component it
  stays where the server already rendered it — `data-oh-*` on the markup's
  own root — because the port's markup-inside-unchanged rule wins (every
  ported component so far: slider, toast, tabs, textarea, tagsinput,
  rating). Moving it to the wrapper is a later cleanup, not part of a port.
  (`data-tui-*` is the legacy vocabulary, retired component by component as
  the port proceeds.)
- **Listeners live on `this`.** Bubbling covers descendants swapped in later,
  so an htmx swap *inside* the element needs no re-initialisation. Exceptions
  to remember: `focus`/`blur` do not bubble — use `focusin`/`focusout`;
  capture phase is available on `this` where intent must be read before a
  bubble handler mutates the DOM; and the platform's non-bubbling events
  (`toggle` on a popover, `cancel`/`close` on a dialog) still reach a capture
  listener on `this`, which beats attaching to the descendant (timepicker and
  selectbox hear opening that way).
- **Teardown only for what outlives the node.** A listener on `this`, or an
  observer owned by the instance and observing `this` or a descendant, dies
  with the element and needs no `disconnectedCallback`. (An
  `IntersectionObserver` must target a descendant that generates a box — a
  `contents` wrapper has none; carousel observes its own root div.) One is required for — and only for —
  `document`/`window` listeners, rAF loops, and observers watching nodes
  outside the element. Timers follow the principle, not a blanket rule: a
  timeout whose callback touches only the element's own subtree dies
  harmlessly, and one that *restores* state outside the element
  (`copybutton`'s caption revert) must be allowed to run — cancelling it on
  disconnect is what would leak the wrong state.
- **Fields hold view state only; they die with the element.** Anything that
  must survive an htmx swap lives on an ancestor outside the swap target, or
  it does not exist. This is a review criterion: read the fields.
- **Instance coordination via a module registry**, joined and left in the
  lifecycle callbacks — never a `querySelectorAll` scan per event.
- **No shadow DOM.** Global styles must apply, htmx must swap fragments
  inside elements, and server-rendered children are the element's children.

A children-taking component wraps by opening `h.elem_open("oh-foo", ...)`
inside its existing `open_scope()` — `close_all` closes innermost-first, so
the wrapper's close lands after the component's own (see `avatar.odin`).
Where the markup's own root was pure structure (popover's `contents` root
div), the element may *replace* it rather than wrap it — same box, one node
fewer; `<oh-popover>` is the worked example.

## Popovers, and hover

Anything that floats — menus, pickers, suggestion lists — composes popover's
root/trigger/content and gets the platform: `popover="auto"` dismissal, CSS
anchor positioning, `@starting-style` animation, and popover.ts's one click
handler. Cross-component control is `content.showPopover()`/`hidePopover()`
on the content element itself — the platform's API, not a method surface; a
component that must own open/close outright (tagsinput's suggestions) asks
for `{kind = .Manual}` and gets no light dismiss to fight.

One Tailwind limit found here: an arbitrary property whose value is a bare
dashed ident (`[anchor-name:--x]`) generates nothing. The popover anchor
plumbing therefore lives as three real rules in `web/src/index.css`, keyed on
the element and role names; per-placement geometry stays in class strings.

**CSS anchor positioning cannot name anything inside an SVG** — measured
(Chromium 151) for `anchor-name` on `<g>`, on `<circle>`,
and on an HTML element inside a `<foreignObject>`: all three leave the
positioned element at its static position, while the identical rule on a
plain `<div>` anchors correctly. A popover that must attach to something
drawn in SVG therefore needs an HTML stand-in — an empty absolutely
positioned box inside the same positioning context, parked over the shape by
the component's own element. Anchoring then tracks whatever moves the box; the
element keeps it in step on the events that move the drawing rather than in
a rAF loop.

Hover popovers (tooltip, hovercard, dropdown submenus) emit the standard
interest-invoker vocabulary — `interestfor` naming the content's id, delays
as `interest-delay-*` inline style — and `interestfor.ts` emulates it where
the browser does not (a coordinator, installed once). Native interest
invokers are buttons and links only, so the wrapper-span invokers tooltip and
hovercard emit are shim-driven in every browser; dropdown's submenu button is
native where shipped. **Not claimed, deliberately**: touch long-press, and the spec's fuller a11y affordances — the
old hover popovers lacked them too, and a component that needs them should
say so rather than assume the shim provides them.

## The lifecycle hazards

**Refcount thrash.** An htmx swap replaces the old node with the new one,
and the callback order is the *opposite* of intuition — measured (Chromium,
`checkbox` port): on an `outerHTML` replacement the incoming element's
`connectedCallback` runs *before* the outgoing element's
`disconnectedCallback`, so counts go 1→2→1, not 1→0→1. Two consequences: a
"last instance out removes the document listener" scheme never actually hits
zero mid-swap (benign), but a registry briefly holds both the departing and
arriving instances — reads during `connectedCallback` must filter members by
`isConnected` or they can pick the corpse. Prefer installing document-scoped
listeners on *open* rather than on *connect*, so the question rarely arises;
where it does, a coordinator that installs once and never uninstalls is
acceptable and cheaper than getting refcounting right per component.

**Cross-swap state.** An element inside the swap target is destroyed exactly
when continuity is needed. State that must survive lives on an element
*wrapping* the swap target — a wrapper the page shell emits and the
swapped fragment never does — or nowhere. What the wrapper mostly buys is not stored state but *listeners*:
they are installed once and bubbling covers every subtree swapped in
underneath, so the swap needs no re-initialisation.

The bill for that comes due in the other direction: **a field on a wrapping
element that points at markup inside the swap target retains the whole
detached tree.** Measured: three such fields — a hovered node, its
highlighted neighbours, the element an open menu was anchored to — kept the
entire old swapped-out subtree alive through a forced GC. Drop them when
the markup goes. A `MutationObserver` on `this` watching `childList` (owned
by the instance, so no teardown is owed) is the version-independent signal:
htmx 4 renamed its swap events and dispatches them on `document`, where an
element listening on `this` cannot hear them. Filter by `isConnected` rather
than clearing wholesale, so an unrelated inner swap does not cost the
element state that is still valid.

**Pointer capture retargets the click.** `setPointerCapture` on
`pointerdown` sends the compatibility `click` to the *capturing* element
rather than to what was under the pointer — measured, not reasoned
(capturing a drag on an `<svg>` surface made every click on a `<g>` inside it
arrive at the `<svg>`, and htmx's handler on the `<g>` never ran). Where the drag surface contains click targets, take capture
late — on the first move past a slop threshold, once the gesture is
provably a drag. Where it does not (slider's thumb), capturing on
`pointerdown` is fine.

## The contract test

Nothing else connects `foo.odin` (which emits attributes) to `foo.ts` (which
reads them) across two languages. The contract closes that gap structurally:

- **`web/src/ui/foo.contract.json`** declares the element name, its display
  utility, the selectors the class queries, and the attributes it observes.
- **`foo.ts` imports the manifest** and uses it — selectors and observed
  names come from the contract, so the code cannot quietly read what it does
  not declare.
- **`foo_test.odin` reads the same manifest** (via `#directory`, no Vite
  involved), renders the component, and asserts the rendered markup carries
  every declared attribute — and that the wrapper's class list contains the
  declared display utility, since omission fails silently.

*Why a JSON manifest*: both sides consume one checked-in file, so drift
appears in a diff touching the shared manifest; `odin test` needs no
JavaScript toolchain; and TypeScript imports JSON natively
(`resolveJsonModule`). The alternative — parsing a TS export from Odin — was
rejected outright, and a build-time generated manifest adds a step that can
itself go stale. Known weakness, accepted: assertions are substring checks
against rendered markup, and the declaration can still name *less* than the
code reads if the code bypasses the manifest — which is why the manifest's
values, not literals, are what the class uses.

The manifest's schema is per-component, not fixed — declare what the class
actually consumes. In particular, the test helper that turns a declared
selector into a markup assertion must match the selector *kinds* the
component declares: `progress` declares only attribute selectors
(`[data-oh-…]`), so its helper strips `[]`; a component that also reads
classes (`input`'s `.icon-open`) declares them explicitly and its helper
handles the dot — don't smuggle one kind through a helper written for the
other (attribute-with-value, `[data-oh-collapsible="root"]`, is a third kind
and works with the plain `[]`-trim helper). A *value* both sides must agree
on is declarable too: `textarea`'s `enabled: "true"` is compared by the TS
side and asserted by the Odin side, same as an attribute name. The rule for
what belongs in the manifest: every name the two sides must *agree* on —
read from the markup, or written by the class and matched by server-rendered
CSS (`collapsible`'s `oh-collapsible-open` class). A name the class writes
that nothing on the Odin side renders or matches (`aria-expanded`) stays
out: there is no agreement to test.

**Borrowed vocabulary**: a component that composes *another* component's
markup (tagsinput's suggestions popover; dropdown, selectbox, datepicker,
timepicker are in the same position) declares only its **own** names plus
the seam that bridges the two — the id or role its class uses to reach the
other component. The other component's attributes belong to *that*
component's contract; reading them is acceptable during the port (isolate
them as named constants with a note on when they retire), but declaring
them would duplicate ownership.

The test lives beside the component's other markup tests and runs with the
rest of that package's tests (`odin test ui/foo`).

## Browser lifecycle checks

Structural tests do not prove behaviour. Browser-dependent checks are
**manual, run by whoever writes the element, and recorded with the change that
introduces it**: upgrade works after an htmx
swap, teardown on removal (nothing left ticking, nothing retained),
pre-upgrade markup renders sanely with the bundle blocked.

**Nothing is checked in to drive them.** No browser automation lives in
this repository, and none should be added as permanent scaffolding. Write the
driver when a change needs it, run it, record the results with the change,
and let it go. The pattern that
worked, if it helps: Playwright installed unsaved (`npm i --no-save
playwright`), the real page through the Vite dev server against an
application with known data, everything asserted by returning primitives from `page.evaluate` —
never an `ElementHandle`, whose remote reference retains the node and
poisons any retention measurement. For retention specifically: `WeakRef` the
nodes, force GC with `--js-flags=--expose-gc`, and include a sacrificial
plain node that *must* be collected, or the method is measuring nothing.

## Reference implementation

`progress` is the worked example: `progress.contract.json`,
`progress.ts` (one observer, owned by the instance, observing `this` — no
`disconnectedCallback`), the `<oh-progress class="block">` wrapper in
`ui/progress/progress.odin`, and `test_progress_contract` in
`progress_test.odin`.
