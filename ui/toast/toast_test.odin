/* Tests for toast, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package toast

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

import "html:html/a"
import "html:html/h"
import "html:html/hx"

import "ui:ui/icon"

@(private = "file")
rendered :: proc(t: ^testing.T, body: proc()) -> string {
	out, err := h.render_to_string(body, context.temp_allocator)
	testing.expect_value(t, err, nil)
	return out
}

@(private = "file")
CARD_CLASS ::
	"w-full bg-popover text-popover-foreground rounded-lg shadow-xs border pt-5 pb-4 px-4 " +
	"flex items-center justify-center relative overflow-hidden group"

@(test)
test_toast_defaults :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toast({title = "Saved"}) }
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-toast class="contents">` +
			`<div data-oh-toast="root" data-oh-toast-duration="3000" data-position="bottom-right" data-variant="default" class="`,
		),
	)
	testing.expect(t, strings.contains(out, `<div class="` + CARD_CLASS + `">`))
	testing.expect(t, strings.contains(out, `<p class="text-sm font-semibold truncate">Saved</p>`))
	testing.expect(t, strings.has_suffix(out, "</span></div></div></oh-toast>"))
}

/* Every corner's rules ride along in the class list and data-position picks
one, which is what lets a swap move a toast by changing one attribute. */
@(test)
test_toast_all_positions_are_in_the_class_list :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toast({position = .Top_Left}) }
	})
	testing.expect(t, strings.contains(out, `data-position="top-left"`))
	for s in ([]string {
			"data-[position=top-right]:top-0",
			"data-[position=top-left]:top-0",
			"data-[position=top-center]:top-0",
			"data-[position=bottom-right]:bottom-0",
			"data-[position=bottom-left]:bottom-0",
			"data-[position=bottom-center]:bottom-0",
		}) {
		testing.expect(t, strings.contains(out, s), s)
	}
	testing.expect(t, strings.contains(out, "data-[position*=top]:slide-in-from-top-4"))
	testing.expect(t, strings.contains(out, "data-[position*=bottom]:slide-in-from-bottom-4"))
}

@(test)
test_toast_position_names :: proc(t: ^testing.T) {
	testing.expect_value(t, position_attr(.Bottom_Right), "bottom-right")
	testing.expect_value(t, position_attr(.Bottom_Left), "bottom-left")
	testing.expect_value(t, position_attr(.Bottom_Center), "bottom-center")
	testing.expect_value(t, position_attr(.Top_Right), "top-right")
	testing.expect_value(t, position_attr(.Top_Left), "top-left")
	testing.expect_value(t, position_attr(.Top_Center), "top-center")
}

@(test)
test_toast_variant_names :: proc(t: ^testing.T) {
	testing.expect_value(t, variant_attr(.Default), "default")
	testing.expect_value(t, variant_attr(.Success), "success")
	testing.expect_value(t, variant_attr(.Error), "error")
	testing.expect_value(t, variant_attr(.Warning), "warning")
	testing.expect_value(t, variant_attr(.Info), "info")
}

/* The bar carries its role, and the variant and duration of its own -- upstream
coloured it from those rather than from the toast around it. */
@(test)
test_toast_indicator :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toast({variant = .Error, duration = 5000, show_indicator = true}) }
	})
	testing.expect(t, strings.contains(out, `<div class="absolute top-0 left-0 right-0 h-1 overflow-hidden">`))
	testing.expect(t, strings.contains(out, `<div data-oh-toast="indicator" class="h-full origin-left`))
	testing.expect(t, strings.contains(out, `data-variant="error" data-duration="5000"`))
}

/* No indicator without one asked for, and none for a toast that never leaves:
there is nothing for the bar to count down. */
@(test)
test_toast_indicator_needs_a_duration :: proc(t: ^testing.T) {
	off := rendered(t, proc() {
		{ toast({}) }
	})
	testing.expect(t, !strings.contains(off, `data-oh-toast="indicator"`))

	forever := rendered(t, proc() {
		{ toast({show_indicator = true, duration = -1}) }
	})
	testing.expect(t, !strings.contains(forever, `data-oh-toast="indicator"`))
}

/* The bar has no width or transform of its own -- an unscripted page shows a
full bar that never moves. */
@(test)
test_toast_indicator_has_no_inline_state :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toast({show_indicator = true}) }
	})
	testing.expect(t, !strings.contains(out, "style="))
}

