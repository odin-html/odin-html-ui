/* Tests for selectbox, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced.

button's, popover's and input's own class lists are left to their tests; what
is pinned here is the ordering the two deferred halves produce and the
attributes selectbox.ts works from. */
package selectbox

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
ITEM ::
	"group relative flex w-full cursor-default select-none items-center " +
	"rounded-sm py-1.5 px-2 text-sm font-light outline-none " +
	"hover:bg-accent hover:text-accent-foreground " +
	"focus-visible:bg-accent focus-visible:text-accent-foreground " +
	"data-[oh-selectbox-selected=true]:bg-accent " +
	"data-[oh-selectbox-selected=true]:text-accent-foreground"

@(private = "file")
CHECK ::
	`<span class="absolute right-2 flex h-3.5 w-3.5 items-center ` +
	`justify-center opacity-0 group-data-[oh-selectbox-selected=true]:opacity-100">` +
	`<svg viewBox="0 0 24 24" class="icon size-4"><path d="M20 6 9 17l-5-5" /></svg></span>`

/* The root is <oh-selectbox> around the container div, with popover's root
inside that -- three elements from one component. */
@(test)
test_selectbox_root :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ selectbox(); h.text("x") }
	})
	testing.expect_value(
		t,
		out,
		`<oh-selectbox class="contents"><div class="w-full relative">` +
		`<oh-popover class="contents">x</oh-popover></div></oh-selectbox>`,
	)
}

/* The order the deferred half produces: hidden input, then the caller's
children, then the clear and the chevron -- all inside the button. */
@(test)
test_selectbox_trigger_order :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{trigger({name = "shelf"})
				{ value({placeholder = "Pick"}) }
			}
		})
	input_at := strings.index(out, "data-oh-selectbox-hidden-input")
	value_at := strings.index(out, "data-oh-selectbox-display")
	clear_at := strings.index(out, "data-oh-selectbox-clear-trigger")
	chevron_at := strings.index(out, "data-oh-selectbox-chevron")
	testing.expect(t, input_at >= 0 && value_at > input_at)
	testing.expect(t, clear_at > value_at && chevron_at > clear_at)
	testing.expect(t, strings.has_suffix(out, "</span></button></span>"))
}

/* The trigger is popover's trigger around a button, and clicking it is what
opens the list -- through popover.ts's toggle, the rest being native. */
@(test)
test_selectbox_trigger_is_a_popover_trigger :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger() }
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<span class="contents" ` +
			`data-oh-popover-trigger data-oh-popover-type="click">`,
		),
	)
	testing.expect(t, strings.contains(out, "data-oh-selectbox-trigger"))
	testing.expect(t, strings.contains(out, `tabindex="0"`))
}

/* The hidden input is what posts, and it is where a caller's attributes land
-- as upstream puts them. */
@(test)
test_selectbox_hidden_input :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({name = "shelf", form = "f"}, a.data("testid", "s")) }
	})
	testing.expect(
		t,
		strings.contains(
			out,
			`<input type="hidden" name="shelf" form="f" data-oh-selectbox-hidden-input data-testid="s">`,
		),
	)
	testing.expect_value(t, strings.count(out, `data-testid="s"`), 1)
}

/* show_pills implies multiple, so the two cannot disagree. */
@(test)
test_selectbox_show_pills_implies_multiple :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({show_pills = true}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-selectbox-multiple="true"`))
	testing.expect(t, strings.contains(out, `data-oh-selectbox-show-pills="true"`))

	plain := rendered(t, proc() {
		{ trigger() }
	})
	testing.expect(t, strings.contains(plain, `data-oh-selectbox-multiple="false"`))
	testing.expect(t, strings.contains(plain, `data-oh-selectbox-show-pills="false"`))
}

@(test)
test_selectbox_trigger_disabled_and_error :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({disabled = true, has_error = true}) }
	})
	testing.expect(t, strings.contains(out, " disabled"))
	testing.expect(t, strings.contains(out, `aria-invalid="true"`))
	testing.expect(t, strings.contains(out, "border-destructive ring-destructive/20 dark:ring-destructive/40"))
}

/* The placeholder is rendered as text so it shows before any script runs, and
kept in an attribute so it can be put back when the selection is cleared. */
@(test)
test_selectbox_value :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ value({placeholder = "Pick a shelf"}) }
	})
	testing.expect_value(
		t,
		out,
		`<span class="block truncate text-muted-foreground" data-oh-selectbox-display ` +
		`data-oh-selectbox-placeholder="Pick a shelf">Pick a shelf</span>`,
	)

	bare := rendered(t, proc() {
			{ value(); h.text("Shelf A1") }
		})
	testing.expect(t, !strings.contains(bare, "data-oh-selectbox-placeholder"))
	testing.expect(t, strings.has_suffix(bare, ">Shelf A1</span>"))
}

/* A row's text is truncated and the tick follows it as a sibling -- which is
what the truncate needs, and the reason item defers a proc of its own. */
@(test)
test_selectbox_item :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ item({value = "a1", selected = true}); h.text("Shelf A1") }
	})
	testing.expect_value(
		t,
		out,
		`<div class="` +
		ITEM +
		`" role="option" data-oh-selectbox-item data-oh-selectbox-value="a1" data-oh-selectbox-selected="true" ` +
		`data-oh-selectbox-disabled="false" tabindex="0">` +
		`<span class="truncate" data-oh-selectbox-item-text>Shelf A1</span>` +
		CHECK +
		`</div>`,
	)
}

