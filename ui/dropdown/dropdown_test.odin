/* Tests for dropdown, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package dropdown

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

import "html:html/a"
import "html:html/h"
import "html:html/hx"

import "ui:ui/popover"

@(private = "file")
rendered :: proc(t: ^testing.T, body: proc()) -> string {
	out, err := h.render_to_string(body, context.temp_allocator)
	testing.expect_value(t, err, nil)
	return out
}

@(private = "file")
MENU ::
	"z-50 rounded-md bg-popover p-1 shadow-md focus:outline-none " +
	"overflow-y-auto overflow-x-hidden " +
	"border border-border " +
	"min-w-[8rem] max-h-[min(24rem,calc(100dvh_-_2rem))]"

@(private = "file")
ITEM_ON ::
	"focus:bg-accent focus:text-accent-foreground hover:bg-accent " + "hover:text-accent-foreground cursor-default"

@(private = "file")
CHEVRON ::
	`<svg width="16" height="16" viewBox="0 0 16 16" fill="none" ` +
	`xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 ml-auto">` +
	`<path d="M6.5 3L11.5 8L6.5 13" stroke="currentColor" stroke-width="1.5" ` +
	`stroke-linecap="round" stroke-linejoin="round"></path></svg>`

/* The root is <oh-dropdown> around popover's root, and the trigger opens on
click. The content is popover="auto": one menu at a time, light dismiss and
Escape are all native, which is why there is no exclusive flag any more. */
@(test)
test_dropdown_is_a_popover :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{dropdown()
			{ trigger(); h.text("Actions") }
			{ content() }
		}
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-dropdown class="contents"><oh-popover class="contents">`,
		),
	)
	testing.expect(t, strings.contains(out, `data-oh-popover-type="click">Actions</span>`))
	testing.expect(t, strings.contains(out, `popover="auto"`))
	testing.expect(t, strings.contains(out, MENU + `"`))
	testing.expect(t, strings.has_suffix(out, "</oh-popover></oh-dropdown>"))
}

/* Bottom_Start is the zero value, so a menu lines up with its trigger's left
edge unless told otherwise -- and, unlike an alias of popover's enum, an
explicit Bottom is still reachable. */
@(test)
test_dropdown_placement_default_and_mapping :: proc(t: ^testing.T) {
	testing.expect_value(t, placement(.Bottom_Start), popover.Placement.Bottom_Start)
	testing.expect_value(t, placement(.Bottom), popover.Placement.Bottom)
	testing.expect_value(t, placement(.Top_End), popover.Placement.Top_End)
	testing.expect_value(t, placement(.Left), popover.Placement.Left)

	def := rendered(t, proc() {
		{ content() }
	})
	testing.expect(t, strings.contains(def, "[position-area:bottom_span-right]"))

	centred := rendered(t, proc() {
		{ content({placement = .Bottom}) }
	})
	testing.expect(t, strings.contains(centred, "[position-area:bottom]"))
}

/* An href makes an anchor, no href a button -- and both carry the attribute
dropdown.ts closes the menu on. */
@(test)
test_dropdown_item_element_follows_href :: proc(t: ^testing.T) {
	link := rendered(t, proc() {
		{ item({href = "/b/1", target = "_blank"}); h.text("Open") }
	})
	testing.expect_value(
		t,
		link,
		`<a href="/b/1" target="_blank" class="flex text-left items-center justify-between ` +
		`px-2 py-1.5 text-sm rounded-sm ` +
		ITEM_ON +
		`" role="menuitem" data-oh-dropdown-item>Open</a>`,
	)

	button := rendered(t, proc() {
			{ item(); h.text("Copy") }
		})
	testing.expect(t, strings.has_prefix(button, `<button class="w-full text-left flex items-center justify-between `))
	testing.expect(t, strings.has_suffix(button, `role="menuitem" data-oh-dropdown-item>Copy</button>`))
}

/* A disabled anchor gets classes only -- there is no disabled attribute for a
link. A disabled button gets both. */
@(test)
test_dropdown_disabled_item :: proc(t: ^testing.T) {
	link := rendered(t, proc() {
		{ item({href = "/x", disabled = true}); h.text("No") }
	})
	testing.expect(t, strings.contains(link, "opacity-50 pointer-events-none"))
	testing.expect(t, !strings.contains(link, ITEM_ON))
	testing.expect(t, !strings.contains(link, " disabled"))

	button := rendered(t, proc() {
		{ item({disabled = true}); h.text("No") }
	})
	testing.expect(t, strings.contains(button, "opacity-50 pointer-events-none"))
	testing.expect(t, strings.contains(button, " disabled>"))
}

@(test)
test_dropdown_prevent_close :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ item({prevent_close = true}); h.text("Toggle") }
	})
	testing.expect(t, strings.contains(out, `data-oh-dropdown-prevent-close="true"`))

	off := rendered(t, proc() {
		{ item(); h.text("Go") }
	})
	testing.expect(t, !strings.contains(off, "prevent-close"))
}

/* No id unless asked for, where upstream gives every item a random one. */
@(test)
test_dropdown_item_no_generated_id :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ item(); h.text("x") }
	})
	testing.expect(t, !strings.contains(out, "id="))
}

