/* Tests for timepicker, in the package and beside the component -- see the
file comment in accordion/accordion_test.odin for why the class tables below
are restated rather than referenced.

Like datepicker's, this asserts the composition and the attributes timepicker
owns, and leaves popover's and card's markup to their own tests. */
package timepicker

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
ENTRY ::
	"w-full px-2 py-1 text-sm rounded transition-colors text-left " +
	"hover:bg-accent hover:text-accent-foreground " +
	"data-[oh-timepicker-selected=true]:bg-primary " +
	"data-[oh-timepicker-selected=true]:text-primary-foreground " +
	"data-[oh-timepicker-selected=true]:hover:bg-primary/90"

@(test)
test_timepicker_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t", name = "at"}) }
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-timepicker class="contents"><div class="relative inline-block w-full">` +
			`<oh-popover class="contents">`,
		),
	)
	testing.expect(
		t,
		strings.contains(out, `<input type="hidden" name="at" value="" data-oh-timepicker-hidden-input="true">`),
	)
	testing.expect(t, strings.contains(out, `<button id="t" class=`))
	testing.expect(t, strings.contains(out, `data-oh-timepicker-popup="true" data-oh-timepicker-input-name="at"`))
	testing.expect(t, strings.has_suffix(out, "</oh-popover></div></oh-timepicker>"))
}

/* "HH:MM", and an unset time is the empty string -- the same shape the hidden
input posts. */
@(test)
test_timepicker_hhmm :: proc(t: ^testing.T) {
	testing.expect_value(t, hhmm(nil), "")
	testing.expect_value(t, hhmm(Time{9, 5, 0, 0}), "09:05")
	testing.expect_value(t, hhmm(Time{23, 59, 0, 0}), "23:59")
}

/* The value reaches the page twice -- the hidden input and the popup -- and
nowhere else: the caption stays a placeholder and no entry is marked. */
@(test)
test_timepicker_value :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t", value = Time{13, 30, 0, 0}}) }
	})
	testing.expect(t, strings.contains(out, `value="13:30" data-oh-timepicker-hidden-input="true"`))
	testing.expect(t, strings.contains(out, `data-oh-timepicker-value="13:30"`))
	testing.expect(t, strings.contains(out, `>Select time</span>`))
	testing.expect(t, !strings.contains(out, `data-oh-timepicker-selected="true"`))

	unset := rendered(t, proc() {
		{ timepicker({id = "t"}) }
	})
	testing.expect(t, !strings.contains(unset, "data-oh-timepicker-value="))
}

/* Twenty-four whole hours, none of them marked. */
@(test)
test_timepicker_hour_list_24 :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t"}) }
	})
	testing.expect_value(t, strings.count(out, "data-oh-timepicker-hour="), 24)
	testing.expect(
		t,
		strings.contains(
			out,
			`data-oh-timepicker-hour="0" data-oh-timepicker-selected="false" class="` + ENTRY + `">00</button>`,
		),
	)
	testing.expect(t, strings.contains(out, `data-oh-timepicker-hour="23"`))
	testing.expect(t, !strings.contains(out, "data-oh-timepicker-period"))
}

/* Twelve-hour form reads like a clock face: 12 first, then 01-11 -- and the
period pair appears below. */
@(test)
test_timepicker_hour_list_12 :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t", use_12_hours = true}) }
	})
	testing.expect_value(t, strings.count(out, "data-oh-timepicker-hour="), 12)
	testing.expect(
		t,
		strings.contains(
			out,
			`data-oh-timepicker-hour="0" data-oh-timepicker-selected="false" class="` + ENTRY + `">12</button>`,
		),
	)
	testing.expect(
		t,
		strings.contains(
			out,
			`data-oh-timepicker-hour="11" data-oh-timepicker-selected="false" class="` + ENTRY + `">11</button>`,
		),
	)
	testing.expect(t, !strings.contains(out, `data-oh-timepicker-hour="12"`))
	testing.expect(t, strings.contains(out, `data-oh-timepicker-use12hours="true"`))
}

/* step decides how long the minute list is, and minutes only. */
@(test)
test_timepicker_step :: proc(t: ^testing.T) {
	one := rendered(t, proc() {
		{ timepicker({id = "t"}) }
	})
	testing.expect_value(t, strings.count(one, "data-oh-timepicker-minute="), 60)
	testing.expect(t, strings.contains(one, `data-oh-timepicker-step="1"`))

	quarter := rendered(t, proc() {
		{ timepicker({id = "t", step = 15}) }
	})
	testing.expect_value(t, strings.count(quarter, "data-oh-timepicker-minute="), 4)
	testing.expect(t, strings.contains(quarter, `data-oh-timepicker-minute="45"`))
	testing.expect(t, strings.contains(quarter, `data-oh-timepicker-step="15"`))

	// Zero and negative both mean one.
	zero := rendered(t, proc() {
		{ timepicker({id = "t", step = -5}) }
	})
	testing.expect_value(t, strings.count(zero, "data-oh-timepicker-minute="), 60)
}

/* The captions are the caller's words; the attribute the script matches on
stays AM and PM. */
@(test)
test_timepicker_period_labels :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t", use_12_hours = true, am_label = "vorm.", pm_label = "nachm."}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-timepicker-period="AM" data-oh-timepicker-active="false"`))
	testing.expect(t, strings.contains(out, ">vorm.</button>"))
	testing.expect(t, strings.contains(out, ">nachm.</button>"))
	testing.expect(t, strings.contains(out, `data-oh-timepicker-am-label="vorm."`))
}