@(test)
test_selectbox_item_disabled :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ item({value = "a1", disabled = true}); h.text("Shelf A1") }
		})
	testing.expect(t, strings.contains(out, "pointer-events-none opacity-50"))
	testing.expect(t, strings.contains(out, `data-oh-selectbox-disabled="true"`))
}

/* The tick is a group-data rule reading the row's own attribute, so marking a
row is one attribute rather than a class swap. */
@(test)
test_selectbox_item_tick_is_attribute_driven :: proc(t: ^testing.T) {
	on := rendered(t, proc() {
		{ item({value = "a"}); h.text("A") }
	})
	off := rendered(t, proc() {
		{ item({value = "a", selected = true}); h.text("A") }
	})
	testing.expect(t, strings.contains(on, CHECK))
	testing.expect(t, strings.contains(off, CHECK))
}

/* Three closes in order at the end of a content block: the scrolling list,
popover's own wrapper, then the popover itself. */
@(test)
test_selectbox_content_closes_in_order :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({no_search = true}); h.text("rows") }
	})
	testing.expect(t, strings.has_suffix(out, `<div class="max-h-[300px] overflow-y-auto">rows</div></div></div>`))
}

/* The search box is rendered with the content; whether Escape clears it first
is selectbox.ts's scoped preventDefault, not a popover knob any more. */
@(test)
test_selectbox_search_box :: proc(t: ^testing.T) {
	searched := rendered(t, proc() {
		{ content() }
	})
	testing.expect(t, strings.contains(searched, `data-oh-selectbox-search=""`))

	plain := rendered(t, proc() {
		{ content({no_search = true}) }
	})
	testing.expect(t, !strings.contains(plain, "data-oh-selectbox-search"))
}

/* auto, anchored bottom-start, and sized to the trigger by anchor-size() --
which is what retired the measured-width sync. */
@(test)
test_selectbox_content_attributes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content() }
	})
	testing.expect(t, strings.contains(out, `popover="auto"`))
	testing.expect(t, strings.contains(out, "[position-area:bottom_span-right]"))
	testing.expect(t, strings.contains(out, `style="margin-top:4px"`))
	testing.expect(t, strings.contains(out, "w-[anchor-size(width)] min-w-[anchor-size(width)]"))
	testing.expect(t, strings.contains(out, `role="listbox" tabindex="-1" data-oh-selectbox-content="true"`))
	testing.expect(t, !strings.contains(out, "disable-esc"))
	testing.expect(t, !strings.contains(out, "exclusive"))
}

@(test)
test_selectbox_search_placeholder :: proc(t: ^testing.T) {
	def := rendered(t, proc() {
		{ content() }
	})
	testing.expect(t, strings.contains(def, `placeholder="Search..."`))

	custom := rendered(t, proc() {
		{ content({search_placeholder = "Filter shelves"}) }
	})
	testing.expect(t, strings.contains(custom, `placeholder="Filter shelves"`))
}

@(test)
test_selectbox_group_and_label :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{group()
			{ label(); h.text("Warehouse A") }
		}
	})
	testing.expect_value(
		t,
		out,
		`<div class="p-1" role="group"><span class="px-2 py-1.5 text-sm font-medium">Warehouse A</span></div>`,
	)
}

/* The whole thing nests: each component closes back to its own mark, so the
root's tags still close at the end of the root's block. */
@(test)
test_selectbox_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{selectbox()
				{trigger({name = "s"})
					{ value({placeholder = "Pick"}) }
				}
				{content({no_search = true})
					{group()
						{ item({value = "a"}); h.text("A") }
					}
				}
			}
			h.text("after")
		})
	testing.expect(t, strings.has_prefix(out, `<oh-selectbox class="contents"><div class="w-full relative">`))
	testing.expect(t, strings.has_suffix(out, "</div></div></oh-popover></div></oh-selectbox>after"))
}

@(test)
test_selectbox_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{selectbox({id = "s", class = "max-w-xs"})
			{ trigger({id = "s-t", class = "h-11"}) }
			{ content({id = "s-c", class = "w-64", no_search = true}) }
		}
	})
	testing.expect(
		t,
		strings.has_prefix(out, `<oh-selectbox class="contents"><div id="s" class="w-full relative max-w-xs">`),
	)
	testing.expect(t, strings.contains(out, `<button id="s-t"`))
	testing.expect(t, strings.contains(out, ` h-11" type="button"`))
	testing.expect(t, strings.contains(out, `<div id="s-c" popover="auto"`))
	testing.expect(t, strings.contains(out, ` w-64" role="listbox"`))
}

@(test)
test_selectbox_extra_attrs_on_the_root :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ selectbox({}, hx.get("/shelves"), a.data("testid", "s")) }
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-selectbox class="contents"><div class="w-full relative" hx-get="/shelves" data-testid="s">`,
		),
	)
}

/* The structural contract (README.md, "The contract test"): selectbox.ts declares in
selectbox.contract.json everything it reads from this component's markup, and
this test asserts the rendered markup carries all of it. */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/selectbox.contract.json"

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
test_selectbox_contract :: proc(t: ^testing.T) {
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

	out := rendered(t, proc() {
		{selectbox()
			{trigger({name = "s", show_pills = true, selected_count_text = "{n} picked"})
				{ value({placeholder = "Pick"}) }
			}
			{content()
				{ item({value = "a", selected = true}); h.text("A") }
			}
		}
	})

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

	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
	for _, name in contract.attributes {
		testing.expectf(t, strings.contains(out, name), "markup lacks %s", name)
	}
}
