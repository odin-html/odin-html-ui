/* Tests for separator, in the package and beside the component -- see
button/button_test.odin for why the class strings are restated rather than
referenced. */
package separator

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
SEP_H_OUTER :: "shrink-0 w-full"
@(private = "file")
SEP_H_INNER :: "relative flex items-center w-full"
@(private = "file")
SEP_H_LINE :: "absolute w-full border-t h-[1px]"
@(private = "file")
SEP_H_LABEL :: "relative mx-auto bg-background px-2 text-xs text-muted-foreground"

@(private = "file")
SEP_V_OUTER :: "shrink-0 h-full"
@(private = "file")
SEP_V_LINE :: "absolute h-full border-l w-[1px]"

/* All four elements in one expectation, so the nesting is pinned: the line and
the label are siblings inside the inner div, and the children belong to the
label. */
@(test)
test_separator_horizontal_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{separator()
			h.text("or")
		}
	})
	testing.expect_value(
		t,
		out,
		`<div role="separator" aria-orientation="horizontal" class="` +
		SEP_H_OUTER +
		`"><div class="` +
		SEP_H_INNER +
		`"><span class="` +
		SEP_H_LINE +
		`" aria-hidden="true"></span><span class="` +
		SEP_H_LABEL +
		`">or</span></div></div>`,
	)
}

/* Horizontal is the zero value, matching upstream's normalizing prologue. */
@(test)
test_separator_zero_props_is_horizontal :: proc(t: ^testing.T) {
	explicit := rendered(t, proc() {
			{ separator({orientation = .Horizontal}); h.text("x") }
		})
	implicit := rendered(t, proc() {
			{ separator(); h.text("x") }
		})
	testing.expect_value(t, explicit, implicit)
}

/* The other branch opens different elements in a different scope, which is
expressible only because _open records the tag for the caller's close_all. */
@(test)
test_separator_vertical :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ separator({orientation = .Vertical}) }
	})
	testing.expect(
		t,
		strings.has_prefix(out, `<div role="separator" aria-orientation="vertical" class="` + SEP_V_OUTER + `">`),
	)
	testing.expect(t, strings.contains(out, `<span class="` + SEP_V_LINE + `" aria-hidden="true"></span>`))
	testing.expect(t, strings.has_suffix(out, "</span></div></div>"))
}

/* The label span is written whether or not there is a label, so an unlabelled
separator still paints a padded box over the middle of its own line. That is
upstream's behaviour and the reason a plain rule has a gap in it. */
@(test)
test_separator_empty_still_has_a_label_span :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ separator() }
	})
	testing.expect(t, strings.contains(out, `<span class="` + SEP_H_LABEL + `"></span>`))
}

@(test)
test_separator_decorations :: proc(t: ^testing.T) {
	none := rendered(t, proc() {
		{ separator({decoration = .None}) }
	})
	testing.expect(t, strings.contains(none, `class="` + SEP_H_LINE + `" aria-hidden`))
	testing.expect(t, !strings.contains(none, "border-dashed"))

	dashed := rendered(t, proc() {
		{ separator({decoration = .Dashed}) }
	})
	testing.expect(t, strings.contains(dashed, SEP_H_LINE + ` border-dashed"`))

	dotted := rendered(t, proc() {
		{ separator({decoration = .Dotted}) }
	})
	testing.expect(t, strings.contains(dotted, SEP_H_LINE + ` border-dotted"`))
}

/* The decoration lands on the line span, not the outer div, so Props.class
cannot reach it -- and neither can a caller's attrs. */
@(test)
test_separator_class_reaches_the_outer_div_only :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{separator({id = "or", class = "my-6"}, hx.get("/x"))
			h.text("or")
		}
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<div id="or" role="separator" aria-orientation="horizontal" class="` +
			SEP_H_OUTER +
			` my-6" hx-get="/x">`,
		),
	)
	testing.expect(t, strings.contains(out, `<span class="` + SEP_H_LINE + `" aria-hidden="true">`))
}

/* role is a default rather than a fixture: a separator that is decoration
rather than structure wants none, and attrs is spread last so a caller wins. */
@(test)
test_separator_role_is_overridable :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ separator({}, a.role("presentation")) }
	})
	testing.expect(t, strings.contains(out, `role="presentation"`))
	testing.expect(t, !strings.contains(out, `role="separator"`))
}

/* Two in a row: each closed its three elements back to its own mark. */
@(test)
test_separator_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ separator(); h.text("one") }
		{ separator(); h.text("two") }
	})
	testing.expect_value(t, strings.count(out, `role="separator"`), 2)
	testing.expect_value(t, strings.count(out, "<div "), 4)
	testing.expect_value(t, strings.count(out, "</div>"), 4)
	testing.expect(t, strings.contains(out, "one</span></div></div><div "))
}
