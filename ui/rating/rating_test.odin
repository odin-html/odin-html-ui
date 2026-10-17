/* Tests for rating, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package rating

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
ITEM_STAR :: "relative text-yellow-400 transition-opacity cursor-pointer"

@(test)
test_rating_root :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ rating({value = 3.5, precision = 0.5}) }
	})
	testing.expect_value(
		t,
		out,
		`<oh-rating class="contents">` +
		`<div data-oh-rating="root" data-oh-rating-initial-value="3.50" ` +
		`data-oh-rating-precision="0.50" data-oh-rating-readonly="false" ` +
		`data-oh-rating-only-integer="false" class="flex flex-col items-start gap-1"></div></oh-rating>`,
	)
}

/* Two decimals, as upstream formats them -- the script parses these back, and
"3.5" and "3.50" are the same number but not the same golden. */
@(test)
test_rating_values_are_two_decimals :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ rating({value = 4, precision = 1}) }
		})
	testing.expect(t, strings.contains(out, `data-oh-rating-initial-value="4.00"`))
	testing.expect(t, strings.contains(out, `data-oh-rating-precision="1.00"`))
}

@(test)
test_rating_precision_default :: proc(t: ^testing.T) {
	testing.expect_value(t, precision_or_default(0), 1.0)
	testing.expect_value(t, precision_or_default(-1), 1.0)
	testing.expect_value(t, precision_or_default(0.5), 0.5)
}

/* The hidden input is last, inside the group, and only when there is a name to
post under -- a rating with none is a readout rather than a field. */
@(test)
test_rating_hidden_input :: proc(t: ^testing.T) {
	named := rendered(t, proc() {
		{rating({value = 3.5, name = "score", form = "f"})
			h.text("symbols")
		}
	})
	testing.expect(t, strings.contains(named, `data-oh-rating-name="score"`))
	testing.expect(
		t,
		strings.has_suffix(
			named,
			`symbols<input type="hidden" name="score" value="3.50" form="f" data-oh-rating="input"></div></oh-rating>`,
		),
	)

	anonymous := rendered(t, proc() {
			{ rating({value = 3.5}); h.text("symbols") }
		})
	testing.expect(t, !strings.contains(anonymous, "<input"))
	testing.expect(t, !strings.contains(anonymous, "data-oh-rating-name"))
	testing.expect(t, strings.has_suffix(anonymous, "symbols</div></oh-rating>"))
}

