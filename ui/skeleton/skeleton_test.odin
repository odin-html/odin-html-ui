/* Tests for skeleton, in the package and beside the component -- see
button/button_test.odin for why the class strings are restated rather than
referenced. */
package skeleton

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
SK_BASE :: "animate-pulse rounded bg-muted"

@(test)
test_skeleton_default :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ skeleton() }
	})
	testing.expect_value(t, out, `<div class="` + SK_BASE + `"></div>`)
}

/* Empty, and that is the whole point of the note on the component: with no
content and no height from a class, this renders and occupies nothing. */
@(test)
test_skeleton_is_empty :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ skeleton({class = "h-4 w-32"}) }
	})
	testing.expect_value(t, out, `<div class="` + SK_BASE + ` h-4 w-32"></div>`)
	testing.expect(t, strings.has_suffix(out, "></div>"))
}

@(test)
test_skeleton_id_and_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ skeleton({id = "loading", class = "h-8"}, hx.get("/rows"), a.aria("hidden", "true")) }
	})
	testing.expect_value(
		t,
		out,
		`<div id="loading" class="` + SK_BASE + ` h-8" hx-get="/rows" aria-hidden="true"></div>`,
	)
}

/* Several in a row, which is how a loading placeholder is actually written --
and a check that each closed itself rather than nesting the next one. */
@(test)
test_skeleton_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ skeleton({class = "h-4 w-full"}) }
			{ skeleton({class = "h-4 w-2/3"}) }
		})
	testing.expect_value(t, strings.count(out, "<div "), 2)
	testing.expect_value(t, strings.count(out, "</div>"), 2)
	testing.expect(t, strings.contains(out, `w-full"></div><div `))
}

/* a.class replaces rather than appends, so the pulse and the colour go with it
-- the same footgun the icon package has. */
@(test)
test_skeleton_attrs_class_replaces_base :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ skeleton({class = "h-4"}, a.class("only-this")) }
	})
	testing.expect_value(t, out, `<div class="only-this"></div>`)
}
