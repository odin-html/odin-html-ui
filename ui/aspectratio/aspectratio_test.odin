/* Tests for aspectratio, in the package and beside the component -- see
button/button_test.odin for why the class strings are restated rather than
referenced. */
package aspectratio

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
AR_BASE :: "relative w-full"
@(private = "file")
AR_INNER :: "absolute inset-0"

/* Both divs and the nesting in one expectation: the children belong to the
inner one, and the outer carries the ratio. */
@(test)
test_aspectratio_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{aspect_ratio({ratio = .Video})
			h.text("content")
		}
	})
	testing.expect_value(
		t,
		out,
		`<div class="` + AR_BASE + ` aspect-video"><div class="` + AR_INNER + `">content</div></div>`,
	)
}

/* Upstream's zero value is the empty string, which falls through its switch to
the same class the explicit "auto" produces -- so Props{} here has to render
what an explicit .Auto does. */
@(test)
test_aspectratio_zero_props_is_auto :: proc(t: ^testing.T) {
	explicit := rendered(t, proc() {
			{aspect_ratio({ratio = .Auto})
				h.text("x")
			}
		})
	implicit := rendered(t, proc() {
		{aspect_ratio()
			h.text("x")
		}
	})
	testing.expect_value(t, explicit, implicit)
	testing.expect(t, strings.contains(implicit, "aspect-auto"))
}

@(test)
test_aspectratio_every_ratio :: proc(t: ^testing.T) {
	/* One literal per ratio rather than a loop: proc literals do not capture,
	so a loop over Ratio would render the default five times. */
	out := rendered(t, proc() {
		{ aspect_ratio({ratio = .Auto}); h.text("a") }
		{ aspect_ratio({ratio = .Square}); h.text("b") }
		{ aspect_ratio({ratio = .Video}); h.text("c") }
		{ aspect_ratio({ratio = .Portrait}); h.text("d") }
		{ aspect_ratio({ratio = .Wide}); h.text("e") }
	})
	testing.expect(t, strings.contains(out, "aspect-auto"))
	testing.expect(t, strings.contains(out, "aspect-square"))
	testing.expect(t, strings.contains(out, "aspect-video"))
	testing.expect(t, strings.contains(out, "aspect-[3/4]"))
	testing.expect(t, strings.contains(out, "aspect-[2/1]"))
	testing.expect_value(t, strings.count(out, AR_INNER), 5)
}

/* id and class land on the outer div; the inner one carries its own class and
nothing else, which is what keeps it pinned. */
@(test)
test_aspectratio_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{aspect_ratio({id = "hero", class = "rounded-xl", ratio = .Wide}, hx.get("/hero"))
			h.text("x")
		}
	})
	testing.expect_value(
		t,
		out,
		`<div id="hero" class="` +
		AR_BASE +
		` aspect-[2/1] rounded-xl" hx-get="/hero"><div class="` +
		AR_INNER +
		`">x</div></div>`,
	)
}

/* Two in a row, so close_all closed both divs of the first back to its own mark
before the second opened. */
@(test)
test_aspectratio_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ aspect_ratio({ratio = .Square}); h.text("one") }
			{ aspect_ratio({ratio = .Video}); h.text("two") }
		})
	testing.expect_value(t, strings.count(out, "<div "), 4)
	testing.expect_value(t, strings.count(out, "</div>"), 4)
	testing.expect(t, strings.contains(out, "one</div></div><div "))
	testing.expect(t, strings.has_suffix(out, "two</div></div>"))
}

/* An element as children rather than text, which is the real use: it lands
inside the inner div, not between the two. */
@(test)
test_aspectratio_element_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{aspect_ratio({ratio = .Video})
			{ h.img(a.src("/still.png"), a.class("size-full object-cover")) }
		}
	})
	testing.expect(
		t,
		strings.contains(out, `<div class="` + AR_INNER + `"><img src="/still.png" class="size-full object-cover">`),
	)
}
