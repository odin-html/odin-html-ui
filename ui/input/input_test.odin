/* Tests for input, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package input

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
IN ::
	"flex h-9 w-full min-w-0 rounded-md border border-input bg-transparent px-3 py-1 " +
	"text-base shadow-xs transition-[color,box-shadow] outline-none md:text-sm " +
	"dark:bg-input/30 " +
	"selection:bg-primary selection:text-primary-foreground " +
	"placeholder:text-muted-foreground " +
	"file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm " +
	"file:font-medium file:text-foreground " +
	"focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] " +
	"disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 " +
	"aria-invalid:ring-destructive/20 aria-invalid:border-destructive " +
	"dark:aria-invalid:ring-destructive/40"

@(private = "file")
ERR :: "border-destructive ring-destructive/20 dark:ring-destructive/40"

@(test)
test_input_default_is_text :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ input() }
	})
	testing.expect_value(
		t,
		out,
		`<oh-input class="contents"><div class="relative w-full"><input type="text" class="` + IN + `"></div></oh-input>`,
	)
}

/* Every member's attribute value, since one of them is not its own name and
the switch is the only place that is written down. */
@(test)
test_input_type_attribute_values :: proc(t: ^testing.T) {
	testing.expect_value(t, type_attr(.Text), "text")
	testing.expect_value(t, type_attr(.Password), "password")
	testing.expect_value(t, type_attr(.Email), "email")
	testing.expect_value(t, type_attr(.Number), "number")
	testing.expect_value(t, type_attr(.Tel), "tel")
	testing.expect_value(t, type_attr(.Url), "url")
	testing.expect_value(t, type_attr(.Search), "search")
	testing.expect_value(t, type_attr(.Date), "date")
	testing.expect_value(t, type_attr(.Date_Time), "datetime-local")
	testing.expect_value(t, type_attr(.Time), "time")
	testing.expect_value(t, type_attr(.File), "file")
	testing.expect_value(t, type_attr(.Color), "color")
	testing.expect_value(t, type_attr(.Week), "week")
	testing.expect_value(t, type_attr(.Month), "month")
}

@(test)
test_input_optional_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{input(
				{
					id = "e",
					name = "email",
					type = .Email,
					form = "f",
					placeholder = "you@example.com",
					value = "a@b.c",
					disabled = true,
					readonly = true,
					required = true,
				},
			)}
	})
	testing.expect(
		t,
		strings.contains(
			out,
			`<input id="e" type="email" name="email" placeholder="you@example.com" value="a@b.c" form="f" disabled readonly required class="`,
		),
	)
}

/* Empty strings drop out rather than rendering empty attributes -- value=""
would post an empty string where the field was meant to be absent.

The bare booleans are checked with their delimiters rather than by name: the
class list contains disabled:, readonly is not in it but aria-invalid: is, and
a bare `strings.contains(out, "disabled")` matches the utility rather than the
attribute. */
@(test)
test_input_empty_props_omitted :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ input() }
		})
	for s in ([]string{" id=", " name=", " placeholder=", " value=", " form=", " accept=", " aria-invalid="}) {
		testing.expect(t, !strings.contains(out, s), s)
	}
	for s in ([]string{" disabled ", " disabled>", " readonly ", " readonly>", " required ", " required>"}) {
		testing.expect(t, !strings.contains(out, s), s)
	}
}

/* accept is for file inputs only, whatever the prop says -- upstream guards it
the same way, and an accept on a text field means nothing. */
@(test)
test_input_accept_only_for_files :: proc(t: ^testing.T) {
	file := rendered(t, proc() {
		{ input({type = .File, file_accept = ".png"}) }
	})
	testing.expect(t, strings.contains(file, `accept=".png"`))

	text := rendered(t, proc() {
		{ input({type = .Text, file_accept = ".png"}) }
	})
	testing.expect(t, !strings.contains(text, "accept="))
}

@(test)
test_input_error :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ input({has_error = true}) }
	})
	testing.expect(t, strings.contains(out, `aria-invalid="true"`))
	testing.expect(t, strings.has_suffix(out, `"` + IN + " " + ERR + `"></div></oh-input>`))
}

