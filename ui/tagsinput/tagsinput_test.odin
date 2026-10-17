/* Tests for tagsinput, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced.

badge's and input's own class lists are left to their tests; what is pinned
here is which pieces are assembled and what carries the tags. */
package tagsinput

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
ROOT ::
	"flex flex-col gap-2 p-2 rounded-md border border-input bg-transparent " +
	"shadow-xs transition-[color,box-shadow] outline-none " +
	"dark:bg-input/30 " +
	"focus-within:border-ring focus-within:ring-ring/50 focus-within:ring-[3px] " +
	"w-full"

@(private = "file")
REMOVE_ICON ::
	`<svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3 pointer-events-none" ` +
	`fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">` +
	`<path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"></path></svg>`

@(test)
test_tagsinput_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ tagsinput({name = "labels"}) }
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-tagsinput class="contents"><div class="` +
			ROOT +
			`" data-oh-tagsinput data-oh-tagsinput-name="labels" data-oh-tagsinput-form="">`,
		),
	)
	testing.expect(
		t,
		strings.contains(out, `<div class="flex flex-wrap gap-2 empty:hidden" data-oh-tagsinput-chips></div>`),
	)
	testing.expect(t, strings.contains(out, `data-oh-tagsinput-text-input=""`))
	testing.expect(
		t,
		strings.has_suffix(out, `<div data-oh-tagsinput-hidden-inputs class="hidden"></div></div></oh-tagsinput>`),
	)
}

/* One chip and one hidden input per tag, all sharing the name -- which is what
makes the field a list. The page posts its tags with or without the script. */
@(test)
test_tagsinput_tags :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ tagsinput({name = "labels", value = {"urgent", "rework"}}) }
	})
	testing.expect_value(t, strings.count(out, `data-oh-tagsinput-chip=""`), 2)
	testing.expect_value(t, strings.count(out, `data-oh-tagsinput-remove`), 2)
	testing.expect(t, strings.contains(out, `<span>urgent</span>`))
	testing.expect(
		t,
		strings.contains(
			out,
			`<input type="hidden" name="labels" value="urgent"><input type="hidden" name="labels" value="rework">`,
		),
	)
}

/* Tag text goes through the text escaper, since it is whatever was typed. */
@(test)
test_tagsinput_tags_are_escaped :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ tagsinput({name = "l", value = {"a<b"}}) }
		})
	testing.expect(t, strings.contains(out, "<span>a&lt;b</span>"))
	testing.expect(t, strings.contains(out, `value="a&lt;b"`))
}

/* The remove button is upstream's own inline SVG rather than the icon
package's x. */
@(test)
test_tagsinput_remove_button :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ tagsinput({name = "l", value = {"a"}, disabled = true}) }
	})
	testing.expect(
		t,
		strings.contains(
			out,
			`<button type="button" class="ml-1 text-current hover:text-destructive disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer" disabled data-oh-tagsinput-remove>`,
		),
	)
	testing.expect(t, strings.contains(out, REMOVE_ICON))
}

/* No suggestions, no popover: the field stands on its own. */
@(test)
test_tagsinput_without_suggestions :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ tagsinput({name = "l"}) }
	})
	testing.expect(t, !strings.contains(out, "<oh-popover"))
	testing.expect(t, !strings.contains(out, "data-oh-tagsinput-suggestions-id"))
}

