/* The page shell: the document every page is written inside, and the head it carries. */
package layout

import "html:html/a"
import "html:html/h"

@(private)
BODY_BASE :: "min-h-screen bg-background text-foreground"

/*
The document every page is written inside.

item_page :: proc(view: Item) {
    {layout.document(view.name)
        {h.h1(); h.text(view.name)}
    }
}
*/
@(deferred_none = h.close_all)
document :: proc(title: string) {
	h.doctype()

	{h.open_scope()
		{h.html_open(a.lang("en"))
			{h.head()
				{h.meta(a.charset("utf-8"))}
				{h.meta(a.name("viewport"), a.content("width=device-width, initial-scale=1"))}
				{h.title()
					h.text(title)
				}
				stylesheet()
				scripts()
			}
			{h.body_open(a.class(BODY_BASE))}
		}
	}
}

/* Tied to -debug rather than given its own build mode, because a debug build is
already what separates development from a release. Overridable
for the case the default gets it wrong: -define:VITE_DEV=false in a debug build
that should not depend on a dev server running. */
@(private)
VITE_DEV :: #config(VITE_DEV, ODIN_DEBUG)

@(private)
VITE_ORIGIN :: #config(VITE_ORIGIN, "http://localhost:5173")

/* Passed in by the release build as -define:STYLESHEET=... and -define:BUNDLE=...,
read out of the manifest Vite writes (build.manifest in web/vite.config.ts): a
release links /assets/index-B7xK2m.css, and the hash is what lets the server
send a year of immutable cache on it.

The default is the unhashed name, which no build produces and every other build
compiles: check, test and a debug binary all reach these constants, and none of
them has a manifest to read. A debug page never asks for either -- VITE_DEV
sends it to the dev server above -- so the default is what a constant needs to
exist rather than a path anything fetches. A release built by hand, without the
defines, is the one case where it is a live wrong answer: it renders a link to a
file that is not there, and the page loads unstyled rather than failing. */
@(private)
STYLESHEET :: #config(STYLESHEET, "/assets/index.css")

// Every component's script, as one bundle.
@(private)
BUNDLE :: #config(BUNDLE, "/assets/index.js")

/* Written into <head>. Everything a page needs to be styled, which in dev is
also everything it needs to restyle itself. */
@(private)
stylesheet :: proc() {
	when VITE_DEV {
		// Served at the root because vite.config.ts sets root: 'src'.
		{ h.link(a.rel("stylesheet"), a.href(VITE_ORIGIN + "/index.css")) }

		/* The client is the whole reason dev is a script tag and not just a
		link: it opens the socket that pushes a rebuilt stylesheet. Without it
		the link above still works, it just goes stale until a reload. */
		{ h.script(a.type("module"), a.src(VITE_ORIGIN + "/@vite/client")) }
	} else {
		{ h.link(a.rel("stylesheet"), a.href(STYLESHEET)) }
	}
}

/* htmx, from the CDN in every build rather than through Vite, because nothing
in web/src imports it: what drives it is the hx-* attributes the server writes,
so it has no place in a module graph and would only be a bundle it does not need
to be in. The integrity hash is what makes a third-party origin acceptable --
the browser refuses a script the hash does not match, so jsdelivr can serve this
URL but cannot change what it means.

Vendoring it into our own bundle is the alternative and stays open; the day it
is worth doing is the day the CDN is a dependency worth removing, not this one.

Pinned to a beta on purpose: htmx 4 is what odin-html-builder's html/hx
generates attributes for, and 3 spells half of them differently. */
@(private)
HTMX :: "https://cdn.jsdelivr.net/npm/htmx.org@4.0.0-beta6"

@(private)
HTMX_INTEGRITY :: "sha384-6lyVbhrs13b9z7mLOpt/N6R76rtkEBWgCjAXRs/DSWyi2AMnQSs10ijWk+PI8n7W"

/* htmx's own configuration, which it reads from this meta once, as the script
below starts -- so the two are written together and in this order.

transitions runs every swap inside document.startViewTransition, which is what
makes a view-transition-name a page puts on its elements mean something: the
elements the old and new content share morph into their new positions instead
of being replaced. It is global rather than per swap: htmx 4 ands the
`transition:true` swap modifier with this, so the modifier alone does nothing
and this alone is enough.

The key:value form rather than JSON. htmx parses either -- content starting
with { is read as JSON -- and this one is a document written for reading. */
@(private)
HTMX_CONFIG :: "transitions:true"

@(private)
scripts :: proc() {
	{ h.meta(a.name("htmx-config"), a.content(HTMX_CONFIG)) }

	// Ahead of the bundle, which is a module and therefore deferred: htmx has
	// processed the document before anything in web/src runs.
	{h.script(a.src(HTMX), a.integrity(HTMX_INTEGRITY), a.crossorigin("anonymous"))}

	when VITE_DEV {
		{ h.script(a.type("module"), a.src(VITE_ORIGIN + "/index.ts")) }
	} else {
		{ h.script(a.type("module"), a.src(BUNDLE)) }
	}
}
