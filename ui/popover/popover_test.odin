/* Tests for popover, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package popover

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
ROOT_CLASS :: "contents"

/* Escaped, which is what goes on the wire: the arbitrary variants carry an
`&`. */
@(private = "file")
TRIGGER_CLASS :: "contents"

@(private = "file")
CONTENT_CLASS ::
	"bg-popover rounded-lg border text-popover-foreground text-sm shadow-lg " +
	"pointer-events-auto fixed inset-auto m-0 " +
	"[position-try-fallbacks:flip-block,flip-inline] " +
	"[position-area:bottom] " +
	"max-w-[min(24rem,calc(100vw-2rem))] overflow-visible outline-none " +
	"opacity-0 [&amp;:popover-open]:opacity-100 [&amp;:popover-open]:starting:opacity-0 " +
	"transition-[opacity,display,overlay] transition-discrete duration-150 ease-out " +
	"motion-reduce:transition-none"

@(private = "file")
ARROW ::
	`<div data-oh-popover-arrow class="absolute h-2.5 w-2.5 rotate-45 bg-popover border border-border ` +
	`-top-[5px] left-1/2 -translate-x-1/2 border-b-transparent border-r-transparent"></div>`

@(test)
test_popover_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{root()
			{ trigger(); h.text("Open") }
			{ content(); h.text("Body") }
		}
	})
	testing.expect_value(
		t,
		out,
		`<oh-popover class="` +
		ROOT_CLASS +
		`">` +
		`<span class="` +
		TRIGGER_CLASS +
		`" data-oh-popover-trigger data-oh-popover-type="click">Open</span>` +
		`<div popover="auto" data-oh-popover-content style="margin-top:4px" class="` +
		CONTENT_CLASS +
		`"><div class="w-full overflow-hidden">Body</div></div></oh-popover>`,
	)
}

/* Both the root and the trigger are `contents`: no box of their own, so
wrapping a button changes nothing about how the button sits. The anchor
plumbing (anchor-scope, the children's anchor-name) is index.css's, keyed on
the element and role names asserted throughout. */
@(test)
test_popover_root_and_trigger_are_contents :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{root()
				{ trigger() }
			}
		})
	testing.expect_value(t, strings.count(out, `class="contents"`), 2)
}

/* The arrow follows the inner wrapper and stays inside the content box: the
wrapper is overflow-hidden, and an arrow inside it would be clipped away. */
@(test)
test_popover_arrow_is_outside_the_wrapper :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({show_arrow = true}); h.text("Body") }
	})
	testing.expect(t, strings.contains(out, `<div class="w-full overflow-hidden">Body</div>` + ARROW + `</div>`))
	testing.expect(t, strings.has_suffix(out, "</div></div>"))
}

@(test)
test_popover_no_arrow_by_default :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content(); h.text("Body") }
	})
	testing.expect(t, !strings.contains(out, "data-oh-popover-arrow"))
	testing.expect(t, strings.has_suffix(out, `<div class="w-full overflow-hidden">Body</div></div>`))
}

/* The arrow's side is decided at render time from the declared placement --
opposite side, centred on the content. */
@(test)
test_popover_arrow_follows_placement :: proc(t: ^testing.T) {
	testing.expect(t, strings.contains(arrow_class(.Top), "-bottom-[5px]"))
	testing.expect(t, strings.contains(arrow_class(.Top_End), "-bottom-[5px]"))
	testing.expect(t, strings.contains(arrow_class(.Right), "-left-[5px]"))
	testing.expect(t, strings.contains(arrow_class(.Left_Start), "-right-[5px]"))
	testing.expect(t, strings.contains(arrow_class(.Bottom), "-top-[5px]"))
}

/* Zero offset means unset, and what it becomes depends on whether there is an
arrow to leave room for. */
@(test)
test_popover_offset_default :: proc(t: ^testing.T) {
	testing.expect_value(t, offset_or_default(0, false), 4)
	testing.expect_value(t, offset_or_default(0, true), 8)
	testing.expect_value(t, offset_or_default(12, true), 12)
	testing.expect_value(t, offset_or_default(-2, false), -2)
}

/* The offset lands on the side facing the anchor, so the gap opens between
trigger and content rather than somewhere else. */
@(test)
test_popover_offset_style_side :: proc(t: ^testing.T) {
	testing.expect_value(t, offset_style(.Bottom, 4), "margin-top:4px")
	testing.expect_value(t, offset_style(.Bottom_End, 8), "margin-top:8px")
	testing.expect_value(t, offset_style(.Top, 4), "margin-bottom:4px")
	testing.expect_value(t, offset_style(.Right_Start, -4), "margin-left:-4px")
	testing.expect_value(t, offset_style(.Left, 6), "margin-right:6px")
}

