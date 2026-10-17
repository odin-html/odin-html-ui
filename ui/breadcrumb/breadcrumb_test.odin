/* Tests for breadcrumb, in the package rather than in a test package of their own, so a
ported component carries its tests beside it.

Everything here still goes through the public API: what is worth testing is the
composition -- where the separator sits, which tag each component chose, which
scope its closing tag landed in -- none of which a unit test of a private proc
reaches.

The class tables are restated rather than referenced, and being in the package
now makes that a choice rather than a necessity. The duplication is the point:
these are golden tests against templui's output, and a table that changed on
both sides at once would prove nothing. */
package breadcrumb

import "core:strings"
import "core:testing"

import "html:html/a"
import "html:html/h"
import "html:html/hx"

@(private = "file")
rendered :: proc(t: ^testing.T, body: proc()) -> string {
	out, err := h.render_to_string(body, context.temp_allocator)
	testing.expect_value(t, err, nil)
	return out
}

@(private = "file")
BC_LIST :: "flex items-center flex-wrap gap-1 text-sm"
@(private = "file")
BC_ITEM :: "flex items-center"
@(private = "file")
BC_LINK ::
	"text-muted-foreground hover:text-foreground hover:underline " + "flex items-center gap-1.5 transition-colors"
@(private = "file")
BC_SEP :: "mx-2 text-muted-foreground"
@(private = "file")
BC_PAGE :: "font-medium text-foreground flex items-center gap-1.5"

/* The chevron as separator() writes it: the icon package's fixed attributes,
the breadcrumb's own class, and the aria-hidden this port adds. */
@(private = "file")
BC_CHEVRON ::
	`<svg viewBox="0 0 24 24" class="icon size-3.5 text-muted-foreground" aria-hidden="true">` +
	`<path d="m9 18 6-6-6-6" /></svg>`

/* The whole trail in one expectation, so the nesting is pinned in one place --
including that the separator sits inside the item it precedes rather than
between items, which is the part of upstream's shape most likely to be got
wrong. */
@(test)
test_breadcrumb_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{breadcrumb()
			{list()
				{item()
					{ link({href = "/"}); h.text("Home") }
				}
				{item()
					{ separator() }
					{ page(); h.text("Components") }
				}
			}
		}
	})
	testing.expect_value(
		t,
		out,
		`<nav class="flex" aria-label="Breadcrumb">` +
		`<ol class="` +
		BC_LIST +
		`">` +
		`<li class="` +
		BC_ITEM +
		`"><a href="/" class="` +
		BC_LINK +
		`">Home</a></li>` +
		`<li class="` +
		BC_ITEM +
		`"><span class="` +
		BC_SEP +
		`">` +
		BC_CHEVRON +
		`</span><span class="` +
		BC_PAGE +
		`" aria-current="page">Components</span></li>` +
		`</ol></nav>`,
	)
}

/* separator() takes no children, so nothing a caller writes after it lands
inside -- it is a complete span, not an _open component. The text below is a
sibling of the separator, inside the item. */
@(test)
test_breadcrumb_separator_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{item()
				{ separator() }
				h.text("after")
			}
		})
	testing.expect_value(
		t,
		out,
		`<li class="` + BC_ITEM + `"><span class="` + BC_SEP + `">` + BC_CHEVRON + `</span>after</li>`,
	)
}

/* Upstream's UseCustom branch, as a proc of its own: the caller's glyph and no
chevron. The flag it replaces could not have worked here -- children are the
caller's block and run either way -- so this is also the test that the two cases
cannot be combined by accident. */
@(test)
test_breadcrumb_separator_custom :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{separator_custom()
				h.text("/")
			}
		})
	testing.expect_value(t, out, `<span class="` + BC_SEP + `">/</span>`)
	testing.expect(t, !strings.contains(out, "<svg"))
}

/* An anchor with no href, which is what upstream renders when Href is unset:
not focusable and not a link. Pinned because it looks like a link on screen. */
@(test)
test_breadcrumb_link_without_href :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ link(); h.text("Nowhere") }
	})
	testing.expect_value(t, out, `<a class="` + BC_LINK + `">Nowhere</a>`)
	testing.expect(t, !strings.contains(out, "href"))
}

/* aria-current is unconditional. Upstream's ItemProps.Current is dropped in
this port precisely because it never reached the markup -- Page marked the
current page whether or not a caller set it, and upstream's own showcases set
it. */
@(test)
test_breadcrumb_page_is_always_current :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ page(); h.text("Here") }
	})
	testing.expect_value(t, out, `<span class="` + BC_PAGE + `" aria-current="page">Here</span>`)
}

@(test)
test_breadcrumb_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{breadcrumb({id = "trail", class = "mb-4"})
			{list({id = "trail-l", class = "gap-2"})
				{item({id = "trail-i", class = "shrink-0"})
					{link({id = "trail-a", class = "font-mono", href = "/"})
						h.text("Home")
					}
					{ separator({id = "trail-s", class = "mx-1"}) }
					{page({id = "trail-p", class = "truncate"})
						h.text("Here")}
				}
			}
		}
	})
	testing.expect(t, strings.has_prefix(out, `<nav id="trail" class="flex mb-4" aria-label="Breadcrumb">`))
	testing.expect(t, strings.contains(out, `<ol id="trail-l" class="` + BC_LIST + ` gap-2">`))
	testing.expect(t, strings.contains(out, `<li id="trail-i" class="` + BC_ITEM + ` shrink-0">`))
	testing.expect(t, strings.contains(out, `<a id="trail-a" href="/" class="` + BC_LINK + ` font-mono">`))
	testing.expect(t, strings.contains(out, `<span id="trail-s" class="` + BC_SEP + ` mx-1">`))
	testing.expect(
		t,
		strings.contains(out, `<span id="trail-p" class="` + BC_PAGE + ` truncate" aria-current="page">`),
	)
}

/* The nav's label is a default, not a fixture: two breadcrumbs on one page want
different ones, and attrs is spread last so a caller wins. */
@(test)
test_breadcrumb_label_is_overridable :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{breadcrumb({}, a.aria("label", "Category trail"), hx.get("/trail"))
				h.text("x")
			}
		})
	testing.expect_value(t, out, `<nav class="flex" aria-label="Category trail" hx-get="/trail">x</nav>`)
}

/* Three items in a row, so each _open component closed back to its own mark
rather than dragging a sibling's close early. */
@(test)
test_breadcrumb_items_are_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{list()
			{item()
				{ link({href = "/"}); h.text("One") }
			}
			{item()
				{ separator() }
				{ link({href = "/two"}); h.text("Two") }
			}
			{item()
				{ separator() }
				{ page(); h.text("Three") }
			}
		}
	})
	testing.expect_value(t, strings.count(out, "<li "), 3)
	testing.expect_value(t, strings.count(out, "</li>"), 3)
	testing.expect_value(t, strings.count(out, "<svg "), 2) // no separator on the first
	testing.expect(t, strings.contains(out, "One</a></li><li "))
	testing.expect(t, strings.has_suffix(out, "Three</span></li></ol>"))
}
