---
id: odin-html-ui
level: vision
title: "odin-html-ui"
short_code: "UI-V-0001"
created_at: 2026-10-17T17:55:55.749734+00:00
updated_at: 2026-10-17T17:55:55.749734+00:00
archived: false

tags:
  - "#vision"
  - "#phase/draft"


exit_criteria_met: false
initiative_id: NULL
---

# odin-html-ui Vision

## Purpose

odin-html-ui is a library of **server-rendered UI components for Odin**. Each
component is one Odin package under `ui/` that writes its markup through
odin-html-builder; an application composes pages from them the way it composes
any other builder call, and the page is complete HTML when it leaves the
server. Where a component needs behaviour only a browser can provide, a small
client half — an `oh-*` custom element — enhances the markup that is already
there. It never supplies it.

The point, in order:

1. **The server owns the page.** What a page shows without JavaScript is what
   the server rendered; scripts add interaction and nothing a reader needs.
   This is what makes the kit fit an htmx-driven application, where a swap
   replaces server-rendered fragments and the elements inside them must
   survive being swapped.
2. **The platform before a script.** `popover="auto"`, `<dialog>`, CSS anchor
   positioning, `:has`, `@starting-style` and interest invokers do what a
   component library used to do in JavaScript; a component reaches for a
   script only for what is left.
3. **Two languages, one checked contract.** The Odin half emits names the
   TypeScript half reads. Nothing but a test joins them, so every component
   with a client half has one.

## Product/Solution Overview

Libraries, not applications — the family's stance, inherited from odin-rdf. The
kit supplies components and a page shell; routing, data, authorization and the
server belong to the application. The placeholder consumer is
`odin-html-app`.

Two halves in one repository:

- **`ui/<name>/`** — the Odin packages, about forty: accordion, alert,
  aspectratio, avatar, badge, breadcrumb, button, calendar, card, carousel,
  checkbox, collapsible, copybutton, datepicker, dialog, dropdown, form,
  hovercard, icon, input, inputotp, label, layout, pagination, popover,
  progress, radio, rating, selectbox, separator, sheet, sidebar, skeleton,
  slider, table, tabs, tagsinput, textarea, timepicker, toast, toggle,
  tooltip. `layout` is the page shell: the document, its `<head>`, and the
  links to the stylesheet and bundle in development (the Vite dev server) and
  in a release (content-hashed names passed in by `-define`).
- **`web/`** — TypeScript, Vite and Tailwind, built with Bun: the `oh-*`
  elements and their contract manifests in `web/src/ui`, the interest-invoker
  shim, and the stylesheet whose Tailwind build scans `ui/` for the utilities
  the components name.

## Current State

*(2026-10-17, at the repository's founding.)*

**Ported and green, unreleased.** The kit was ported from templui component by
component, its markup kept and its class strings carried over as Tailwind
utility strings, shadcn's theme tokens (`--background`, `--primary`, `--muted`,
`--sidebar-*`, …) mapped into Tailwind in `web/src/index.css`. 42 packages
under `ui/`, 472 tests, all passing with leaks and bad frees promoted to
failures; `odin check -vet -strict-style` clean on every package. 23
components have a client half: avatar, calendar, carousel, checkbox,
collapsible, copybutton, datepicker, dialog, dropdown, input, inputotp, label,
popover, progress, rating, selectbox, sidebar, slider, tabs, tagsinput,
textarea, timepicker, toast — each with a `*.contract.json` and a contract
test. The other 19 are server only. No tag; nothing pins this repository yet.

**The collection layout is odin-rdf's**: each collection is a repository root,
`-collection:html=../odin-html-builder` and `-collection:ui=<this repository>`,
so imports read `html:html/h`, `html:html/a`, `html:html/hx` and `ui:ui/button`.
This repository is its own `ui:` collection because components compose each
other — sheet is built on dialog and sidebar on sheet, most components take
icon or button, and the pickers compose popover's root, trigger and content.

**What the port left, known and stated in the sources:**

- **No class merging.** templui pipes every class list through a Tailwind
  merge, so a caller's class beats a variant default; here the parts are
  concatenated and the stylesheet's source order decides a collision. A
  collision likely enough to meet — button's `justify` — is a prop instead.
- **`href` is written verbatim.** templ's safe-URL check has no equivalent in
  the builder's attribute package yet, so an `href` built from user input is
  the caller's to sanitise.
