/* Tests for label, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package label

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

@(private = "file")
LBL :: "text-sm font-medium leading-none inline-block"

/* The wrapper, restated: the element boundary and its display utility, opened
in label_open so form.label renders it too. */
@(private = "file")
OPEN :: `<oh-label class="contents">`
@(private = "file")
CLOSE :: `</oh-label>`

/* Written on every label, whether or not anything can use it: label.ts reads
it off the element it is about to dim. */
@(private = "file")
DIS :: ` data-oh-label-disabled-style="opacity-50 cursor-not-allowed"`

@(test)
test_label_renders_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ label(); h.text("Email") }
	})
	testing.expect_value(t, out, OPEN + `<label class="` + LBL + `"` + DIS + `>Email</label>` + CLOSE)
}

/* `for` is the whole of the association: it is what the browser follows on a
click and what label.ts looks the control up by. Absent unless asked for. */
@(test)
test_label_for :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ label({for_ = "email"}); h.text("Email") }
	})
	testing.expect_value(
		t,
		out,
		OPEN + `<label for="email" class="` + LBL + `"` + DIS + `>Email</label>` + CLOSE,
	)
}

/* error colours the label and renders nothing of the message itself -- the
string is only tested for emptiness, upstream and here. */
@(test)
test_label_error_colours_only :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ label({error = "Required"}); h.text("Email") }
	})
	testing.expect_value(
		t,
		out,
		OPEN + `<label class="` + LBL + ` text-destructive"` + DIS + `>Email</label>` + CLOSE,
	)
	testing.expect(t, !strings.contains(out, "Required"))
}

@(test)
test_label_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ label({id = "l", for_ = "email", class = "mb-1"}); h.text("Email") }
	})
	testing.expect_value(
		t,
		out,
		OPEN + `<label id="l" for="email" class="` + LBL + ` mb-1"` + DIS + `>Email</label>` + CLOSE,
	)
}

/* A caller's class lands after the error colour, so it can override it -- the
concatenation order is the whole of the precedence here, there being no
TwMerge. */
@(test)
test_label_class_follows_error :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{label({error = "x", class = "text-foreground"})
			h.text("Email")}
	})
	testing.expect(t, strings.contains(out, `text-destructive text-foreground"`))
}

@(test)
test_label_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ label({}, hx.get("/v"), a.data("testid", "l")); h.text("E") }
	})
	testing.expect(t, strings.has_suffix(out, `hx-get="/v" data-testid="l">E</label>` + CLOSE))
}

/* The children are whatever the caller writes, elements included -- the
component closes at the end of that block and not before, and the wrapper
closes after it. */
@(test)
test_label_element_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{label()
			h.text("Email ")
			{ h.span(a.class("text-destructive")); h.text("*") }
		}
	})
	testing.expect(
		t,
		strings.has_suffix(
			out,
			`>Email <span class="text-destructive">*</span></label>` + CLOSE,
		),
	)
}

/* The structural contract (README.md, "The contract test"): label.ts declares in
label.contract.json everything it reads from this component's markup, and this
test asserts the rendered markup carries all of it. The manifest is consumed by
both sides -- the class imports it for the label's selector and for the two
attribute names it reads off it; this test reads it from disk -- so neither side
can drift from the declaration without the shared file appearing in the diff.

The display assertion is the one thing beyond attributes: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in
the pre-upgrade window, where nothing else catches it.

`observed` is the exception this component brings: it names the attribute
watched on the *labelled control*, which is not part of this markup and cannot
be asserted against it -- the control is the caller's, anywhere in the page. All
that is checked here is that the declaration exists, which is what keeps the
class from observing a name it never declared. */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
	observed:   []string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/label.contract.json"

/* The attribute a selector names: "[data-oh-label-disabled-style]" names
data-oh-label-disabled-style. Every selector this component declares is of that
one kind -- the contract keeps CSS selector syntax because the TS side feeds it
to querySelector verbatim. */
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
test_label_contract :: proc(t: ^testing.T) {
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

	// A label pointing at a control is the only shape the element acts on: no
	// `for`, no target, and nothing to watch.
	out := rendered(t, proc() {
		{ label({for_ = "email"}); h.text("Email") }
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

	// Every attribute the element selects by, and every attribute it reads,
	// appears in the rendered markup.
	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
	for _, attr in contract.attributes {
		written := fmt.tprintf(`%s="`, attr)
		testing.expectf(t, strings.contains(out, written), "markup lacks %s", written)
	}

	// The control's attribute, declared but not assertable here.
	testing.expect(t, len(contract.observed) > 0)
}