/* The glyph follows the variant, and .Default has none -- so `icon = true`
alone renders nothing. */
@(test)
test_toast_icon_follows_the_variant :: proc(t: ^testing.T) {
	name, class := variant_icon(.Success)
	testing.expect_value(t, name, icon.Name.Circle_Check)
	testing.expect_value(t, class, "size-[22px] text-green-500 mr-3 flex-shrink-0")

	none_name, none_class := variant_icon(.Default)
	testing.expect_value(t, none_name, icon.Name.None)
	testing.expect_value(t, none_class, "")

	drawn := rendered(t, proc() {
		{ toast({variant = .Warning, icon = true}) }
	})
	testing.expect(t, strings.contains(drawn, `class="icon size-[22px] text-yellow-500 mr-3 flex-shrink-0"`))

	blank := rendered(t, proc() {
		{ toast({icon = true}) }
	})
	testing.expect(t, !strings.contains(blank, "<svg"))
}

@(test)
test_toast_title_and_description_are_optional :: proc(t: ^testing.T) {
	both := rendered(t, proc() {
		{ toast({title = "T", description = "D"}) }
	})
	testing.expect(
		t,
		strings.contains(
			both,
			`<span class="flex-1 min-w-0"><p class="text-sm font-semibold truncate">T</p><p class="text-sm opacity-90 mt-1">D</p></span>`,
		),
	)

	neither := rendered(t, proc() {
			{ toast({}) }
		})
	testing.expect(t, strings.contains(neither, `<span class="flex-1 min-w-0"></span>`))
}

/* Escaped as text, since a toast usually says something a handler put in it. */
@(test)
test_toast_text_is_escaped :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toast({title = "a < b", description = "x & y"}) }
	})
	testing.expect(t, strings.contains(out, ">a &lt; b</p>"))
	testing.expect(t, strings.contains(out, ">x &amp; y</p>"))
}

@(test)
test_toast_dismiss_button :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toast({dismissible = true}) }
	})
	testing.expect(t, strings.contains(out, `type="button" aria-label="Close" data-oh-toast="dismiss">`))
	testing.expect(t, strings.contains(out, `class="icon size-[18px] opacity-75 hover:opacity-100"`))

	off := rendered(t, proc() {
		{ toast({}) }
	})
	testing.expect(t, !strings.contains(off, `data-oh-toast="dismiss"`))
}

/* No id unless asked for, where upstream invents one -- <oh-toast> is what
marks a toast, and toast.ts keeps the countdown on the element itself. */
@(test)
test_toast_no_generated_id :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toast({}) }
	})
	testing.expect(t, !strings.contains(out, " id="))
}

@(test)
test_toast_class_and_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toast({class = "md:max-w-none"}, hx.get("/t"), a.data("testid", "t")) }
	})
	testing.expect(t, strings.contains(out, ` md:max-w-none" hx-get="/t" data-testid="t">`))
}

/* It takes no children: what follows the call is a sibling -- and the wrapper
closes before it, rather than swallowing it. */
@(test)
test_toast_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ toast({}) }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "</div></div></oh-toast>after"))
}

/* The structural contract (README.md, "The contract test"): toast.ts declares in
toast.contract.json everything it reads from this component's markup, and this
test asserts the rendered markup carries all of it. The manifest is consumed by
both sides -- the class imports it for the three part roles, the attribute the
countdown is read from, and the duration it falls back to when that attribute is
missing; this test reads it from disk -- so neither side can drift from the
declaration without the shared file appearing in the diff.

The display assertion is the one thing beyond attributes: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in
the pre-upgrade window, where nothing else catches it. */

@(private = "file")
Contract :: struct {
	element:          string,
	display:          string,
	selectors:        map[string]string,
	attributes:       map[string]string,
	default_duration: string `json:"defaultDuration"`,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/toast.contract.json"

/* The attribute a selector names, value and all: `[data-oh-toast="root"]` names
data-oh-toast="root". Every selector this component declares is of that one kind
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
test_toast_contract :: proc(t: ^testing.T) {
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

	/* A dismissible toast counting down behind an indicator: only that shape
	carries all three roles at once, and its duration is the default one both
	sides fall back to. */
	out := rendered(t, proc() {
		{ toast({title = "Saved", dismissible = true, show_indicator = true}) }
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

	// ...and the one value both sides agree on: the default this component
	// renders when the caller names no duration, which is what the element
	// falls back to when the attribute is absent.
	fallback := fmt.tprintf(`%s="%s"`, contract.attributes["duration"], contract.default_duration)
	testing.expectf(t, strings.contains(out, fallback), "markup lacks %s", fallback)
}
