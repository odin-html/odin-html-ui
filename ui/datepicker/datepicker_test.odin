/* Tests for datepicker, in the package and beside the component -- see the
file comment in accordion/accordion_test.odin for why the class tables below
are restated rather than referenced.

This one asserts the composition and the attributes datepicker owns, and leaves
the popover's, the card's and the calendar's markup to their own tests: what is
worth pinning here is which pieces are assembled and what is handed to them. */
package datepicker

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

import "html:html/a"
import "html:html/h"
import "html:html/hx"

import cal "ui:ui/calendar"

@(private = "file")
rendered :: proc(t: ^testing.T, body: proc()) -> string {
	out, err := h.render_to_string(body, context.temp_allocator)
	testing.expect_value(t, err, nil)
	return out
}

/* Not for datepicker's own sake -- its script works from data attributes --
but for the calendar inside, which needs one and will not invent one. */
@(test)
test_datepicker_requires_an_id :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker() }
	})
	testing.expect_value(
		t,
		out,
		`<span class="text-xs text-destructive">Error: DatePicker missing required 'ID' attribute.</span>`,
	)
}

/* A popover root, a hidden input, a trigger holding a button, and a calendar
in a card inside the content. */
@(test)
test_datepicker_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ datepicker({id = "due"}) }
		})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-datepicker class="contents"><div class="relative inline-block w-full">` +
			`<oh-popover class="contents">`,
		),
	)
	testing.expect(
		t,
		strings.contains(out, `<input type="hidden" name="due" value="" data-oh-datepicker-hidden-input>`),
	)
	testing.expect(t, strings.contains(out, `data-oh-popover-trigger data-oh-popover-type="click"`))
	testing.expect(t, strings.contains(out, `<button id="due" class=`))
	testing.expect(t, strings.contains(out, `data-oh-calendar-container="true"`))
	testing.expect(t, strings.has_suffix(out, "</oh-popover></div></oh-datepicker>"))
}

/* The calendar's id is the picker's with a suffix, so several pickers on a
page do not collide. */
@(test)
test_datepicker_names_its_calendar :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "due"}) }
	})
	testing.expect(t, strings.contains(out, `id="due-calendar"`))
	testing.expect(t, strings.contains(out, `id="due-calendar-wrapper"`))
	testing.expect(t, strings.contains(out, `id="due-calendar-month-select"`))
}

/* Only one input posts: the calendar is told to hide its own, since two with
the same name would send the date twice. */
@(test)
test_datepicker_calendar_hides_its_input :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "d", name = "due"}) }
	})
	testing.expect_value(t, strings.count(out, `type="hidden"`), 1)
	testing.expect(t, !strings.contains(out, "data-oh-calendar-hidden-input"))
}

/* The value is rendered into the hidden input in ISO, and nowhere else: the
caption stays a placeholder until datepicker.ts formats it. */
@(test)
test_datepicker_value_is_iso_in_the_input_only :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "d", value = cal.Date{2026, 7, 30}}) }
	})
	testing.expect(t, strings.contains(out, `value="2026-07-30" data-oh-datepicker-hidden-input`))
	testing.expect(
		t,
		strings.contains(
			out,
			`data-oh-datepicker-display class="text-left grow text-muted-foreground">Select a date</span>`,
		),
	)
}

/* Range mode: a second hidden input, and a caption showing both placeholders
either side of an en dash. */
@(test)
test_datepicker_range :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{datepicker(
					{
						id = "d",
						name = "from",
						mode = .Range,
						value = cal.Date{2026, 7, 30},
						end_value = cal.Date{2026, 8, 2},
					},
				)}
		})
	testing.expect_value(t, strings.count(out, `type="hidden"`), 2)
	testing.expect(t, strings.contains(out, `name="from-end" value="2026-08-02" data-oh-datepicker-hidden-end-input`))
	testing.expect(t, strings.contains(out, ">Select a date – End date</span>"))
	testing.expect(t, strings.contains(out, `data-oh-datepicker-mode="range"`))
	testing.expect(t, strings.contains(out, `data-oh-calendar-mode="range"`))
}

/* end_value and the end placeholder are ignored outside range mode -- the
attribute is written empty, as upstream writes it. */
@(test)
test_datepicker_end_is_ignored_outside_range :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "d", end_value = cal.Date{2026, 8, 2}, end_placeholder = "To"}) }
	})
	testing.expect_value(t, strings.count(out, `type="hidden"`), 1)
	testing.expect(t, strings.contains(out, `data-oh-datepicker-end-placeholder=""`))
	testing.expect(t, !strings.contains(out, "To"))
}

@(test)
test_datepicker_format_names :: proc(t: ^testing.T) {
	testing.expect_value(t, format_attr(.Locale_Medium), "locale-medium")
	testing.expect_value(t, format_attr(.Locale_Short), "locale-short")
	testing.expect_value(t, format_attr(.Locale_Long), "locale-long")
	testing.expect_value(t, format_attr(.Locale_Full), "locale-full")
}

/* The format and locale are the browser's to apply -- they are handed over as
attributes and nothing here formats a date. */
@(test)
test_datepicker_format_and_locale_reach_the_trigger :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "d", format = .Locale_Full, locale = .De_DE}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-datepicker-display-format="locale-full"`))
	testing.expect(t, strings.contains(out, `data-oh-datepicker-locale-tag="de-DE"`))

	// And the calendar gets the same locale, so the grid matches the caption.
	testing.expect(t, strings.contains(out, `data-oh-calendar-locale-tag="de-DE"`))
}