/* The toggle is written for a password field with an id, and the padding comes
with it. */
@(test)
test_input_password_toggle :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ input({id = "pw", type = .Password}) }
	})
	testing.expect(t, strings.contains(out, " pr-8\""))
	testing.expect(t, strings.contains(out, `data-oh-toggle-password="pw"`))
	testing.expect(t, strings.contains(out, `<span class="icon-open block">`))
	testing.expect(t, strings.contains(out, `<span class="icon-closed hidden">`))
}

/* The deviation, stated as a test: no id, no toggle -- and no padding either,
since the space is only there for the button. Upstream reaches this case by
inventing an id; this port does not invent ids. */
@(test)
test_input_password_without_id_has_no_toggle :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ input({type = .Password}) }
	})
	testing.expect(t, !strings.contains(out, "<button"))
	testing.expect(t, !strings.contains(out, "pr-8"))
	testing.expect_value(
		t,
		out,
		`<oh-input class="contents"><div class="relative w-full"><input type="password" class="` + IN + `"></div></oh-input>`,
	)
}

@(test)
test_input_no_toggle_password :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ input({id = "pw", type = .Password, no_toggle_password = true}) }
	})
	testing.expect(t, !strings.contains(out, "<button"))
	testing.expect(t, !strings.contains(out, "pr-8"))
}

/* Only a password field gets one, id or not. */
@(test)
test_input_toggle_is_password_only :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ input({id = "e", type = .Email}) }
	})
	testing.expect(t, !strings.contains(out, "<button"))
}

/* attrs land on the input, not the wrapper: the input is the control htmx
should be watching. */
@(test)
test_input_extra_attrs_reach_the_input :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ input({name = "q"}, hx.get("/search"), a.data("testid", "q")) }
	})
	testing.expect(t, strings.has_suffix(out, `hx-get="/search" data-testid="q"></div></oh-input>`))
	testing.expect(t, strings.has_prefix(out, `<oh-input class="contents"><div class="relative w-full"><input`))
}

@(test)
test_input_class_is_appended :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ input({class = "h-12"}) }
	})
	testing.expect(t, strings.has_suffix(out, `"` + IN + ` h-12"></div></oh-input>`))
}

/* It takes no children: what follows the call is a sibling of the wrapper. */
@(test)
test_input_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ input() }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "></div></oh-input>after"))
}

/* The structural contract (README.md, "The contract test"): input.ts declares in
input.contract.json everything it reads from this component's markup, and this
test asserts the rendered markup carries all of it. The manifest is consumed by
both sides -- the class imports it for its selectors, the attribute holding the
target id, and the class it toggles; this test reads it from disk -- so neither
side can drift from the declaration without the shared file appearing in the
diff.

The display assertion is the one thing beyond attributes: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in
the pre-upgrade window, where nothing else catches it. */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
	hidden:     string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/input.contract.json"

/* What a selector names: ".icon-open" names the class icon-open,
"[data-oh-toggle-password]" the attribute of that name. The contract keeps CSS
selector syntax because the TS side feeds it to querySelector verbatim. */
@(private = "file")
selector_name :: proc(selector: string) -> string {
	return strings.trim(selector, "[].")
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
test_input_contract :: proc(t: ^testing.T) {
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

	// The password field with an id is the only shape that renders the toggle,
	// and the toggle is all the element reads.
	out := rendered(t, proc() {
		{ input({id = "pw", type = .Password}) }
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

	// Every class the element selects by, and every attribute it reads,
	// appears in the rendered markup.
	for _, selector in contract.selectors {
		name := selector_name(selector)
		testing.expectf(t, strings.contains(out, name), "markup lacks %s", name)
	}
	for _, attr in contract.attributes {
		with_value := fmt.tprintf(`%s="`, attr)
		testing.expectf(t, strings.contains(out, with_value), "markup lacks %s", attr)
	}

	// The class the element toggles is the one the closed icon starts with:
	// exactly one of the two icons is hidden before anything is clicked.
	closed := fmt.tprintf(`class="%s %s"`, selector_name(contract.selectors["iconClosed"]), contract.hidden)
	testing.expectf(t, strings.contains(out, closed), "markup lacks %s", closed)
	open_icon := fmt.tprintf(`class="%s `, selector_name(contract.selectors["iconOpen"]))
	testing.expectf(t, strings.contains(out, open_icon), "markup lacks %s", open_icon)
}