/* An empty div where the period pair would be: the footer is
justify-between, so Done needs something to be pushed away from. */
@(test)
test_timepicker_footer_spacer :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t"}) }
	})
	testing.expect(t, strings.contains(out, `<div class="flex justify-between items-center"><div></div><button `))
}

@(test)
test_timepicker_done_button :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t"}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-timepicker-done="true">Done</button>`))
}

/* Bounds are handed to the script as strings; the lists are drawn in full
regardless. */
@(test)
test_timepicker_min_and_max :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t", min_time = Time{9, 0, 0, 0}, max_time = Time{17, 0, 0, 0}}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-timepicker-min-time="09:00"`))
	testing.expect(t, strings.contains(out, `data-oh-timepicker-max-time="17:00"`))
	testing.expect_value(t, strings.count(out, "data-oh-timepicker-hour="), 24)

	unset := rendered(t, proc() {
		{ timepicker({id = "t"}) }
	})
	testing.expect(t, strings.contains(unset, `data-oh-timepicker-min-time=""`))
}

@(test)
test_timepicker_name_defaults_to_the_id :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "start"}) }
	})
	testing.expect(t, strings.contains(out, `name="start"`))
	testing.expect(t, strings.contains(out, `data-oh-timepicker-input-name="start"`))
}

/* With neither, the input has no name and posts nothing -- upstream reaches
this case only through a generated id. */
@(test)
test_timepicker_without_id_or_name :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker() }
	})
	testing.expect(t, strings.contains(out, `<input type="hidden" value="" data-oh-timepicker-hidden-input="true">`))
	testing.expect(t, strings.contains(out, `data-oh-timepicker-input-name=""`))
}

@(test)
test_timepicker_disabled_and_error :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t", disabled = true, has_error = true}) }
	})
	testing.expect(t, strings.contains(out, " disabled"))
	testing.expect(t, strings.contains(out, `aria-invalid="true"`))
	testing.expect(t, strings.contains(out, "border-destructive ring-destructive/20 dark:ring-destructive/40"))
}

@(test)
test_timepicker_form :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t", form = "f"}) }
	})
	testing.expect_value(t, strings.count(out, `form="f"`), 1)
}

/* Upstream's precedence: the script's attributes are written last and win. */
@(test)
test_timepicker_script_attrs_win :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t"}, a.data("oh-timepicker-step", "99"), hx.get("/t")) }
	})
	testing.expect(t, strings.contains(out, `hx-get="/t"`))
	testing.expect_value(t, strings.count(out, "data-oh-timepicker-step="), 1)
	testing.expect(t, strings.contains(out, `data-oh-timepicker-step="1"`))
}

@(test)
test_timepicker_class_lands_on_the_trigger :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t", class = "max-w-xs"}) }
	})
	testing.expect(t, strings.contains(out, ` max-w-xs" type="button"`))
}

/* It takes no children: what follows the call is a sibling of the root. */
@(test)
test_timepicker_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ timepicker({id = "t"}) }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "</oh-timepicker>after"))
}

/* The structural contract (README.md, "The contract test"): timepicker.ts declares
in timepicker.contract.json everything it reads from this component's markup,
and this test asserts the rendered markup carries all of it. [popover] is the
seam to popover's component: Done closes through content.hidePopover(). */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/timepicker.contract.json"

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
test_timepicker_contract :: proc(t: ^testing.T) {
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
		{ timepicker({id = "t", use_12_hours = true, value = Time{13, 30, 0, 0}}) }
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