/* With them, the field is wrapped in a manual popover -- manual trigger and
manual popover state both, because tagsinput.ts opens and closes it as the
field is typed in, and light dismiss must not fight that. */
@(test)
test_tagsinput_with_suggestions :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ tagsinput({id = "l", name = "labels", suggestions = {"urgent", "rework"}}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-tagsinput-suggestions-id="l-suggestions"`))
	testing.expect(t, strings.contains(out, `<oh-popover id="l-suggestions"`))
	testing.expect(t, strings.contains(out, `data-oh-popover-type="manual"`))
	testing.expect(t, strings.contains(out, `popover="manual"`))
	testing.expect(t, strings.contains(out, "w-[anchor-size(width)]"))
	testing.expect(t, strings.contains(out, `data-oh-tagsinput-suggestions-content="true"`))
}

/* Every suggestion is rendered and the filtering is the browser's, so a long
list is a long page. */
@(test)
test_tagsinput_suggestions_are_rendered_in_full :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ tagsinput({id = "l", suggestions = {"a", "b", "c"}}) }
	})
	testing.expect_value(t, strings.count(out, "data-oh-tagsinput-suggestion-value="), 3)
	testing.expect(
		t,
		strings.contains(out, `data-oh-tagsinput-suggestion data-oh-tagsinput-suggestion-value="b">b</div>`),
	)
}

/* The popover has to be addressable, and this port will not invent an id --
so suggestions without one is a hard failure rather than a quiet collision. */
@(test)
test_tagsinput_suggestions_require_an_id :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ tagsinput({suggestions = {"a"}}) }
		})
	testing.expect_value(
		t,
		out,
		`<span class="text-xs text-destructive">Error: TagsInput with suggestions is missing required 'ID' attribute.</span>`,
	)
}

/* Without suggestions nothing needs an id, so none is required and none is
written. */
@(test)
test_tagsinput_id_is_optional_without_suggestions :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ tagsinput({name = "l"}) }
		})
	testing.expect(t, !strings.contains(out, " id="))

	named := rendered(t, proc() {
		{ tagsinput({id = "l", name = "labels"}) }
	})
	testing.expect(t, strings.contains(named, `<div id="l-container"`))
	testing.expect(t, strings.contains(named, `<input id="l" type="text"`))
}

@(test)
test_tagsinput_disabled_and_error :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ tagsinput({name = "l", disabled = true, has_error = true, readonly = true}) }
	})
	testing.expect(t, strings.contains(out, "opacity-50 cursor-not-allowed w-full border-destructive"))
	testing.expect(t, strings.contains(out, " disabled"))
	testing.expect(t, strings.contains(out, " readonly"))
}

/* form is a data attribute for the script rather than a form attribute:
the hidden inputs it writes are the ones that need associating. */
@(test)
test_tagsinput_form_is_a_data_attribute :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ tagsinput({name = "l", form = "f"}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-tagsinput-form="f"`))

	// With its delimiter: the data attribute's own name ends in "form", so
	// matching the bare word would find that rather than a form attribute.
	testing.expect(t, !strings.contains(out, ` form="f"`))
}

/* The deviation: upstream puts a caller's attributes on the container and the
input both. Here the container alone gets them, as everywhere else in this
collection. */
@(test)
test_tagsinput_attrs_go_to_the_container_only :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ tagsinput({name = "l"}, hx.post("/tags"), a.data("testid", "ti")) }
	})
	testing.expect_value(t, strings.count(out, `data-testid="ti"`), 1)
	testing.expect(t, strings.contains(out, `data-oh-tagsinput-form="" hx-post="/tags" data-testid="ti">`))
}

/* It takes no children: what follows the call is a sibling of the wrapper. */
@(test)
test_tagsinput_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ tagsinput({name = "l"}) }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "</div></div></oh-tagsinput>after"))
}

/* The error branch is the component failing to render at all, so there is
nothing for an element to enhance and no wrapper around it. */
@(test)
test_tagsinput_error_has_no_wrapper :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ tagsinput({suggestions = {"a"}}) }
		})
	testing.expect(t, !strings.contains(out, "oh-tagsinput"))
}

/* The structural contract (README.md, "The contract test"): tagsinput.ts declares in
tagsinput.contract.json everything it reads from this component's markup, and
this test asserts the rendered markup carries all of it. The manifest is
consumed by both sides -- the class imports it for its selectors, for the two
attributes it reads off the root, for the suggestion values, and for the two
roles it writes onto a chip it builds itself; this test reads it from disk -- so
neither side can drift from the declaration without the shared file appearing in
the diff.

What is deliberately *not* in it: the popover attributes. tagsinput.ts finds
the suggestion list through popover's element and content role, but those are
rendered by popover.odin and belong to popover's own contract. The
composition tests above are where that coupling is pinned.

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
CONTRACT_PATH :: #directory + "/../../web/src/ui/tagsinput.contract.json"

/* The attribute a selector names: "[data-oh-tagsinput-chips]" names
data-oh-tagsinput-chips. Every selector this component declares is of that one
kind -- the contract keeps CSS selector syntax because the TS side feeds it to
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
test_tagsinput_contract :: proc(t: ^testing.T) {
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

	/* A tags input with a tag on it and a list to suggest from: only that shape
	carries every role at once -- the chip and its remove button come with the
	tag, the suggestion roles with the list. */
	out := rendered(t, proc() {
		{ tagsinput({id = "l", name = "labels", value = {"urgent"}, suggestions = {"urgent", "rework"}}) }
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

	// Every part the element selects by, and every attribute it reads or
	// writes, appears in the rendered markup.
	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
	for _, attr in contract.attributes {
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
}