/* Twelve placements, one position-area utility each. -start spans away from
the anchor's start edge (span-right below, span-bottom beside), -end the
opposite -- floating-ui's alignment vocabulary restated in CSS. */
@(test)
test_popover_placement_classes :: proc(t: ^testing.T) {
	testing.expect_value(t, placement_class(.Bottom), "[position-area:bottom]")
	testing.expect_value(t, placement_class(.Bottom_Start), "[position-area:bottom_span-right]")
	testing.expect_value(t, placement_class(.Bottom_End), "[position-area:bottom_span-left]")
	testing.expect_value(t, placement_class(.Top), "[position-area:top]")
	testing.expect_value(t, placement_class(.Top_Start), "[position-area:top_span-right]")
	testing.expect_value(t, placement_class(.Top_End), "[position-area:top_span-left]")
	testing.expect_value(t, placement_class(.Right), "[position-area:right]")
	testing.expect_value(t, placement_class(.Right_Start), "[position-area:right_span-bottom]")
	testing.expect_value(t, placement_class(.Right_End), "[position-area:right_span-top]")
	testing.expect_value(t, placement_class(.Left), "[position-area:left]")
	testing.expect_value(t, placement_class(.Left_Start), "[position-area:left_span-bottom]")
	testing.expect_value(t, placement_class(.Left_End), "[position-area:left_span-top]")
}

@(test)
test_popover_trigger_types :: proc(t: ^testing.T) {
	testing.expect_value(t, trigger_type_attr(.Click), "click")
	testing.expect_value(t, trigger_type_attr(.Manual), "manual")

	out := rendered(t, proc() {
		{ trigger({trigger_type = .Manual}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-popover-type="manual"`))
}

/* auto is the default; manual is tagsinput's holdout; hint is hover content.
The value is the platform's own attribute, not a data hook. */
@(test)
test_popover_kinds :: proc(t: ^testing.T) {
	testing.expect_value(t, kind_attr(.Auto), "auto")
	testing.expect_value(t, kind_attr(.Manual), "manual")
	testing.expect_value(t, kind_attr(.Hint), "hint")

	manual := rendered(t, proc() {
		{ content({kind = .Manual}) }
	})
	testing.expect(t, strings.contains(manual, `popover="manual"`))

	hint := rendered(t, proc() {
			{ content({kind = .Hint}) }
		})
	testing.expect(t, strings.contains(hint, `popover="hint"`))
}

/* The interest-invoker delay style, stated once for every hover component. */
@(test)
test_popover_interest_delays :: proc(t: ^testing.T) {
	testing.expect_value(t, interest_delays(0, 0), "interest-delay-start:0ms;interest-delay-end:0ms")
	testing.expect_value(t, interest_delays(150, 300), "interest-delay-start:150ms;interest-delay-end:300ms")
}

/* Nesting: an inner popover closes back to its own mark, so the outer content
still closes at the end of the outer block. */
@(test)
test_popover_nested_closes_only_itself :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{content({show_arrow = true})
			{ content(); h.text("inner") }
			h.text("after")
		}
	})
	testing.expect(t, strings.contains(out, `inner</div></div>after</div>` + ARROW + `</div>`))
}

@(test)
test_popover_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{root({id = "r", class = "block"})
			{ trigger({id = "t", class = "inline"}) }
			{ content({id = "c", class = "w-80"}) }
		}
	})
	testing.expect(t, strings.has_prefix(out, `<oh-popover id="r" class="` + ROOT_CLASS + ` block">`))
	testing.expect(t, strings.contains(out, `<span id="t" class="` + TRIGGER_CLASS + ` inline"`))
	testing.expect(t, strings.contains(out, `<div id="c"`))
	testing.expect(t, strings.contains(out, CONTENT_CLASS + ` w-80"`))
}

/* Nothing here needs an id: the element and its class work by structure, and
the anchor name is scoped rather than minted. Hover components mint content
ids because interestfor must name one -- that is their deal, not this one's. */
@(test)
test_popover_no_generated_ids :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{root()
			{ trigger() }
			{ content() }
		}
	})
	testing.expect(t, !strings.contains(out, " id="))
}

@(test)
test_popover_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{root({}, a.data("testid", "r"))
			{ trigger({}, hx.get("/t")) }
			{ content({}, a.role("dialog")) }
		}
	})
	testing.expect(t, strings.contains(out, `" data-testid="r">`))
	testing.expect(t, strings.contains(out, `data-oh-popover-type="click" hx-get="/t">`))
	testing.expect(t, strings.contains(out, `" role="dialog">`))
}

/* The structural contract (README.md, "The contract test"): popover.ts declares in
popover.contract.json everything it reads from this component's markup, and
this test asserts the rendered markup carries all of it. */

@(private = "file")
Contract :: struct {
	element:   string,
	display:   string,
	selectors: map[string]string,
	attributes: map[string]string,
	values:    map[string]string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/popover.contract.json"

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
test_popover_contract :: proc(t: ^testing.T) {
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
		{root()
			{ trigger(); h.text("Open") }
			{ content(); h.text("Body") }
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
		with_value := fmt.tprintf(`%s="`, name)
		testing.expectf(t, strings.contains(out, with_value), "markup lacks %s", name)
	}

	// The one value both sides compare: the default trigger type the class
	// toggles on.
	testing.expectf(
		t,
		strings.contains(out, fmt.tprintf(`%s="%s"`, contract.attributes["type"], contract.values["typeClick"])),
		"markup lacks the click trigger type",
	)
}
