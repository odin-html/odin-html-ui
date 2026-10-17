/* Tests for icon, in the package rather than in a test package of their own, so a
component carries its tests beside it.

Everything here goes through the public API. The expectations are restated
rather than referenced, and being in the package now makes that a choice: a test
that read the same table the component writes from would pass whatever the table
said. */
package icon

import "core:strings"
import "core:testing"

import "html:html/a"
import "html:html/h"

@(private = "file")
rendered :: proc(t: ^testing.T, body: proc()) -> string {
	out, err := h.render_to_string(body, context.temp_allocator)
	testing.expect_value(t, err, nil)
	return out
}

/* Everything upstream stamped on every icon is one class now, except the
viewBox -- which has no CSS property and is what makes a sized icon scale rather
than crop. See icon.odin.

The class attribute is load bearing beyond styling: the button's
[&_svg:not([class*='size-'])] selector reads it, and "icon" alone does not
contain "size-", so an unsized icon inside a button still gets sized by it. */
@(private = "file")
CHEVRON_BARE :: `<svg viewBox="0 0 24 24" class="icon"><path d="m6 9 6 6 6-6" /></svg>`

@(test)
test_icon_renders_lucide_body :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ icon(.Chevron_Down) }
	})
	testing.expect_value(t, out, CHEVRON_BARE)
}

/* The reason None exists. A component holding an icon in its Props can pass the
field straight through without guarding it, so this has to be nothing at all --
not an empty <svg>, which would still take up a flex slot and a border. */
@(test)
test_icon_none_renders_nothing :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ icon(.None) }
		{ icon(.None, {class = "size-4"}) }
	})
	testing.expect_value(t, out, "")
}

@(test)
test_icon_class_and_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ icon(.Plus, {class = "size-4 text-muted-foreground"}, a.aria("hidden", "true")) }
	})
	testing.expect(t, strings.contains(out, `class="icon size-4 text-muted-foreground"`))
	testing.expect(t, strings.has_suffix(out, `aria-hidden="true"><path d="M5 12h14" /> <path d="M12 5v14" /></svg>`))
}

/* Spread last wins, and viewBox is now the only fixed attribute there is left
to win against -- which is the one worth reaching, for a body drawn on some
other grid. The seven that became .icon cannot be overridden this way any more:
CSS beats a presentation attribute, so passing stroke-width here would render
and then be ignored. Changing those is a class's job now. */
@(test)
test_icon_extra_attrs_override_viewbox :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ icon(.Chevron_Down, {}, a.view_box("0 0 16 16")) }
	})
	testing.expect(t, strings.contains(out, `viewBox="0 0 16 16"`))
	testing.expect(t, !strings.contains(out, `viewBox="0 0 24 24"`))
}

/* The footgun of putting the base class in the class attribute rather than in
attrs: a caller passing a.class replaces it wholesale, .icon included, and the
icon loses its paint. Props.class is the additive way in. */
@(test)
test_icon_attrs_class_replaces_base :: proc(t: ^testing.T) {
	via_props := rendered(t, proc() {
		{ icon(.Chevron_Down, {class = "size-4"}) }
	})
	testing.expect(t, strings.contains(via_props, `class="icon size-4"`))

	via_attrs := rendered(t, proc() {
		{ icon(.Chevron_Down, {}, a.class("size-4")) }
	})
	testing.expect(t, strings.contains(via_attrs, `class="size-4"`))
	testing.expect(t, !strings.contains(via_attrs, "icon"))
}
