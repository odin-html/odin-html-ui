/* Tests for toggle -- templui's switch, renamed because switch is an Odin
keyword. In the package and beside the component; see button/button_test.odin
for why the class strings are restated rather than referenced. */
package toggle

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
TG_LABEL :: "inline-flex cursor-pointer items-center gap-2"

@(private = "file")
TG_TRACK ::
	"relative inline-flex h-5 w-9 shrink-0 cursor-pointer items-center " +
	"rounded-full border-2 border-transparent " +
	"transition-colors " +
	"bg-input peer-checked:bg-primary " +
	"peer-focus-visible:outline-none peer-focus-visible:ring-2 " +
	"peer-focus-visible:ring-ring peer-focus-visible:ring-offset-2 " +
	"peer-focus-visible:ring-offset-background " +
	"peer-disabled:cursor-not-allowed peer-disabled:opacity-50 " +
	"after:pointer-events-none after:block " +
	"after:h-4 after:w-4 " +
	"after:rounded-full after:bg-background " +
	"after:shadow-lg after:ring-0 " +
	"after:transition-transform " +
	"after:content-[&#39;&#39;] " +
	"peer-checked:after:translate-x-4"

/* All three elements in one expectation: the label, the hidden peer, and the
track that renders every visible state from it. */
@(test)
test_toggle_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toggle() }
	})
	testing.expect_value(
		t,
		out,
		`<label class="` +
		TG_LABEL +
		`">` +
		`<input type="checkbox" value="on" class="peer sr-only" role="switch">` +
		`<div class="` +
		TG_TRACK +
		`" aria-hidden="true"></div>` +
		`</label>`,
	)
}

/* No id, no `for`, and no invented one either. Upstream generates a random ID
so it can write a `for`; nesting the input inside the label associates them
without one, which keeps the same call rendering the same bytes twice. */
@(test)
test_toggle_without_an_id_writes_no_for :: proc(t: ^testing.T) {
	first := rendered(t, proc() {
			{ toggle({name = "notify"}) }
		})
	second := rendered(t, proc() {
		{ toggle({name = "notify"}) }
	})
	testing.expect_value(t, first, second)
	testing.expect(t, !strings.contains(first, "for="))
	testing.expect(t, !strings.contains(first, "id="))
}

@(test)
test_toggle_with_an_id_writes_for_and_id :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toggle({id = "notify", name = "notify"}) }
	})
	testing.expect(t, strings.has_prefix(out, `<label for="notify" class="`))
	testing.expect(t, strings.contains(out, `<input id="notify" name="notify" type="checkbox"`))
}

/* sr-only rather than hidden, so the input keeps its place in the tab order --
upstream's display:none made the switch unreachable by keyboard and its own
peer-focus-visible rules dead. */
@(test)
test_toggle_input_is_focusable_not_display_none :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toggle({name = "n"}) }
	})
	testing.expect(t, strings.contains(out, `class="peer sr-only"`))
	// Not a bare "hidden" search: the track carries aria-hidden.
	testing.expect(t, !strings.contains(out, "peer hidden"))
}

/* Bare booleans, and the label gains a cursor when disabled -- upstream's
utils.If, which is a.class dropping the empty part here. */
@(test)
test_toggle_checked_and_disabled :: proc(t: ^testing.T) {
	off := rendered(t, proc() {
		{ toggle({name = "n"}) }
	})
	testing.expect(t, !strings.contains(off, " checked"))
	testing.expect(t, !strings.contains(off, "cursor-not-allowed\""))

	on := rendered(t, proc() {
		{ toggle({name = "n", checked = true, disabled = true}) }
	})
	testing.expect(t, strings.has_prefix(on, `<label class="` + TG_LABEL + ` cursor-not-allowed">`))
	testing.expect(t, strings.contains(on, ` checked disabled class="peer sr-only"`))
}

/* value is written whether or not the caller gave one, "on" being what a
browser would submit anyway -- stated rather than implied. */
@(test)
test_toggle_value :: proc(t: ^testing.T) {
	def := rendered(t, proc() {
		{ toggle({name = "n"}) }
	})
	testing.expect(t, strings.contains(def, `value="on"`))

	given := rendered(t, proc() {
		{ toggle({name = "n", value = "yes"}) }
	})
	testing.expect(t, strings.contains(given, `value="yes"`))
	testing.expect(t, !strings.contains(given, `value="on"`))
}

/* The two halves that are easy to get backwards: Props.class styles the track,
attrs land on the input. */
@(test)
test_toggle_class_goes_to_the_track_and_attrs_to_the_input :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toggle({name = "n", class = "h-6 w-11"}, hx.post("/notify"), a.aria("label", "Notify")) }
	})
	testing.expect(t, strings.contains(out, `role="switch" hx-post="/notify" aria-label="Notify">`))
	testing.expect(t, strings.contains(out, ` peer-checked:after:translate-x-4 h-6 w-11" aria-hidden="true">`))
	testing.expect(t, !strings.contains(out, `<label class="` + TG_LABEL + ` h-6`))
}

/* role="switch" on a checkbox is what makes it announce as a switch rather than
a tick box, and attrs is spread last so a caller can still take it back. */
@(test)
test_toggle_role_is_overridable :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toggle({name = "n"}, a.role("checkbox")) }
	})
	testing.expect(t, strings.contains(out, `role="checkbox"`))
	testing.expect(t, !strings.contains(out, `role="switch"`))
}

@(test)
test_toggle_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toggle({name = "a"}) }
		{ toggle({name = "b"}) }
	})
	testing.expect_value(t, strings.count(out, "<label "), 2)
	testing.expect_value(t, strings.count(out, "</label>"), 2)
	testing.expect(t, strings.contains(out, "</div></label><label "))
}
