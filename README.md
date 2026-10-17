# odin-html-ui

Server-rendered UI components for Odin: accordion, alert, badge, button, card,
dialog, tabs, toast and about thirty-five more, each one Odin package under
`ui/` that writes its markup through
[odin-html-builder](https://github.com/odin-html/odin-html-builder). The kit
is shadcn-style — Tailwind utilities over a small set of theme tokens — and was
ported from [templui](https://templui.io), component by component, with its
markup kept.

A component that needs browser behaviour has a client half in `web/src/ui`: an
`oh-*` custom element that **enhances markup the server already rendered** and
never supplies it. The page works before the script loads; the element adds
what only a browser can. Most of the kit needs no script at all.

## Status: ported, tested, unreleased

42 packages under `ui/`, 472 tests across them, all green. 23 components have a
client half, each with a contract manifest its Odin test asserts against the
rendered markup (below). No tag yet.

| | Components |
| --- | --- |
| **Server only** | accordion, alert, aspectratio, badge, breadcrumb, button, card, form, hovercard, icon, layout, pagination, radio, separator, sheet, skeleton, table, toggle, tooltip |
| **With an `oh-*` element** | avatar, calendar, carousel, checkbox, collapsible, copybutton, datepicker, dialog, dropdown, input, inputotp, label, popover, progress, rating, selectbox, sidebar, slider, tabs, tagsinput, textarea, timepicker, toast |

`layout` is the page shell — the document, its `<head>`, the stylesheet and
the bundle in development (through the Vite dev server) and in a release (the
hashed names passed in as `-define:STYLESHEET=…` and `-define:BUNDLE=…`).
`interestfor.ts` emulates the interest-invoker vocabulary for the hover
popovers (tooltip, hovercard, dropdown submenus) where the browser does not
have it yet.

## Using a component

Declare two collections, each a repository root, pointing at sibling
checkouts:

```
-collection:html=../odin-html-builder -collection:ui=../odin-html-ui
```

and import by repository and package:

```odin
import "html:html/h"
import "html:html/hx"
import "ui:ui/button"

save :: proc() {
	{button.button({variant = .Outline, size = .Sm}, hx.get("/save"))
		h.text("Save")
	}
}
```

A component that takes children is an *open* component: it returns with its
element open and the braces at the call site close it (see
`html/h/component.odin` in the builder). Both collections are needed even
where an application names only `ui:` — the components import `html:`, and a
collection resolves in the importing compilation, not in the imported
checkout.

The client half is built from `web/` into `web/dist/assets/`, one stylesheet
and one module bundle, which the application serves at `/assets`. The
stylesheet's Tailwind build scans `ui/` as text, so the utilities a component
names are the utilities that ship.

## Authoring a component

[`web/src/ui/README.md`](web/src/ui/README.md) is the checklist, and a new
component is reviewed against it. The short form:

- **No script unless the platform cannot do it.** `popover="auto"`,
  `<dialog>`, CSS anchor positioning, `:has`, `@starting-style` come first.
- A component that does need one wraps its unchanged markup in `<oh-foo>` with
  an explicit display utility (`contents` or `block`), and gets
  `web/src/ui/foo.ts` (one class, no shadow DOM, listeners on `this`) and
  `web/src/ui/foo.contract.json`.
- **The contract test** is what joins the two languages: the manifest declares
  the element, its display utility, and every selector, attribute and value
  both sides must agree on; `foo.ts` imports it and reads its names from it,
  and `foo_test.odin` reads the same file by `#directory`, renders the
  component and asserts every declared name is in the markup.

## Building

Needs Odin and, for `web/`, [Bun](https://bun.sh). odin-html-builder is
expected beside this checkout; `ODIN_HTML_ROOT` points elsewhere.

```
make test           # every component's tests (no Bun needed: the manifests are checked in)
make check          # vet every package with -vet -strict-style, then the import-alias rule
make web-install    # bun install --frozen-lockfile in web/
make web            # typecheck the custom elements, then build web/dist
make help           # the rest
```

A single package: `odin test ui/button -collection:html=../odin-html-builder -collection:ui=.`

## License

MIT — see [LICENSE](LICENSE).
