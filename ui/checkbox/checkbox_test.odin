/* Tests for checkbox, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package checkbox

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

import "html:html/a"
import "html:html/h"
import "html:html/hx"

import "ui:ui/icon"

@(private = "file")
rendered :: proc(t: ^testing.T, body: proc()) -> string {
	out, err := h.render_to_string(body, context.temp_allocator)
	testing.expect_value(t, err, nil)
	return out
}

@(private = "file")
BOX_CLASS ::
	"peer size-4 shrink-0 rounded-[4px] border border-input shadow-xs " +
	"focus-visible:outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 " +
	"focus-visible:border-ring " +
	"disabled:cursor-not-allowed disabled:opacity-50 " +
	"checked:bg-primary checked:text-primary-foreground checked:border-primary " +
	"indeterminate:bg-primary indeterminate:text-primary-foreground " +
	"indeterminate:border-primary " +
	"appearance-none cursor-pointer transition-shadow " +
	"relative"

@(private = "file")
MARK :: "absolute inset-0 pointer-events-none flex items-center justify-center " + "text-primary-foreground opacity-0"

@(private = "file")
TICK :: `<svg viewBox="0 0 24 24" class="icon size-3.5"><path d="M20 6 9 17l-5-5" /></svg>`
@(private = "file")
DASH :: `<svg viewBox="0 0 24 24" class="icon size-3.5"><path d="M5 12h14" /></svg>`

@(private = "file")
OVERLAYS ::
	`<div class="` +
	MARK +
	` peer-checked:opacity-100">` +
	TICK +
	`</div><div class="` +
	MARK +
	` peer-indeterminate:opacity-100">` +
	DASH +
	`</div>`

@(private = "file")
WRAP :: `<oh-checkbox class="contents">`

@(test)
test_checkbox_markup :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ checkbox({name = "terms"}) }
	})
	testing.expect_value(
		t,
		out,
		WRAP +
		`<div class="relative inline-flex items-center">` +
		`<input name="terms" value="on" type="checkbox" class="` +
		BOX_CLASS +
		`">` +
		OVERLAYS +
		`</div></oh-checkbox>`,
	)
}

/* value defaults to "on", which is what a browser posts for a checkbox with
none -- written out rather than left implicit, so the markup says what the form
will carry. */
@(test)
test_checkbox_value_defaults_to_on :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ checkbox() }
		})
	testing.expect(t, strings.contains(out, `value="on"`))

	custom := rendered(t, proc() {
		{ checkbox({value = "yes"}) }
	})
	testing.expect(t, strings.contains(custom, `value="yes"`))
	testing.expect(t, !strings.contains(custom, `value="on"`))
}

/* Bare booleans: absent rather than checked="false", which would check it. */
@(test)
test_checkbox_checked_and_disabled_are_bare :: proc(t: ^testing.T) {
	on := rendered(t, proc() {
		{ checkbox({checked = true, disabled = true}) }
	})
	testing.expect(
		t,
		strings.has_prefix(on, WRAP + `<div class="relative inline-flex items-center"><input checked disabled `),
	)

	/* With their delimiters: the class list carries checked:bg-primary and
	disabled:cursor-not-allowed, so matching the bare words would find the
	utilities rather than the attributes. */
	off := rendered(t, proc() {
			{ checkbox() }
		})
	testing.expect(t, !strings.contains(off, " checked "))
	testing.expect(t, !strings.contains(off, " checked>"))
	testing.expect(t, !strings.contains(off, " disabled "))
	testing.expect(t, !strings.contains(off, " disabled>"))
}

/* The group attributes are the whole of the parent/child wiring, and they are
strings checkbox.ts compares -- nothing here reads them. */
@(test)
test_checkbox_group :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ checkbox({group = "perms", group_parent = true}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-checkbox-group="perms"`))
	testing.expect(t, strings.contains(out, `data-oh-checkbox-parent="true"`))

	child := rendered(t, proc() {
		{ checkbox({group = "perms"}) }
	})
	testing.expect(t, strings.contains(child, `data-oh-checkbox-group="perms"`))
	testing.expect(t, !strings.contains(child, "data-oh-checkbox-parent"))
}

/* Both overlays are always written and both start at opacity-0: which one
shows is a peer-* rule, so the markup is the same whatever the state. */
@(test)
test_checkbox_both_overlays_always_written :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ checkbox({checked = true}) }
	})
	testing.expect_value(t, strings.count(out, "opacity-0"), 2)
	testing.expect(t, strings.contains(out, "peer-checked:opacity-100"))
	testing.expect(t, strings.contains(out, "peer-indeterminate:opacity-100"))
}

/* icon replaces the tick and leaves the dash alone -- the dash means "partly",
which is not a thing a caller's icon is standing in for. */
@(test)
test_checkbox_custom_icon_replaces_the_tick_only :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{checkbox({
				icon = proc() {
					{ icon.icon(.Heart, {class = "size-3.5"}) }
				},
			})}
	})
	testing.expect(t, !strings.contains(out, TICK))
	testing.expect(t, strings.contains(out, DASH))
	testing.expect(t, strings.contains(out, `peer-checked:opacity-100"><svg`))
}

