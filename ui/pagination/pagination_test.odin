/* Tests for pagination, in the package and beside the component -- see
button/button_test.odin for why the class strings are restated rather than
referenced.

The button classes are not restated here, though: what matters at this level is
which variant and size pagination asked for, not what button renders for them,
and button's own tests pin that. */
package pagination

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
PG_NAV :: "flex flex-wrap justify-center"
@(private = "file")
PG_CONTENT :: "flex flex-row items-center gap-1"

@(test)
test_pagination_nav_and_list :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{pagination()
			{content()
				{item()
					h.text("x")
				}
			}
		}
	})
	testing.expect_value(
		t,
		out,
		`<nav role="navigation" aria-label="pagination" class="` +
		PG_NAV +
		`"><ul class="` +
		PG_CONTENT +
		`"><li>x</li></ul></nav>`,
	)
}

/* The item carries no class at all, as upstream's does not. */
@(test)
test_pagination_item_has_no_class :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{item({id = "p3"})
				h.text("3")
			}
		})
	testing.expect_value(t, out, `<li id="p3">3</li>`)
}

/* The reason button has an open(): link cannot call button(), whose close would
land at the end of link's own body -- before the page number. This is the test
that says the number ended up inside the anchor. */
@(test)
test_pagination_link_holds_its_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{link({href = "?p=3"})
			h.text("3")
		}
	})
	testing.expect(t, strings.has_prefix(out, `<a href="?p=3" class="`))
	testing.expect(t, strings.has_suffix(out, `">3</a>`))
}

/* Active is an outline where the rest are ghosts, which is the whole of "you
are here" -- so this checks the variant reached button rather than the classes
button chose for it. */
@(test)
test_pagination_link_active_and_inactive_differ :: proc(t: ^testing.T) {
	active := rendered(t, proc() {
		{ link({href = "?p=3", is_active = true}); h.text("3") }
	})
	inactive := rendered(t, proc() {
		{ link({href = "?p=4"}); h.text("4") }
	})
	testing.expect(t, strings.contains(active, "border bg-background"))
	testing.expect(t, !strings.contains(inactive, "border bg-background"))
	testing.expect(t, strings.contains(inactive, "hover:bg-accent"))
}

/* Disabled renders a button rather than an anchor and drops the href, because
an anchor cannot be disabled -- button's rule, inherited. */
@(test)
test_pagination_link_disabled_is_a_button :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ link({href = "?p=3", disabled = true}); h.text("3") }
	})
	testing.expect(t, strings.has_prefix(out, "<button "))
	testing.expect(t, !strings.contains(out, "href"))
	testing.expect(t, strings.contains(out, " disabled>"))
}

/* previous and next take no children: the chevron and the optional label are
all of them, and the chevron sits on the leading side of each. */
@(test)
test_pagination_previous_and_next :: proc(t: ^testing.T) {
	prev := rendered(t, proc() {
		{ previous({href = "?p=1", label = "Previous"}) }
	})
	testing.expect(t, strings.contains(prev, `<svg viewBox="0 0 24 24" class="icon size-4" aria-hidden="true">`))
	testing.expect(t, strings.has_suffix(prev, "<span>Previous</span></a>"))

	nxt := rendered(t, proc() {
		{ next({href = "?p=3", label = "Next"}) }
	})
	testing.expect(t, strings.contains(nxt, "<span>Next</span><svg "))
	testing.expect(t, strings.has_suffix(nxt, "</svg></a>"))
}

/* No label, no span -- just the chevron. */
@(test)
test_pagination_controls_without_labels :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ previous({href = "?p=1"}) }
	})
	testing.expect(t, !strings.contains(out, "<span>"))
	testing.expect(t, strings.contains(out, "<svg "))
}

@(test)
test_pagination_ellipsis :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ ellipsis() }
	})
	testing.expect_value(
		t,
		out,
		`<svg viewBox="0 0 24 24" class="icon size-4" aria-hidden="true">` +
		`<circle cx="12" cy="12" r="1" /> <circle cx="19" cy="12" r="1" /> <circle cx="5" cy="12" r="1" /></svg>`,
	)
}

@(test)
test_pagination_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{pagination({id = "pg", class = "mt-6"}, hx.get("/rows"), a.aria("label", "Results"))
				h.text("x")
			}
		})
	/* The overriding aria-label is emitted where the caller's copy sits --
	write_attrs keeps the later duplicate, in its own position -- so it lands
	after hx-get rather than back where the component set it. */
	testing.expect_value(
		t,
		out,
		`<nav id="pg" role="navigation" class="` + PG_NAV + ` mt-6" hx-get="/rows" aria-label="Results">x</nav>`,
	)
}

// ------------------------------------------------------------------- pages()

/* Fewer pages than the window: everything, and no windowing at all. */
@(test)
test_pages_shorter_than_the_window :: proc(t: ^testing.T) {
	r := pages(1, 3, 5)
	testing.expect_value(t, r.current, 1)
	testing.expect_value(t, r.total, 3)
	testing.expect_value(t, len(r.pages), 3)
	testing.expect_value(t, r.pages[0], 1)
	testing.expect_value(t, r.pages[2], 3)
	testing.expect(t, !r.has_previous)
	testing.expect(t, r.has_next)
}

/* Centred on the current page once there are more pages than fit. */
@(test)
test_pages_centres_the_window :: proc(t: ^testing.T) {
	r := pages(10, 20, 5)
	testing.expect_value(t, len(r.pages), 5)
	testing.expect_value(t, r.pages[0], 8)
	testing.expect_value(t, r.pages[4], 12)
	testing.expect(t, r.has_previous)
	testing.expect(t, r.has_next)
}

/* Pushed back inside the range at either end rather than running off it. */
@(test)
test_pages_clamps_the_window_at_both_ends :: proc(t: ^testing.T) {
	first := pages(1, 20, 5)
	testing.expect_value(t, first.pages[0], 1)
	testing.expect_value(t, first.pages[4], 5)
	testing.expect(t, !first.has_previous)

	last := pages(20, 20, 5)
	testing.expect_value(t, last.pages[0], 16)
	testing.expect_value(t, last.pages[4], 20)
	testing.expect(t, !last.has_next)
}

/* Out-of-range input is pulled into range rather than rejected, so a handler
can pass a query parameter straight in. */
@(test)
test_pages_clamps_its_arguments :: proc(t: ^testing.T) {
	low := pages(-5, 10, 5)
	testing.expect_value(t, low.current, 1)

	high := pages(99, 10, 5)
	testing.expect_value(t, high.current, 10)

	empty := pages(1, 0, 5)
	testing.expect_value(t, empty.total, 1)
	testing.expect_value(t, len(empty.pages), 1)

	defaulted := pages(3, 20, 0)
	testing.expect_value(t, len(defaulted.pages), 5)
}

/* An even max_visible gives one more page than asked for: the window is half on
each side plus the current page. Upstream's arithmetic, pinned rather than
corrected. */
@(test)
test_pages_even_max_visible_is_one_wider :: proc(t: ^testing.T) {
	r := pages(10, 20, 4)
	testing.expect_value(t, len(r.pages), 5)

	odd := pages(10, 20, 5)
	testing.expect_value(t, len(odd.pages), 5)
}
