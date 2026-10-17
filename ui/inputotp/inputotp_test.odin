/* Tests for inputotp, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package inputotp

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
SLOT ::
	"w-10 h-12 text-center rounded-md border border-input bg-transparent text-base " +
	"shadow-xs transition-[color,box-shadow] outline-none md:text-sm " +
	"dark:bg-input/30 " +
	"selection:bg-primary selection:text-primary-foreground " +
	"placeholder:text-muted-foreground " +
	"focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] " +
	"disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 " +
	"aria-invalid:ring-destructive/20 aria-invalid:border-destructive " +
	"dark:aria-invalid:ring-destructive/40"

@(test)
test_inputotp_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{inputotp({name = "code"})
			{group()
				{ slot({index = 0}) }
			}
		}
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-inputotp class="contents"><div class="flex flex-row items-center gap-2 w-fit" data-oh-inputotp>`,
		),
	)
	testing.expect(t, strings.contains(out, `<input type="hidden" name="code" data-oh-inputotp-value-target>`))
	testing.expect(
		t,
		strings.contains(
			out,
			`<div class="flex gap-2"><div class="relative"><input type="text" inputmode="numeric" maxlength="1" class="`,
		),
	)
	testing.expect(
		t,
		strings.has_suffix(out, `data-oh-inputotp-index="0" data-oh-inputotp-slot></div></div></div></oh-inputotp>`),
	)
}

/* The id produces two: <id>-container on the root div, <id> on the hidden
input -- which is what lets a label point at something postable. Neither lands
on the <oh-inputotp> wrapper, which carries the display utility and nothing
else. */
@(test)
test_inputotp_id_produces_two :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ inputotp({id = "otp"}) }
	})
	testing.expect(t, strings.has_prefix(out, `<oh-inputotp class="contents"><div id="otp-container"`))
	testing.expect(t, strings.contains(out, `<input type="hidden" id="otp" data-oh-inputotp-value-target>`))

	none := rendered(t, proc() {
		{ inputotp() }
	})
	testing.expect(t, !strings.contains(none, "id="))
}

/* The hidden input is the field that posts; the slots are one character each
and post nothing. */
@(test)
test_inputotp_hidden_input_is_the_field :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{inputotp({name = "code"})
			{group()
				{ slot({index = 0}) }
				{ slot({index = 1}) }
			}
		}
	})
	testing.expect_value(t, strings.count(out, "name="), 1)
	testing.expect_value(t, strings.count(out, `maxlength="1"`), 2)
}

/* A server-rendered value goes on the root for inputotp.ts to spread when it
connects; the slots are rendered empty, so an unscripted page shows nothing and
posts nothing. */
@(test)
test_inputotp_value_is_for_the_script :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{inputotp({value = "123456"})
			{group()
				{ slot({index = 0}) }
			}
		}
	})
	testing.expect(t, strings.contains(out, `data-oh-inputotp-value="123456"`))
	testing.expect(t, !strings.contains(out, `value="1"`))

	empty := rendered(t, proc() {
		{ inputotp() }
	})
	testing.expect(t, !strings.contains(empty, "data-oh-inputotp-value="))
}

/* Kept as upstream has it: `form` on a div does nothing, and the hidden input
beside it is what would need it. */
@(test)
test_inputotp_form_goes_on_the_root_div :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ inputotp({form = "f", name = "code"}) }
	})
	testing.expect(t, strings.contains(out, `<div form="f"`))
	testing.expect(t, !strings.contains(out, `name="code" form=`))
}

/* has_error marks the hidden input and each slot that asks for it -- the root
sets the one that a form validator would read. */
@(test)
test_inputotp_errors :: proc(t: ^testing.T) {
	root := rendered(t, proc() {
		{ inputotp({has_error = true}) }
	})
	testing.expect(t, strings.contains(root, `aria-invalid="true" data-oh-inputotp-value-target`))

	s := rendered(t, proc() {
		{ slot({index = 0, has_error = true}) }
	})
	testing.expect(t, strings.contains(s, "border-destructive ring-destructive/20 dark:ring-destructive/40"))
	testing.expect(t, strings.contains(s, `aria-invalid="true"`))
}