@(test)
test_checkbox_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ checkbox({id = "c", name = "n", form = "f", class = "size-5"}) }
	})
	testing.expect(
		t,
		strings.contains(
			out,
			`<input id="c" name="n" value="on" form="f" type="checkbox" class="` + BOX_CLASS + ` size-5">`,
		),
	)
}

@(test)
test_checkbox_extra_attrs_reach_the_input :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ checkbox({name = "n"}, hx.post("/toggle"), a.data("testid", "c")) }
		})
	testing.expect(t, strings.contains(out, `hx-post="/toggle" data-testid="c">`))
}

/* It takes no children: what follows the call is a sibling of the wrapper --
the dash overlay, the component's own box and the element all close first. */
@(test)
test_checkbox_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ checkbox() }
		h.text("Accept")
	})
	testing.expect(t, strings.has_suffix(out, "</div></div></oh-checkbox>Accept"))
}

/* The structural contract (README.md, "The contract test"): checkbox.ts declares in
checkbox.contract.json everything it reads from this component's markup, and this
test asserts the rendered markup carries all of it. The manifest is consumed by
both sides -- the class imports it for the box's role, the attribute naming the
group, and the attribute marking the parent; this test reads it from disk -- so
neither side can drift from the declaration without the shared file appearing in
the diff.

The parent attribute's value is not in it. checkbox.ts asks whether the attribute
is there and never what it says, so "true" is markup nothing reads and there is
no agreement to test -- unlike the group's value, which is the string the two
boxes are paired by and so is asserted on both of them below.

The display assertion is the one thing beyond attributes: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in the
pre-upgrade window, where nothing else catches it. */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/checkbox.contract.json"

/* The attribute a selector names: "[data-oh-checkbox-group]" names
data-oh-checkbox-group. Every selector this component declares is of that one kind
-- the contract keeps CSS selector syntax because the TS side feeds it to
querySelector verbatim. */
@(private = "file")
selector_attr :: proc(selector: string) -> string {
	return strings.trim(selector, "[]")
}

@(private = "file")
wrapper_class_has :: proc(open_tag, token: string) -> bool {
	marker := ` class="`
	start := strings.index(open_tag, marker)
	if start < 0 {
		return false
	}
	rest := open_tag[start + len(marker):]
	end := strings.index_byte(rest, '"')
	if end < 0 {
		return false
	}
	tokens := strings.split(rest[:end], " ", context.temp_allocator)
	for tok in tokens {
		if tok == token {
			return true
		}
	}
	return false
}

@(test)
test_checkbox_contract :: proc(t: ^testing.T) {
	data, read_err := os.read_entire_file(CONTRACT_PATH, context.temp_allocator)
	testing.expectf(t, read_err == nil, "contract manifest unreadable: %s (%v)", CONTRACT_PATH, read_err)
	if read_err != nil {
		return
	}

	contract: Contract
	err := json.unmarshal(data, &contract, allocator = context.temp_allocator)
	testing.expectf(t, err == nil, "contract manifest unparsable: %v", err)
	if err != nil {
		return
	}

	// A whole group: the parent box and one child, which between them carry
	// every name the element acts on.
	out := rendered(t, proc() {
		{ checkbox({group = "perms", group_parent = true}) }
		{ checkbox({group = "perms"}) }
	})

	// The wrapper is the declared element and carries the declared display
	// utility as a whole class token.
	tag_end := strings.index_byte(out, '>')
	testing.expect(t, tag_end > 0)
	open_tag := out[:tag_end]
	testing.expectf(
		t,
		strings.has_prefix(open_tag, fmt.tprintf("<%s", contract.element)),
		"wrapper is not <%s>: %s",
		contract.element,
		open_tag,
	)
	testing.expectf(
		t,
		wrapper_class_has(open_tag, contract.display),
		"wrapper class carries no %q display utility: %s",
		contract.display,
		open_tag,
	)

	// Every role the element selects by appears in the rendered markup, as does
	// every attribute it reads.
	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
	for _, attr in contract.attributes {
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}

	// The group name is what a parent and its children are matched by, so it
	// appears on both of them with the same string.
	matched := fmt.tprintf(`%s="perms"`, contract.attributes["group"])
	testing.expectf(t, strings.count(out, matched) == 2, "markup lacks a parent and a child carrying %s", matched)
}