@(test)
test_datepicker_name_defaults_to_the_id :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "due"}) }
	})
	testing.expect(t, strings.contains(out, `name="due"`))
}

@(test)
test_datepicker_placeholders :: proc(t: ^testing.T) {
	def := rendered(t, proc() {
		{ datepicker({id = "d"}) }
	})
	testing.expect(t, strings.contains(def, `data-oh-datepicker-placeholder="Select a date"`))

	custom := rendered(t, proc() {
		{ datepicker({id = "d", placeholder = "When?"}) }
	})
	testing.expect(t, strings.contains(custom, `data-oh-datepicker-placeholder="When?"`))
	testing.expect(t, strings.contains(custom, ">When?</span>"))
}

@(test)
test_datepicker_disabled_and_error :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "d", disabled = true, has_error = true}) }
	})
	testing.expect(t, strings.contains(out, " disabled"))
	testing.expect(t, strings.contains(out, `aria-invalid="true"`))
	testing.expect(t, strings.contains(out, "border-destructive ring-destructive/20 dark:ring-destructive/40"))

	plain := rendered(t, proc() {
		{ datepicker({id = "d"}) }
	})
	testing.expect(t, !strings.contains(plain, "aria-invalid="))
}

/* start_of_week is passed through to the calendar rather than used here. */
@(test)
test_datepicker_start_of_week_reaches_the_calendar :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "d", start_of_week = cal.Day.Sunday}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-calendar-start-of-week="0"`))
}

/* The form attribute goes on the hidden inputs, which are the elements that
post -- unlike inputotp, where upstream puts it on a div. */
@(test)
test_datepicker_form :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "d", form = "f", mode = .Range}) }
	})
	testing.expect_value(t, strings.count(out, `form="f"`), 2)
}

/* Upstream's precedence, and this collection's exception: the data-tui-* group
is written after the caller's attributes and wins, so a caller cannot detach
the picker from its own script. */
@(test)
test_datepicker_script_attrs_win_over_the_callers :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "d"}, a.data("oh-datepicker-mode", "range"), hx.get("/d")) }
	})
	testing.expect(t, strings.contains(out, `hx-get="/d"`))

	// The caller's mode is written first and overridden, not dropped -- later
	// duplicates win in write_attrs, so only the last one reaches the page.
	testing.expect_value(t, strings.count(out, "data-oh-datepicker-mode="), 1)
	testing.expect(t, strings.contains(out, `data-oh-datepicker-mode="single"`))
}

@(test)
test_datepicker_class_lands_on_the_trigger :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "d", class = "max-w-xs"}) }
	})
	testing.expect(t, strings.contains(out, ` max-w-xs" type="button"`))
}

/* It takes no children: what follows the call is a sibling of the root. */
@(test)
test_datepicker_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ datepicker({id = "d"}) }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "</oh-datepicker>after"))
}

/* The structural contract (README.md, "The contract test"): datepicker.ts declares
in datepicker.contract.json everything it reads from this component's markup,
and this test asserts the rendered markup carries all of it. [popover] is the
seam to popover's component: closing on a completed selection is
content.hidePopover() on that element. */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/datepicker.contract.json"

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
test_datepicker_contract :: proc(t: ^testing.T) {
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
		{ datepicker({id = "d", mode = .Range}) }
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