/* Index is the slot's place in the code, and inputotp.ts sorts by it rather
than by document order. */
@(test)
test_inputotp_slot_index :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ slot({index = 4}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-inputotp-index="4"`))
}

@(test)
test_inputotp_slot_type_and_placeholder :: proc(t: ^testing.T) {
	def := rendered(t, proc() {
		{ slot({index = 0}) }
	})
	testing.expect(t, strings.contains(def, `type="text"`))
	testing.expect(t, !strings.contains(def, "placeholder="))

	custom := rendered(t, proc() {
		{ slot({index = 0, type = "password", placeholder = "•", disabled = true}) }
	})
	testing.expect(t, strings.contains(custom, `type="password"`))
	testing.expect(t, strings.contains(custom, `placeholder="•"`))
	testing.expect(t, strings.contains(custom, " disabled"))
}

/* The deviation: upstream spreads a slot's attributes onto the wrapper *and*
the input, so anything passed lands twice. Here the input alone gets them. */
@(test)
test_inputotp_slot_attrs_go_to_the_input_only :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ slot({index = 0}, a.data("testid", "s")) }
	})
	testing.expect_value(t, strings.count(out, `data-testid="s"`), 1)
	testing.expect(t, strings.contains(out, `data-oh-inputotp-slot data-testid="s">`))
}

/* The slot's id goes on the wrapper, as upstream has it -- the input inside is
reached through the index instead. */
@(test)
test_inputotp_slot_id_goes_on_the_wrapper :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ slot({id = "s0", index = 0}) }
	})
	testing.expect(t, strings.has_prefix(out, `<div id="s0" class="relative">`))
}

@(test)
test_inputotp_separator :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ separator() }
	})
	testing.expect_value(t, out, `<div class="flex items-center text-muted-foreground text-xl"><span>-</span></div>`)
}

/* slot and separator take no children: what follows is a sibling. */
@(test)
test_inputotp_leaves_take_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ slot({index = 0}) }
		{ separator() }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "</div>after"))
}

@(test)
test_inputotp_classes_and_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{inputotp({class = "gap-4"}, hx.post("/verify"))
			{group({id = "g", class = "gap-1"})
				{ slot({index = 0, class = "w-8"}) }
			}
		}
	})
	testing.expect(
		t,
		strings.contains(
			out,
			`class="flex flex-row items-center gap-2 w-fit gap-4" data-oh-inputotp hx-post="/verify">`,
		),
	)
	testing.expect(t, strings.contains(out, `<div id="g" class="flex gap-2 gap-1">`))
	testing.expect(t, strings.contains(out, SLOT + ` w-8"`))
}

/* The structural contract (README.md, "The contract test"): inputotp.ts declares in
inputotp.contract.json everything it reads from this component's markup, and
this test asserts the rendered markup carries all of it. The manifest is
consumed by both sides -- the class imports it for its three selectors, for the
server-rendered value it spreads across the slots, and for the index it orders
them by; this test reads it from disk -- so neither side can drift from the
declaration without the shared file appearing in the diff.

What is deliberately *not* in it: `label[for]` and `autofocus`, the two other
names inputotp.ts reads. Neither is this component's vocabulary -- one is the
platform's and the other a plain HTML attribute a caller passes through -- and
inputotp.odin renders neither, so there is no agreement to assert.

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
CONTRACT_PATH :: #directory + "/../../web/src/ui/inputotp.contract.json"

/* The attribute a selector names: "[data-oh-inputotp-slot]" names
data-oh-inputotp-slot. Every selector this component declares is of that one kind
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
test_inputotp_contract :: proc(t: ^testing.T) {
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

	/* A code row with a server-rendered value on it: only that shape carries
	every declared name at once -- the value attribute comes with the prop, the
	slot role and its index with a slot. */
	out := rendered(t, proc() {
		{inputotp({id = "otp", name = "code", value = "123456"})
			{group()
				{ slot({index = 0}) }
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
}