@(test)
test_dropdown_group_label_separator_shortcut :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{group()
			{ label(); h.text("Bearing") }
			{item()
				h.text("Copy")
				{ shortcut(); h.text("C") }
			}
		}
		{ separator() }
	})
	testing.expect(t, strings.has_prefix(out, `<div class="py-1" role="group">`))
	testing.expect(t, strings.contains(out, `<div class="px-2 py-1.5 text-sm font-semibold">Bearing</div>`))
	testing.expect(t, strings.contains(out, `<span class="ml-auto text-xs tracking-widest opacity-60">C</span>`))
	testing.expect(t, strings.has_suffix(out, `<div class="h-px my-1 -mx-1 bg-muted" role="separator"></div>`))
}

/* separator takes no children: what follows it is a sibling. */
@(test)
test_dropdown_separator_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ separator() }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "></div>after"))
}

/* The chevron follows the caller's children, inside the button -- the seam
sub_trigger_close exists for. The button is the interest invoker: interestfor
names the sub_content, with the crossing delays as inline style. */
@(test)
test_dropdown_sub_trigger :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ sub_trigger({for_ = "mv"}); h.text("Move to") }
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<span class="contents" ` +
			`data-oh-popover-trigger data-oh-popover-type="manual">`,
		),
	)
	testing.expect(
		t,
		strings.contains(
			out,
			`<button type="button" data-oh-dropdown-submenu-trigger interestfor="mv" ` +
			`style="interest-delay-start:100ms;interest-delay-end:200ms" class="`,
		),
	)
	testing.expect(t, strings.contains(out, `><span>Move to</span>` + CHEVRON + `</button></span>`))
}

/* interestfor is an idref, so a submenu without its pair of ids is loud. */
@(test)
test_dropdown_submenu_requires_ids :: proc(t: ^testing.T) {
	no_for := rendered(t, proc() {
		{ sub_trigger(); h.text("Move to") }
	})
	testing.expect(t, strings.contains(no_for, "missing required 'for_' attribute"))
	testing.expect(t, !strings.contains(no_for, "interestfor"))

	no_id := rendered(t, proc() {
		{ sub_content(); h.text("x") }
	})
	testing.expect(t, strings.contains(no_id, "missing required 'ID' attribute"))
}

/* A submenu opens beside its parent and overlaps it slightly. The crossing
delays ride the trigger now; the content carries the placement and the
negative offset. */
@(test)
test_dropdown_sub_content :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ sub_content({id = "mv"}); h.text("x") }
	})
	testing.expect(t, strings.contains(out, `id="mv"`))
	testing.expect(t, strings.contains(out, `popover="auto"`))
	testing.expect(t, strings.contains(out, "[position-area:right_span-bottom]"))
	testing.expect(t, strings.contains(out, `style="margin-left:-4px"`))
	testing.expect(t, strings.contains(out, "z-[9999] min-w-[8rem] rounded-md border bg-popover p-1 shadow-lg"))
}

/* A submenu is a whole popover nested in the menu, and each closes back to its
own mark -- so the outer menu still closes at the end of its own block. */
@(test)
test_dropdown_submenu_nests :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{content()
			{sub()
				{ sub_trigger({for_ = "mv"}); h.text("More") }
				{sub_content({id = "mv"})
					{ item(); h.text("Deep") }
				}
			}
			h.text("after")
		}
	})
	testing.expect_value(t, strings.count(out, "<oh-popover"), 1)
	testing.expect_value(t, strings.count(out, "data-oh-popover-content"), 2)
	testing.expect(t, strings.contains(out, "Deep</button></div></div></oh-popover>after</div>"))
}

@(test)
test_dropdown_ids_classes_and_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{dropdown({id = "m"})
			{ trigger({class = "inline-flex"}, hx.get("/m")) }
			{ content({class = "w-56"}) }
		}
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-dropdown class="contents"><oh-popover id="m" class="contents">`,
		),
	)
	testing.expect(t, strings.contains(out, `class="contents inline-flex"`))
	testing.expect(t, strings.contains(out, `hx-get="/m">`))
	testing.expect(t, strings.contains(out, MENU + ` w-56"`))
}

@(test)
test_dropdown_item_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ item({}, hx.post("/copy"), a.data("testid", "i")); h.text("Copy") }
	})
	testing.expect(t, strings.contains(out, `data-oh-dropdown-item hx-post="/copy" data-testid="i">Copy</button>`))
}

/* The structural contract (README.md, "The contract test"): dropdown.ts declares in
dropdown.contract.json everything it reads from this component's markup, and
this test asserts the rendered markup carries all of it. [popover] is the seam
to popover's component -- the platform's own attribute, which is how the class
reaches the content it closes. */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/dropdown.contract.json"

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
test_dropdown_contract :: proc(t: ^testing.T) {
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
		{dropdown()
			{ trigger(); h.text("Actions") }
			{content()
				{ item({prevent_close = true}); h.text("Copy") }
				{sub()
					{ sub_trigger({for_ = "mv"}); h.text("More") }
					{sub_content({id = "mv"})
						{ item(); h.text("Deep") }
					}
				}
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