@(test)
test_rating_flags :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ rating({read_only = true, only_integer = true}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-rating-readonly="true"`))
	testing.expect(t, strings.contains(out, `data-oh-rating-only-integer="true"`))
}

@(test)
test_rating_group :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ group(); h.text("x") }
	})
	testing.expect_value(t, out, `<div class="flex flex-row items-center gap-1">x</div>`)
}

/* Two layers per symbol: a dim one, and a filled copy clipped to w-0 that
rating.ts widens. So an unscripted page shows nothing filled. */
@(test)
test_rating_item_has_two_layers :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ item({value = 1}) }
	})
	testing.expect(
		t,
		strings.has_prefix(out, `<div data-oh-rating="item" data-oh-rating-value="1" class="` + ITEM_STAR + `">`),
	)
	testing.expect(t, strings.contains(out, `<div class="opacity-30">`))
	testing.expect(
		t,
		strings.contains(out, `<div class="absolute inset-0 overflow-hidden w-0" data-oh-rating="fill">`),
	)
	testing.expect_value(t, strings.count(out, "<svg"), 2)
	testing.expect_value(t, strings.count(out, "fill-current"), 1)
	testing.expect(t, !strings.contains(out, "style="))
}

@(test)
test_rating_colours :: proc(t: ^testing.T) {
	testing.expect_value(t, colour_class(.Star), "text-yellow-400")
	testing.expect_value(t, colour_class(.Heart), "text-destructive")
	testing.expect_value(t, colour_class(.Emoji), "text-yellow-500")
}

/* star and heart are one glyph, filled with fill-current. */
@(test)
test_rating_heart_style :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ item({value = 1, style = .Heart}) }
	})
	testing.expect(t, strings.contains(out, "text-destructive"))
	testing.expect_value(t, strings.count(out, "fill-current"), 1)
}

/* emoji is five faces, and which one is filled follows the item's own value --
so a row runs angry, frown, meh, smile, laugh. The unfilled layer is always
neutral, and nothing there is fill-current. */
@(test)
test_rating_emoji_faces_follow_the_value :: proc(t: ^testing.T) {
	first := rendered(t, proc() {
		{ item({value = 1, style = .Emoji}) }
	})
	last := rendered(t, proc() {
		{ item({value = 5, style = .Emoji}) }
	})
	testing.expect(t, !strings.contains(first, "fill-current"))
	testing.expect(t, !strings.contains(last, "fill-current"))

	// The two filled faces differ; the dim ones are the same neutral face.
	testing.expect(t, first != last)
	dim := `<div class="opacity-30">`
	fi := strings.index(first, dim)
	li := strings.index(last, dim)
	fj := strings.index(first, `data-oh-rating="fill"`)
	lj := strings.index(last, `data-oh-rating="fill"`)
	testing.expect_value(t, first[fi:fj], last[li:lj])
}

@(test)
test_rating_ids_classes_and_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{rating({id = "r", class = "gap-2"}, hx.post("/r"), a.data("testid", "r"))
			{group({id = "g", class = "gap-3"})
				{ item({id = "i", value = 1, class = "size-6"}) }
			}
		}
	})
	testing.expect(t, strings.has_prefix(out, `<oh-rating class="contents"><div id="r" data-oh-rating="root"`))
	testing.expect(
		t,
		strings.contains(out, `class="flex flex-col items-start gap-1 gap-2" hx-post="/r" data-testid="r">`),
	)
	testing.expect(t, strings.contains(out, `<div id="g" class="flex flex-row items-center gap-1 gap-3">`))
	testing.expect(
		t,
		strings.contains(
			out,
			`<div id="i" data-oh-rating="item" data-oh-rating-value="1" class="` + ITEM_STAR + ` size-6">`,
		),
	)
}

/* item takes no children: what follows a call is a sibling. */
@(test)
test_rating_item_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ item({value = 1}) }
			h.text("after")
		})
	testing.expect(t, strings.has_suffix(out, "</div></div>after"))
}

/* The structural contract (README.md, "The contract test"): rating.ts declares in
rating.contract.json everything it reads from this component's markup, and this
test asserts the rendered markup carries all of it. The manifest is consumed by
both sides -- the class imports it for the four roles, the five configuration
attributes, the symbol's own number, and the string that turns a boolean flag on;
this test reads it from disk -- so neither side can drift from the declaration
without the shared file appearing in the diff.

Two names the class uses are deliberately absent, both by the manifest's rule
that only what the two sides must *agree* on belongs in it: the `rating-change`
event it dispatches, which nothing here renders or matches, and the committed
value, which is a field on the element rather than anything in this markup.

The display assertion is the one thing beyond attributes: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in
the pre-upgrade window, where nothing else catches it. */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
	enabled:    string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/rating.contract.json"

/* The attribute a selector names, value and all: `[data-oh-rating="item"]` names
data-oh-rating="item". Every selector this component declares is of that one kind
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
test_rating_contract :: proc(t: ^testing.T) {
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

	/* A named, read-only, integer-only rating with one symbol in it: between
	them the root, the group, the symbol and the hidden input carry every name
	the manifest declares, and both boolean flags carry the value the class
	compares against. */
	out := rendered(t, proc() {
		{rating({value = 3, name = "score", read_only = true, only_integer = true})
			{group()
				{ item({value = 1}) }
			}
		}
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

	// Every part the element selects by, and every attribute it reads, appears
	// in the rendered markup.
	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
	for _, attr in contract.attributes {
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}

	// ...and the value both sides compare the two flags against.
	for key in ([]string{"readonly", "onlyInteger"}) {
		with_value := fmt.tprintf(`%s="%s"`, contract.attributes[key], contract.enabled)
		testing.expectf(t, strings.contains(out, with_value), "markup lacks %s", with_value)
	}
}
