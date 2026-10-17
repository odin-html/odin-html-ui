/* Tests for radio, in the package and beside the component -- see
button/button_test.odin for why the class strings are restated rather than
referenced. */
package radio

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

/* The rendered form, not the source form: escape_attr turns ' into &#39;, so
the arbitrary value arrives escaped. */
@(private = "file")
RD_CLASS ::
	"relative h-4 w-4 " +
	"before:absolute before:left-1/2 before:top-1/2 " +
	"before:h-1.5 before:w-1.5 before:-translate-x-1/2 before:-translate-y-1/2 " +
	"appearance-none rounded-full " +
	"border-2 border-primary " +
	"before:content[&#39;&#39;] before:rounded-full before:bg-background " +
	"checked:border-primary checked:bg-primary " +
	"checked:before:visible " +
	"focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-ring " +
	"focus-visible:ring-offset-2 focus-visible:ring-offset-background " +
	"disabled:cursor-not-allowed"

@(test)
test_radio_default :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ radio() }
	})
	testing.expect_value(t, out, `<input type="radio" class="` + RD_CLASS + `">`)
}

/* A void element: no closing tag, and nothing can go inside it. */
@(test)
test_radio_is_void :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ radio({name = "size"}) }
		h.text("after")
	})
	testing.expect(t, !strings.contains(out, "</input>"))
	testing.expect(t, strings.has_suffix(out, ">after"))
}

/* name is what makes two radios alternatives rather than two independent
toggles, so it is the field worth pinning. */
@(test)
test_radio_name_value_and_form :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ radio({id = "sm", name = "size", value = "small", form = "prefs"}) }
	})
	testing.expect(
		t,
		strings.has_prefix(out, `<input type="radio" id="sm" name="size" value="small" form="prefs" class="`),
	)
}

/* Bare booleans: absent rather than checked="false", which would check it. */
@(test)
test_radio_checked_and_disabled :: proc(t: ^testing.T) {
	off := rendered(t, proc() {
			{ radio({name = "size"}) }
		})
	/* " checked " with the spaces: the class list is full of checked: and
	disabled: variants, and a bare substring search finds those instead. */
	testing.expect(t, !strings.contains(off, " checked "))
	testing.expect(t, !strings.contains(off, " disabled "))

	on := rendered(t, proc() {
		{ radio({name = "size", checked = true, disabled = true}) }
	})
	testing.expect(t, strings.contains(on, `name="size" checked disabled class=`))
	testing.expect(t, !strings.contains(on, `checked="`))
}

/* Upstream's class list says content[''] where Tailwind spells it content-[''],
so that one class emits no CSS. It costs nothing -- the before: variant supplies
a content property by itself -- and it is kept verbatim rather than corrected.
This test is what says the port did not quietly fix it, and is the one to change
if upstream does. */
@(test)
test_radio_keeps_upstreams_malformed_content_utility :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ radio() }
	})
	testing.expect(t, strings.contains(out, "before:content[&#39;&#39;]"))
	testing.expect(t, !strings.contains(out, "before:content-["))
}

@(test)
test_radio_class_appended_and_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ radio({name = "size", class = "mr-2"}, hx.post("/prefs"), a.aria("label", "Small")) }
	})
	testing.expect(t, strings.contains(out, ` disabled:cursor-not-allowed mr-2"`))
	testing.expect(t, strings.has_suffix(out, ` hx-post="/prefs" aria-label="Small">`))
}

/* A group as it is actually written: same name, different values, one checked. */
@(test)
test_radio_group :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ radio({name = "size", value = "sm"}) }
		{ radio({name = "size", value = "md", checked = true}) }
		{ radio({name = "size", value = "lg"}) }
	})
	testing.expect_value(t, strings.count(out, `name="size"`), 3)
	testing.expect_value(t, strings.count(out, " checked "), 1)
}
