/* Tests for copybutton, in the package and beside the component -- see the
file comment in accordion/accordion_test.odin for why the class tables below
are restated rather than referenced.

This one restates two components' worth: the button's own class list, because
copybutton renders a button and what a caller sees is the whole string, and the
two icon bodies, because which icon goes in which span is the part
copybutton.ts depends on. Both are duplicated from button's and icon's own
tests on purpose -- a change on either side should show up here as a failure to
look at, not as a silent agreement. */
package copybutton

import "core:encoding/json"
import "core:fmt"
import "core:os"
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

/* button's base, escaped as it goes on the wire. */
@(private = "file")
BTN ::
	"inline-flex items-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-all " +
	"justify-center " +
	"disabled:pointer-events-none disabled:opacity-50 [&amp;_svg]:pointer-events-none " +
	"[&amp;_svg:not([class*=&#39;size-&#39;])]:size-4 shrink-0 [&amp;_svg]:shrink-0 " +
	"outline-none focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] " +
	"aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive " +
	"cursor-pointer"

@(private = "file")
V_GHOST :: "hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50"
@(private = "file")
S_ICON :: "size-9"

@(private = "file")
CB :: "h-7 w-7 text-muted-foreground hover:text-accent-foreground"

@(private = "file")
CLIPBOARD ::
	`<svg viewBox="0 0 24 24" class="icon size-4">` +
	`<rect width="8" height="4" x="8" y="2" rx="1" ry="1" /> ` +
	`<path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" /></svg>`

@(private = "file")
CHECK :: `<svg viewBox="0 0 24 24" class="icon size-4"><path d="M20 6 9 17l-5-5" /></svg>`

@(private = "file")
ICONS ::
	`<span data-oh-copybutton="clipboard">` +
	CLIPBOARD +
	`</span><span data-oh-copybutton="check" class="hidden">` +
	CHECK +
	`</span>`

/* The element boundary and the wrapper it holds: the two are always written
together, and only the target id between them varies -- so the tests below say
OPEN + id + BOX and mean "the opening, pointed there". */
@(private = "file")
OPEN :: `<oh-copybutton class="contents"><div data-oh-copybutton="root" data-oh-copybutton-target="`
@(private = "file")
BOX :: `" class="inline-block">`

/* The whole thing, once: element, wrapper, ghost icon button, both icons. */
@(test)
test_copybutton_markup :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ copybutton({target_id = "install"}) }
	})
	testing.expect_value(
		t,
		out,
		OPEN +
		"install" +
		BOX +
		`<button class="` +
		BTN +
		" " +
		V_GHOST +
		" " +
		S_ICON +
		" " +
		CB +
		`" type="button">` +
		ICONS +
		`</button></div></oh-copybutton>`,
	)
}

/* target_id is what the element looks the source up by, so it is written
whatever it says -- including empty, which is the shape copybutton.ts logs about
rather than the shape it silently ignores. */
@(test)
test_copybutton_target_id_always_written :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ copybutton() }
		})
	testing.expect(t, strings.contains(out, `data-oh-copybutton-target=""`))
}

/* The wrapper class is layout, not contract: <oh-copybutton> is where
copybutton.js used to climb to with closest(".inline-block"), so the utility is
kept as upstream's and nothing reads it. */
@(test)
test_copybutton_wrapper_class :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ copybutton({target_id = "x"}) }
	})
	testing.expect(t, strings.has_prefix(out, OPEN + "x" + BOX))
}

/* Two spans, in this order, and only the second hidden. The element swaps their
inline display and never looks at the order again -- but it does query by these
two roles, so both have to be present and distinct. */
@(test)
test_copybutton_both_icons_written :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ copybutton({target_id = "x"}) }
	})
	clip := strings.index(out, `data-oh-copybutton="clipboard"`)
	check := strings.index(out, `data-oh-copybutton="check"`)
	testing.expect(t, clip >= 0 && check > clip)
	testing.expect_value(t, strings.count(out, `class="hidden"`), 1)
}

/* id, class and attrs land on the button rather than the wrapper: the button
is what is clicked and what is worth restyling. */
@(test)
test_copybutton_id_class_and_attrs_go_to_the_button :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ copybutton({id = "cb", target_id = "x", class = "ml-2"}, a.data("testid", "c")) }
	})
	testing.expect(t, strings.contains(out, `<button id="cb" class="`))
	testing.expect(t, strings.contains(out, " " + CB + ` ml-2" type="button" data-testid="c">`))
	testing.expect(t, strings.has_prefix(out, OPEN + "x" + BOX))
}

/* No id at all unless asked for, where upstream invents a "copybutton-" one.
Nothing reads it. */
@(test)
test_copybutton_no_generated_id :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ copybutton({target_id = "x"}) }
	})
	testing.expect(t, !strings.contains(out, " id="))
}

/* It takes no children: the two icons are the whole of the button's content,
and anything written after the call is a sibling of the element. */
@(test)
test_copybutton_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ copybutton({target_id = "x"}) }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "</button></div></oh-copybutton>after"))
}

@(test)
test_copybutton_htmx_reaches_the_button :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ copybutton({target_id = "x"}, hx.post("/copied")) }
	})
	testing.expect(t, strings.contains(out, `type="button" hx-post="/copied">`))
}

/* The structural contract (README.md, "The contract test"): copybutton.ts declares in
copybutton.contract.json everything it reads from this component's markup, and
this test asserts the rendered markup carries all of it. The manifest is
consumed by both sides -- the class imports it for the three roles it acts on
and for the attribute carrying the id of the element to copy from; this test
reads it from disk -- so neither side can drift from the declaration without the
shared file appearing in the diff.

Three names the element uses stay out of it, all for the same reason: nothing
here renders them, so there is no agreement to test. data-oh-copybutton-tooltip-
text is templui's caption, which this kit has no component for; "Copied!" is the
text written into it; and the inline `display` the icons are swapped by is a
style, not markup.

The display assertion is the one thing beyond attributes: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in
the pre-upgrade window, where nothing else catches it. */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/copybutton.contract.json"

/* The attribute a selector names, value and all: `[data-oh-copybutton="root"]`
names data-oh-copybutton="root". Every selector this component declares is of
that one kind -- the contract keeps CSS selector syntax because the TS side
feeds it to querySelector and to Element.closest verbatim. */
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
test_copybutton_contract :: proc(t: ^testing.T) {
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

	// A button pointed at something: every role the element acts on, and the
	// attribute it reads the source's id from.
	out := rendered(t, proc() {
		{ copybutton({target_id = "install"}) }
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

	// Every role the element selects by appears in the rendered markup.
	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}

	// ...and the attribute appears carrying the caller's id, which is the value
	// the element hands to getElementById.
	for _, attr in contract.attributes {
		with_value := fmt.tprintf(`%s="install"`, attr)
		testing.expectf(t, strings.contains(out, with_value), "markup lacks %s", with_value)
	}
}