- **The legacy attribute vocabulary is being retired.** `data-tui-*` (upstream's)
  gives way to `data-oh-*` component by component; a ported component keeps its
  configuration where the server already rendered it.

### Dependency on odin-html-builder

The one dependency, reached as a sibling checkout through the `html:`
collection and never vendored. The kit uses three of its packages: `html/h`
(elements, open components and their deferred close, rendering to an
`io.Writer`), `html/a` (attributes, joined and conditionally emitted) and
`html/hx` (the htmx 4 attribute vocabulary, which is why `layout` loads htmx
4). Dependencies point downward only: a capability the components need from
the builder is asked of the builder with evidence, never worked around here.
The builder has no release yet, so CI checks out its `main`; the first tag
becomes the pin, and from then on a bump is a deliberate commit.

### The authoring model

`web/src/ui/README.md` is the checklist and the authority; a new component is
reviewed against it. In short:

- **The prefix is `oh-`, fixed and not configurable** (the owner's decision,
  2026-10-17): elements `oh-<name>`, attributes `data-oh-<name>-*` (Tailwind
  variants `data-[oh-…]` with them), TypeScript classes `Oh<Name>`. It names
  where the elements come from — odin-html — and keeps the library's names
  out of a consumer's own namespace. Until that day the prefix was `v-`; the
  rename landed before the first commit, so no released markup ever carried
  it.
- **The decision tree.** Does the component need client behaviour? Most do
  not, and are `ui/foo/foo.odin` alone. If it does, can the platform do it?
  Use that first and re-ask. Only then: the Odin package wraps its unchanged
  output in `<oh-foo>`, `web/src/ui/foo.ts` is one class registered as
  `oh-foo`, `web/src/ui/foo.contract.json` declares what the class reads, and
  `ui/foo/foo_test.odin` asserts it.
- **The rules.** Current evergreen browsers as the support floor, with a shim
  only for a gap in current browsers (`interestfor`). The wrapper carries an
  explicit display utility (`contents` or `block`), since an unknown element
  is inline until upgrade. Markup works before upgrade. `data-oh-*` names the
  roles the handlers match. Listeners live on `this`, so a swap inside the
  element needs no re-initialisation; teardown only for what outlives the
  node. Fields hold view state only; state that must survive a swap lives on
  an ancestor outside the swap target. Instances coordinate through a module
  registry, never a per-event document scan. No shadow DOM.
- **The lifecycle hazards, measured.** An htmx `outerHTML` swap connects the
  incoming element before disconnecting the outgoing one; a field on a
  wrapping element that points into the swap target retains the detached
  tree; pointer capture retargets the compatibility click.
- **The contract test.** The manifest declares the element name, its display
  utility, the selectors the class queries, the attributes it observes, and
  any value both sides compare. The class imports the manifest and reads its
  names from it, so it cannot quietly read what it does not declare; the Odin
  test reads the same file by `#directory` — no JavaScript toolchain — renders
  the component and asserts every declared name appears in the markup and the
  wrapper carries the declared display utility. A component composing another
  one's markup declares only its own names and the seam between them.
- **Browser checks are manual and not checked in**: written when a change
  needs them, run, recorded with the change, and let go.

## Future State

**Basecoat-inspired** — an open direction, stated and not yet decided in
detail. Today every component emits the Tailwind utility strings templui
wrote. The direction is for components to emit **Basecoat's component
classes** instead (`btn`, `btn-outline`, `card`, `badge`, `alert`, `input`, …):
the shadcn look expressed as a small set of semantic classes in a stylesheet,
where it is now a long utility string repeated in every component and in every
application that wants to match it.

What that would buy, if it holds: markup a reader can read; a caller's class
that composes with a component's instead of colliding with it, which retires
most of the no-class-merging hazard; a stylesheet that does not depend on
scanning Odin sources as text; and one place to restyle the kit.

What is open, and is decided when the direction becomes an initiative:

- whether the classes are Basecoat's own stylesheet taken as a dependency, a
  vendored copy, or this repository's classes modelled on it;
- how far the theme tokens already in `web/src/index.css` map onto Basecoat's;
- what happens to Basecoat's own JavaScript for interactive components, given
  this kit's `oh-*` elements and the platform-first rule;
- whether the golden tests, which restate templui's class tables on purpose,
  are rewritten per component or retired with the port's provenance;
- how a component Basecoat does not cover is styled, and the migration order.

## Success Criteria

- Every component renders complete, usable markup with no script loaded.
- Every component with a client half has a contract manifest and a test
  asserting it; the suite is green with leaks promoted to failures, and
  `odin check -vet -strict-style` is clean on every package.
- `odin-html-app` builds pages from the kit with the two collections and the
  built `web/dist`, and nothing else.
- The web half typechecks and builds from the lockfile.

## Principles

- **Libraries, not applications.** Building blocks; policy stays with the
  consumer.
- **The server renders; the client enhances.** Never the reverse.
- **The platform before a script**, and a shim only for a gap in current
  browsers, retired as they ship.
- **Measured, not reasoned**, for anything about browser behaviour.
- **Consume the builder's interface, do not bypass it**; a gap becomes an
  evidence-backed request below.
- **Idiomatic Odin**: explicit memory, allocator awareness, contract-level doc
  comments on public procedures.

## Constraints

- One dependency in Odin, odin-html-builder, as a sibling checkout through a
  collection — never vendored.
- The support floor is current evergreen browsers, as policy.
- No shadow DOM: global styles must apply and htmx must swap inside elements.
- No browser automation checked in.
- Public repository: needs are stated against the placeholder consumer,
  `odin-html-app`.
