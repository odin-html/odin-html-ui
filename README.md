# odin-html-ui

[![CI](https://github.com/odin-html/odin-html-ui/actions/workflows/ci.yml/badge.svg)](https://github.com/odin-html/odin-html-ui/actions/workflows/ci.yml)

Server-rendered UI components for Odin, written through
[odin-html-builder](https://github.com/odin-html/odin-html-builder). The kit is
shadcn-style — Tailwind utilities over a small set of theme tokens — and was
ported from [templui](https://templui.io) component by component, with its
markup kept. Its direction is [Basecoat](https://basecoatui.com)-inspired:
semantic component classes in place of long utility strings.

Two halves in one repository:

- **`ui/`** — the components, one Odin package each. A component writes
  complete markup; the page works with no script loaded.
- **`web/`** — for the components that need browser behaviour, an `oh-*`
  custom element (TypeScript) that **enhances the markup the server rendered
  and never supplies it**, plus the Tailwind stylesheet. A `*.contract.json`
  beside each element names what it reads from the markup, and the Odin tests
  assert the rendered output against it.

Ported, tested, unreleased.

## A static component

```odin
import "html:html/h"
import "ui:ui/badge"

status :: proc() {
	{badge.badge({variant = .Secondary})
		h.text("Draft")
	}
}
```

renders (the class list trimmed here; it is 27 utilities)

```html
<span class="inline-flex items-center justify-center rounded-md border px-2 py-0.5 text-xs … bg-secondary text-secondary-foreground [a&amp;]:hover:bg-secondary/90">Draft</span>
```

Every component that takes children is an *open* component: it returns with
its element open, and the braces at the call site close it. They are not
optional — see `html/h/component.odin` in the builder.

## An interactive component

```odin
import "ui:ui/tabs"

settings :: proc() {
	{tabs.tabs({id = "settings"})
		{tabs.list({tabs_id = "settings"})
			{tabs.trigger({tabs_id = "settings", value = "general", is_active = true})
				h.text("General")
			}
			{tabs.trigger({tabs_id = "settings", value = "keys"})
				h.text("API keys")
			}
		}
		{tabs.content({tabs_id = "settings", value = "general", is_active = true})
			h.text("Name, email, time zone.")
		}
		{tabs.content({tabs_id = "settings", value = "keys"})
			h.text("No keys yet.")
		}
	}
}
```

renders (class lists trimmed to `…`)

```html
<oh-tabs class="contents"><div id="settings" class="flex flex-col gap-2" data-oh-tabs="root" data-oh-tabs-id="settings">
  <div class="…" data-oh-tabs="list" data-oh-tabs-id="settings">
    <button type="button" class="…" data-oh-tabs="trigger" data-oh-tabs-id="settings" data-oh-tabs-value="general" data-oh-tabs-state="active">General</button>
    <button type="button" class="…" data-oh-tabs="trigger" data-oh-tabs-id="settings" data-oh-tabs-value="keys" data-oh-tabs-state="inactive">API keys</button>
  </div>
  <div class="flex-1 outline-none" data-oh-tabs="content" data-oh-tabs-id="settings" data-oh-tabs-value="general" data-oh-tabs-state="active">Name, email, time zone.</div>
  <div class="flex-1 outline-none hidden" data-oh-tabs="content" data-oh-tabs-id="settings" data-oh-tabs-value="keys" data-oh-tabs-state="inactive">No keys yet.</div>
</div></oh-tabs>
```

(line breaks added; the render writes no whitespace between tags).

Before the script loads this is a correct page showing the active panel. When
the bundle loads, `<oh-tabs>` upgrades and switches panels on click by flipping
`data-oh-tabs-state` and the `hidden` class — the names declared in
`web/src/ui/tabs.contract.json`. The element adds no markup, so an htmx swap
inside it needs no re-initialisation.

## Using it

Check out both repositories side by side (the family's
[`init.sh`](https://github.com/odin-html/.github) does it) and declare both
collections, each a repository root:

```sh
odin build . -collection:html=../odin-html-builder -collection:ui=../odin-html-ui
```

Both are needed even if your code imports only `ui:` — the components import
`html:`, and a collection resolves in the importing compilation.

Build the client half with [Bun](https://bun.sh):

```sh
make web-install   # bun install --frozen-lockfile in web/
make web           # typecheck, then build web/dist
```

This writes one stylesheet and one module bundle, content-hashed, to
`web/dist/assets/`, which your server serves at `/assets`. The Tailwind build
scans `ui/` for the utilities the components name.

`ui/layout` is the page shell that links them:

```odin
import "ui:ui/layout"

page :: proc() {
	{layout.document("Settings")
		{h.h1(); h.text("Settings")}
		settings()
	}
}
```

writes the doctype, `<head>` (charset, viewport, title, the stylesheet, htmx 4
from its CDN with an integrity hash, the bundle) and opens
`<body class="min-h-screen bg-background text-foreground">`. In a `-debug`
build it links the Vite dev server (`bun run dev` in `web/`) instead. In a
release, pass the hashed names from `web/dist/.vite/manifest.json`:

```sh
odin build . -o:speed … -define:STYLESHEET=/assets/index-<hash>.css -define:BUNDLE=/assets/index-<hash>.js
```

## Components

Server only: accordion, alert, aspectratio, badge, breadcrumb, button, card,
form, hovercard, icon, layout, pagination, radio, separator, sheet, skeleton,
table, toggle, tooltip.

With an `oh-*` element: avatar, calendar, carousel, checkbox, collapsible,
copybutton, datepicker, dialog, dropdown, input, inputotp, label, popover,
progress, rating, selectbox, sidebar, slider, tabs, tagsinput, textarea,
timepicker, toast.

Each package's file comment documents its props and call shape.

## Authoring a component

[`web/src/ui/README.md`](web/src/ui/README.md) is the checklist a new
component is reviewed against: when a script is allowed at all (the platform
first), the `oh-` naming, the wrapper's display utility, the lifecycle rules,
and the contract test.

## Testing

```sh
make test    # every component's tests, leaks as failures (no Bun needed)
make check   # vet every package with -vet -strict-style, and the import-alias rule
make web     # typecheck the custom elements and build web/dist
```

odin-html-builder is expected beside this checkout; set `ODIN_HTML_ROOT` to
point elsewhere.

## License

MIT — see [LICENSE](LICENSE).
