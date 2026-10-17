/* Tests for textarea, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package textarea

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
TA ::
	"flex w-full min-w-0 rounded-md border border-input bg-transparent px-3 py-1 " +
	"text-base shadow-xs transition-[color,box-shadow] outline-none md:text-sm " +
	"min-h-[80px] " +
	"dark:bg-input/30 " +
	"selection:bg-primary selection:text-primary-foreground " +
	"placeholder:text-muted-foreground " +
	"focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] " +
	"disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 " +
	"aria-invalid:ring-destructive/20 aria-invalid:border-destructive " +
	"dark:aria-invalid:ring-destructive/40"

@(private = "file")
ERR :: "border-destructive ring-destructive/20 dark:ring-destructive/40"

@(test)
test_textarea_empty :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ textarea() }
	})
	testing.expect_value(
		t,
		out,
		`<oh-textarea class="contents"><textarea data-oh-textarea class="` + TA + `"></textarea></oh-textarea>`,
	)
}

/* The value is content, not an attribute, and goes through the text escaper --
which is the reason it is a prop rather than children: a textarea holds text
and nothing else, and children would let elements in. */
@(test)
test_textarea_value_is_escaped_content :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ textarea({value = "a < b & c"}) }
	})
	testing.expect(t, strings.has_suffix(out, `">a &lt; b &amp; c</textarea></oh-textarea>`))
}

@(test)
test_textarea_optional_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{textarea(
				{
					id = "n",
					name = "notes",
					form = "f",
					placeholder = "Notes",
					rows = 4,
					disabled = true,
					readonly = true,
				},
			)}
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-textarea class="contents">` +
			`<textarea id="n" data-oh-textarea name="notes" form="f" placeholder="Notes" rows="4" disabled readonly class="`,
		),
	)
}

/* rows is written only when positive: zero would pin the box to no rows at
all, where leaving it out lets min-h-[80px] and the browser default stand. */
@(test)
test_textarea_rows_omitted_when_not_positive :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ textarea({rows = 0}) }
		})
	testing.expect(t, !strings.contains(out, "rows="))

	neg := rendered(t, proc() {
		{ textarea({rows = -1}) }
	})
	testing.expect(t, !strings.contains(neg, "rows="))
}

/* auto_resize is two things at once: the flag textarea.ts looks for, and the
two classes that keep the scrollbar and the drag handle out of its way. */
@(test)
test_textarea_auto_resize :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ textarea({auto_resize = true}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-textarea-auto-resize="true"`))
	testing.expect(
		t,
		strings.has_suffix(out, `"` + TA + ` overflow-hidden resize-none"></textarea></oh-textarea>`),
	)
}

@(test)
test_textarea_error :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ textarea({has_error = true}) }
	})
	testing.expect(t, strings.contains(out, `aria-invalid="true"`))
	testing.expect(t, strings.has_suffix(out, `"` + TA + " " + ERR + `"></textarea></oh-textarea>`))
}

/* No id unless asked for, where upstream invents one. textarea.ts finds the
field by data-oh-textarea, inside its own element. */
@(test)
test_textarea_no_generated_id :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ textarea() }
	})
	testing.expect(t, !strings.contains(out, "id="))
}

@(test)
test_textarea_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ textarea({name = "q"}, hx.post("/save"), a.data("testid", "n")) }
	})
	testing.expect(t, strings.contains(out, `hx-post="/save" data-testid="n">`))
}

@(test)
test_textarea_class_is_appended :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ textarea({class = "font-mono"}) }
	})
	testing.expect(t, strings.has_suffix(out, `"` + TA + ` font-mono"></textarea></oh-textarea>`))
}

/* The structural contract (README.md, "The contract test"): textarea.ts declares in
textarea.contract.json everything it reads from this component's markup, and
this test asserts the rendered markup carries all of it. The manifest is
consumed by both sides -- the class imports it for the field's selector, the
attribute carrying the auto-resize flag, and the value that turns it on; this
test reads it from disk -- so neither side can drift from the declaration
without the shared file appearing in the diff.

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
CONTRACT_PATH :: #directory + "/../../web/src/ui/textarea.contract.json"

/* The attribute a selector names: "[data-oh-textarea]" names data-oh-textarea.
Every selector this component declares is of that one kind -- the contract keeps
CSS selector syntax because the TS side feeds it to querySelector verbatim. */
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
test_textarea_contract :: proc(t: ^testing.T) {
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

	// The auto-resizing field is the only shape the element acts on, and the
	// flag is all it reads beyond the field's own role.
	out := rendered(t, proc() {
		{ textarea({auto_resize = true, value = "one"}) }
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

	// Every attribute the element selects by appears in the rendered markup,
	// and every attribute it reads appears with the value that turns it on.
	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
	for _, attr in contract.attributes {
		with_value := fmt.tprintf(`%s="%s"`, attr, contract.enabled)
		testing.expectf(t, strings.contains(out, with_value), "markup lacks %s", with_value)
	}
}
