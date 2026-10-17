/* Tests for progress, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package progress

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
TRACK_CLASS :: "w-full overflow-hidden rounded-full bg-secondary"
@(private = "file")
BAR_CLASS :: "h-full rounded-full transition-all"

@(test)
test_progress_markup :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ progress({value = 40}) }
	})
	testing.expect_value(
		t,
		out,
		`<oh-progress class="block">` +
		`<div class="w-full" aria-valuemin="0" aria-valuemax="100" aria-valuenow="40" role="progressbar">` +
		`<div class="` +
		TRACK_CLASS +
		`"><div data-oh-indicator class="` +
		BAR_CLASS +
		` h-2.5 bg-primary"></div></div></div></oh-progress>`,
	)
}

/* The bar carries no width. progress.js sets it from aria-valuenow, which is
what keeps the value in one place -- and what means an unscripted page shows an
empty track. */
@(test)
test_progress_bar_has_no_width :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ progress({value = 40}) }
		})
	testing.expect(t, !strings.contains(out, "style="))
	testing.expect(t, !strings.contains(out, "width"))
}

/* max defaults to 100 when it is zero or negative, which is what makes a bare
value read as a percentage. */
@(test)
test_progress_max_value :: proc(t: ^testing.T) {
	testing.expect_value(t, max_value(0), 100)
	testing.expect_value(t, max_value(-5), 100)
	testing.expect_value(t, max_value(7), 7)
}

/* The displayed percentage is clamped; aria-valuenow is not, and reports what
it was given, as upstream does. */
@(test)
test_progress_percentage_is_clamped :: proc(t: ^testing.T) {
	testing.expect_value(t, percentage(-10, 100), 0)
	testing.expect_value(t, percentage(150, 100), 100)
	testing.expect_value(t, percentage(1, 4), 25)
	testing.expect_value(t, percentage(2, 3), 66) // integer division, as upstream
}

@(test)
test_progress_valuenow_is_not_clamped :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ progress({value = 150, show_value = true}) }
	})
	testing.expect(t, strings.contains(out, `aria-valuenow="150"`))
	testing.expect(t, strings.contains(out, ">100%</span>"))
}

@(test)
test_progress_custom_max :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ progress({value = 3, max = 4, show_value = true}) }
	})
	testing.expect(t, strings.contains(out, `aria-valuemax="4"`))
	testing.expect(t, strings.contains(out, ">75%</span>"))
}

/* The header appears when there is a label, or a value to show, or both --
and not at all otherwise. */
@(test)
test_progress_header :: proc(t: ^testing.T) {
	none := rendered(t, proc() {
		{ progress({value = 1}) }
	})
	testing.expect(t, !strings.contains(none, "mb-1"))

	label_only := rendered(t, proc() {
		{ progress({value = 1, label = "Uploading"}) }
	})
	testing.expect(
		t,
		strings.contains(
			label_only,
			`<div class="flex justify-between items-center mb-1"><span class="text-sm font-medium">Uploading</span></div>`,
		),
	)

	value_only := rendered(t, proc() {
			{ progress({value = 25, show_value = true}) }
		})
	testing.expect(t, strings.contains(value_only, `mb-1"><span class="text-sm font-medium">25%</span></div>`))

	both := rendered(t, proc() {
		{ progress({value = 25, label = "Uploading", show_value = true}) }
	})
	testing.expect_value(t, strings.count(both, "text-sm font-medium"), 2)
}

@(test)
test_progress_sizes :: proc(t: ^testing.T) {
	testing.expect_value(t, size_class(.Default), "h-2.5")
	testing.expect_value(t, size_class(.Sm), "h-1")
	testing.expect_value(t, size_class(.Lg), "h-4")
}

@(test)
test_progress_variants :: proc(t: ^testing.T) {
	testing.expect_value(t, variant_class(.Default), "bg-primary")
	testing.expect_value(t, variant_class(.Success), "bg-green-500")
	testing.expect_value(t, variant_class(.Danger), "bg-destructive")
	testing.expect_value(t, variant_class(.Warning), "bg-yellow-500")
}

/* bar_class goes to the fill, class to the root -- the two are separate props
because restyling the bar is the common case and reaching it through the
wrapper would need a descendant selector. */
@(test)
test_progress_class_and_bar_class :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ progress({value = 1, class = "max-w-sm", bar_class = "bg-sky-500"}) }
	})
	testing.expect(t, strings.has_prefix(out, `<oh-progress class="block"><div class="w-full max-w-sm" `))
	testing.expect(t, strings.contains(out, ` h-2.5 bg-primary bg-sky-500"`))
}

@(test)
test_progress_ids_and_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ progress({id = "p", value = 1}, hx.get("/p"), a.data("testid", "p")) }
	})
	testing.expect(t, strings.has_prefix(out, `<oh-progress class="block"><div id="p" class="w-full" `))
	testing.expect(t, strings.contains(out, `role="progressbar" hx-get="/p" data-testid="p">`))
}

/* It takes no children: what follows the call is a sibling of the root. */
@(test)
test_progress_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ progress({value = 1}) }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "</div></div></oh-progress>after"))
}

/* The structural contract (README.md, "The contract test"): progress.ts declares in
progress.contract.json everything it reads from this component's markup, and
this test asserts the rendered markup carries all of it. The manifest is
consumed by both sides -- the class imports it for its selectors and observed
attributes, this test reads it from disk -- so neither side can drift from the
declaration without the shared file appearing in the diff.

The display assertion is the one thing beyond attributes: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in
the pre-upgrade window, where nothing else catches it. */

@(private = "file")
Contract :: struct {
	element:   string,
	display:   string,
	selectors: map[string]string,
	observed:  []string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/progress.contract.json"

/* The attribute a selector names: "[data-oh-indicator]" names data-oh-indicator,
`[role="progressbar"]` names role="progressbar". The contract keeps CSS
selector syntax because the TS side feeds it to querySelector verbatim. */
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
test_progress_contract :: proc(t: ^testing.T) {
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
		{ progress({value = 40, label = "Uploading", show_value = true}) }
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

	// Every attribute the element selects by, and every attribute it
	// observes, appears in the rendered markup.
	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
	for name in contract.observed {
		with_value := fmt.tprintf(`%s="`, name)
		testing.expectf(t, strings.contains(out, with_value), "markup lacks %s", name)
	}
}
