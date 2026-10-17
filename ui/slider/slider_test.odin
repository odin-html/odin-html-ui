/* Tests for slider, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package slider

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
ROOT :: "relative flex items-center w-full select-none"
@(private = "file")
TRACK :: "relative w-full h-2 rounded-full bg-secondary"
@(private = "file")
FILL :: "absolute inset-y-0 rounded-full bg-primary pointer-events-none"
@(private = "file")
THUMB ::
	"absolute top-1/2 size-4 -translate-x-1/2 -translate-y-1/2 rounded-full bg-primary " +
	"touch-none " +
	"ring-offset-background focus-visible:outline-none focus-visible:ring-2 " +
	"focus-visible:ring-ring focus-visible:ring-offset-2 " +
	"hover:bg-primary/90 "
@(private = "file")
THUMB_ON :: THUMB + "cursor-grab active:cursor-grabbing"
@(private = "file")
THUMB_OFF :: THUMB + "opacity-50 cursor-not-allowed"

@(test)
test_slider_markup :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ slider({id = "vol", name = "volume", value = 40}) }
	})
	testing.expect_value(
		t,
		out,
		`<oh-slider class="contents">` +
		`<div id="vol" data-oh-slider="root" data-oh-slider-min="0" data-oh-slider-max="100" ` +
		`data-oh-slider-step="1" class="` +
		ROOT +
		`"><div data-oh-slider="track" class="` +
		TRACK +
		`"><div data-oh-slider="fill" class="` +
		FILL +
		`" style="left:0%;right:60.00%"></div>` +
		`<div data-oh-slider="thumb" role="slider" tabindex="0" aria-valuemin="0" aria-valuemax="100" ` +
		`aria-valuenow="40" style="left:40.00%" class="` +
		THUMB_ON +
		`"></div></div>` +
		`<input data-oh-slider="input" type="hidden" name="volume" value="40"></div></oh-slider>`,
	)
}

/* Unlike progress, the position is rendered: a slider looks right before any
script runs, and slider.ts re-computes the same numbers on drag. */
@(test)
test_slider_positions_are_rendered :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ slider({value = 25, min = 0, max = 50}) }
		})
	testing.expect(t, strings.contains(out, `style="left:0%;right:50.00%"`))
	testing.expect(t, strings.contains(out, `style="left:50.00%"`))
}

@(test)
test_slider_defaults :: proc(t: ^testing.T) {
	testing.expect_value(t, max_or_default(0), 100)
	testing.expect_value(t, max_or_default(7), 7)
	testing.expect_value(t, step_or_default(0), 1)
	testing.expect_value(t, step_or_default(5), 5)
}

/* Upstream divides without checking, and a min equal to max renders NaN%.
Zero here instead -- the one deviation in this file. */
@(test)
test_slider_percent_guards_empty_range :: proc(t: ^testing.T) {
	testing.expect_value(t, percent(5, 0, 10), 50.0)
	testing.expect_value(t, percent(0, 0, 10), 0.0)
	testing.expect_value(t, percent(10, 0, 10), 100.0)
	testing.expect_value(t, percent(5, 5, 5), 0.0)

	out := rendered(t, proc() {
		{ slider({min = 5, max = 5, value = 5}) }
	})
	testing.expect(t, !strings.contains(out, "NaN"))
}

/* Disabled takes the thumb out of the tab order rather than leaving it
focusable with nothing to do. */
@(test)
test_slider_disabled :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ slider({disabled = true}) }
	})
	testing.expect(t, strings.contains(out, `tabindex="-1"`))
	testing.expect(t, strings.contains(out, `aria-disabled="true"`))
	testing.expect(t, strings.contains(out, THUMB_OFF))

	on := rendered(t, proc() {
		{ slider() }
	})
	testing.expect(t, strings.contains(on, `tabindex="0"`))
	testing.expect(t, !strings.contains(on, "aria-disabled"))
}

@(test)
test_slider_tabindex_attr :: proc(t: ^testing.T) {
	testing.expect_value(t, tabindex_attr(true), "-1")
	testing.expect_value(t, tabindex_attr(false), "0")
}

/* The hidden input is what makes this a form control rather than a picture. */
@(test)
test_slider_hidden_input :: proc(t: ^testing.T) {
	named := rendered(t, proc() {
		{ slider({name = "v", value = 7}) }
	})
	testing.expect(
		t,
		strings.contains(named, `<input data-oh-slider="input" type="hidden" name="v" value="7">`),
	)

	unnamed := rendered(t, proc() {
		{ slider({value = 7}) }
	})
	testing.expect(
		t,
		strings.contains(unnamed, `<input data-oh-slider="input" type="hidden" value="7">`),
	)
}

/* Two thumbs, two inputs, and a fill inset from both ends -- the whole of the
difference from a single slider. */
@(test)
test_slider_range :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ range({name_min = "a", name_max = "b", min_value = 20, max_value = 80}) }
	})
	testing.expect_value(t, strings.count(out, `data-oh-slider="thumb"`), 2)
	testing.expect_value(t, strings.count(out, `data-oh-slider="input"`), 2)
	testing.expect(t, strings.has_prefix(out, `<oh-slider class="contents">`))
	testing.expect(t, strings.contains(out, `style="left:20.00%;right:20.00%"`))
	testing.expect(t, strings.contains(out, `aria-label="Minimum"`))
	testing.expect(t, strings.contains(out, `aria-label="Maximum"`))
	testing.expect(t, strings.contains(out, `name="a" value="20"`))
	testing.expect(t, strings.contains(out, `name="b" value="80"`))
}

/* A zero max_value means the top of the range, so a range with neither value
set spans the whole track. */
@(test)
test_slider_range_max_value_default :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ range({max = 50}) }
	})
	testing.expect(t, strings.contains(out, `aria-valuenow="50"`))
	testing.expect(t, strings.contains(out, `style="left:0.00%;right:0.00%"`))
}

/* A single slider's thumb has no aria-label; a range's two do, because there
they need telling apart. */
@(test)
test_slider_single_thumb_has_no_label :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ slider() }
	})
	testing.expect(t, !strings.contains(out, "aria-label"))
}

/* The readout is empty: slider.ts fills it, and rendering the number here as
well would put the value in two places. It is not wrapped in <oh-slider> either
-- it belongs to no one slider's markup, which is why it names one by id. */
@(test)
test_slider_value_is_empty :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ value({for_ = "vol"}) }
	})
	testing.expect_value(
		t,
		out,
		`<span data-oh-slider-value data-oh-slider-value-for="vol" class="text-sm text-muted-foreground"></span>`,
	)
}

/* Without a for_ there is nothing to read out, so the error span goes first --
and the empty span still follows, as upstream writes it. */
@(test)
test_slider_value_without_for :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ value() }
		})
	testing.expect(
		t,
		strings.has_prefix(out, `<span class="text-xs text-destructive">Error: Value missing 'For' attribute.</span>`),
	)
	testing.expect(
		t,
		strings.has_suffix(out, `data-oh-slider-value-for="" class="text-sm text-muted-foreground"></span>`),
	)
}

@(test)
test_slider_ids_classes_and_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ slider({id = "s", class = "max-w-sm"}, hx.post("/v"), a.data("testid", "s")) }
		})
	testing.expect(t, strings.has_prefix(out, `<oh-slider class="contents"><div id="s" data-oh-slider="root" `))
	testing.expect(t, strings.contains(out, `class="` + ROOT + ` max-w-sm" hx-post="/v" data-testid="s">`))
}

/* None of the three takes children: what follows a call is a sibling -- and the
wrapper closes before it, rather than swallowing it. */
@(test)
test_slider_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ slider() }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "></div></oh-slider>after"))
}

/* The structural contract (README.md, "The contract test"): slider.ts declares in
slider.contract.json everything it reads from this component's markup, and this
test asserts the rendered markup carries all of it. The manifest is consumed by
both sides -- the class imports it for the five part selectors, the three
configuration attributes it reads off the root, the two aria names it reads and
writes on a thumb, and the readout's `for` attribute; this test reads it from
disk -- so neither side can drift from the declaration without the shared file
appearing in the diff.

The display assertion is the one thing beyond attributes: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in
the pre-upgrade window, where nothing else catches it. */

@(private = "file")
Contract :: struct {
	element:        string,
	display:        string,
	selectors:      map[string]string,
	attributes:     map[string]string,
	disabled_value: string `json:"disabledValue"`,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/slider.contract.json"

/* The attribute a selector names, value and all: `[data-oh-slider="thumb"]`
names data-oh-slider="thumb". Every selector this component declares is of that
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
test_slider_contract :: proc(t: ^testing.T) {
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

	/* A disabled slider and the readout that names it: between them they carry
	every name the manifest declares. aria-disabled is only rendered when the
	slider is disabled, and the readout is a separate component -- the element
	writes into it from outside itself. */
	out := rendered(t, proc() {
		{ slider({id = "vol", name = "volume", value = 40, disabled = true}) }
		{ value({for_ = "vol"}) }
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

	// ...and the one attribute value both sides compare against.
	disabled := fmt.tprintf(`%s="%s"`, contract.attributes["disabled"], contract.disabled_value)
	testing.expectf(t, strings.contains(out, disabled), "markup lacks %s", disabled)
}
