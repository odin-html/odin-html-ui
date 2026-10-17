/* Tests for calendar, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced.

The month and year the view opens on come from the server's clock when nothing
else decides them, so the tests that care about it always pin a value or an
initial_month/initial_year. */
package calendar

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import "core:time"

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
WRAPPER :: "inline-flex flex-col [--cell-size:2rem]"

/* Nothing at all without an id, because the alternative is markup that makes
calendar.ts throw and stops every calendar on the page. */
@(test)
test_calendar_requires_an_id :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ calendar() }
	})
	testing.expect_value(
		t,
		out,
		`<span class="text-xs text-destructive">Error: Calendar missing required 'ID' attribute.</span>`,
	)
}

/* The id is used six times: the wrapper, the container, both hidden inputs and
both selects -- plus the two caption spans the script writes into. */
@(test)
test_calendar_id_is_used_throughout :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ calendar({id = "due", mode = .Range}) }
		})
	for s in ([]string {
			`id="due-wrapper"`,
			`id="due"`,
			`id="due-hidden"`,
			`id="due-hidden-end"`,
			`id="due-month-select"`,
			`id="due-year-select"`,
			`id="due-month-value"`,
			`id="due-year-value"`,
		}) {
		testing.expect(t, strings.contains(out, s), s)
	}
}

/* Both grids are rendered empty: calendar.ts fills them, so an unscripted page
shows the header and nothing under it. */
@(test)
test_calendar_grids_are_empty :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ calendar({id = "c"}) }
	})
	testing.expect(
		t,
		strings.contains(
			out,
			`<div data-oh-calendar-weekdays class="inline-grid grid-cols-[repeat(7,var(--cell-size))] gap-1 mb-1 place-items-center"></div>`,
		),
	)
	testing.expect(
		t,
		strings.has_suffix(
			out,
			`<div data-oh-calendar-days class="inline-grid grid-cols-[repeat(7,var(--cell-size))] gap-1 place-items-center"></div></div></div></oh-calendar>`,
		),
	)
}

/* The state the script starts from, all on the container. */
@(test)
test_calendar_container_attributes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ calendar({id = "c", value = Date{2026, 7, 30}, locale = .De_DE, start_of_week = Day.Sunday}) }
		})
	testing.expect(t, strings.contains(out, `data-oh-calendar-container="true"`))
	testing.expect(t, strings.contains(out, `data-oh-calendar-mode="single"`))
	testing.expect(t, strings.contains(out, `data-oh-calendar-locale-tag="de-DE"`))
	testing.expect(t, strings.contains(out, `data-oh-calendar-initial-month="6"`))
	testing.expect(t, strings.contains(out, `data-oh-calendar-initial-year="2026"`))
	testing.expect(t, strings.contains(out, `data-oh-calendar-selected-date="2026-07-30"`))
	testing.expect(t, strings.contains(out, `data-oh-calendar-end-date=""`))
	testing.expect(t, strings.contains(out, `data-oh-calendar-start-of-week="0"`))
}

@(test)
test_calendar_locale_tags :: proc(t: ^testing.T) {
	testing.expect_value(t, locale_tag(.En_US), "en-US")
	testing.expect_value(t, locale_tag(.Zh_CN), "zh-CN")
	testing.expect_value(t, locale_tag(.Fr_FR), "fr-FR")
	testing.expect_value(t, locale_tag(.De_DE), "de-DE")
	testing.expect_value(t, locale_tag(.It_IT), "it-IT")
	testing.expect_value(t, locale_tag(.Ja_JP), "ja-JP")
	testing.expect_value(t, locale_tag(.Pt_PT), "pt-PT")
	testing.expect_value(t, locale_tag(.Es_ES), "es-ES")
}

/* ISO 8601, and an unset date is the empty string rather than a zero date --
calendar.ts tests these for emptiness. */
@(test)
test_calendar_iso :: proc(t: ^testing.T) {
	testing.expect_value(t, iso_date(nil), "")
	testing.expect_value(t, iso_date(Date{2026, 1, 5}), "2026-01-05")
	testing.expect_value(t, iso_date(Date{999, 12, 31}), "0999-12-31")
}

/* Monday by default, as upstream falls back. Sunday is 0, so it has to be a
Maybe rather than a zero value meaning "unset". */
@(test)
test_calendar_start_of_week_default_is_monday :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ calendar({id = "c"}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-calendar-start-of-week="1"`))

	sunday := rendered(t, proc() {
		{ calendar({id = "c", start_of_week = Day.Sunday}) }
	})
	testing.expect(t, strings.contains(sunday, `data-oh-calendar-start-of-week="0"`))
}

/* The value wins over the clock, an explicit month or year wins over the
value, and the two are decided separately. */
@(test)
test_calendar_initial_view :: proc(t: ^testing.T) {
	from_value := rendered(t, proc() {
		{ calendar({id = "c", value = Date{2020, 3, 9}}) }
	})
	testing.expect(t, strings.contains(from_value, `data-oh-calendar-initial-month="2"`))
	testing.expect(t, strings.contains(from_value, `data-oh-calendar-initial-year="2020"`))

	overridden := rendered(t, proc() {
		{ calendar({id = "c", value = Date{2020, 3, 9}, initial_month = 12, initial_year = 2031}) }
	})
	testing.expect(t, strings.contains(overridden, `data-oh-calendar-initial-month="11"`))
	testing.expect(t, strings.contains(overridden, `data-oh-calendar-initial-year="2031"`))

	// A year alone leaves the month where it was.
	year_only := rendered(t, proc() {
		{ calendar({id = "c", value = Date{2020, 3, 9}, initial_year = 2031}) }
	})
	testing.expect(t, strings.contains(year_only, `data-oh-calendar-initial-month="2"`))
	testing.expect(t, strings.contains(year_only, `data-oh-calendar-initial-year="2031"`))
}

/* The deviation: initial_month is 1-12 here, so January is reachable without
also pinning a year. Upstream's 0-11 cannot tell January from unset. */
@(test)
test_calendar_january_is_reachable :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ calendar({id = "c", initial_month = 1}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-calendar-initial-month="0"`))
	testing.expect(t, strings.contains(out, `<span id="c-month-value" data-oh-calendar-month-value>Jan</span>`))
	testing.expect(
		t,
		strings.contains(out, `<option value="0" selected data-oh-calendar-month-index="0">Jan</option>`),
	)
}

/* Out of range is ignored rather than clamped, which leaves the month wherever
it already was. */
@(test)
test_calendar_initial_month_out_of_range_is_ignored :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ calendar({id = "c", value = Date{2020, 3, 9}, initial_month = 13}) }
		})
	testing.expect(t, strings.contains(out, `data-oh-calendar-initial-month="2"`))
}

/* Falls back to the server's clock when nothing else decides -- the one place
this component is not a pure function of its props. */
@(test)
test_calendar_falls_back_to_today :: proc(t: ^testing.T) {
	year, month, _ := time.date(time.now())
	out := rendered(t, proc() {
		{ calendar({id = "c"}) }
	})
	testing.expect(t, strings.contains(out, fmt.tprintf(`data-oh-calendar-initial-year="%d"`, year)))
	testing.expect(t, strings.contains(out, fmt.tprintf(`data-oh-calendar-initial-month="%d"`, int(month) - 1)))
}

/* One hidden input in single mode, two in range -- and the end one only there
because a range has an end to post. */
@(test)
test_calendar_hidden_inputs :: proc(t: ^testing.T) {
	single := rendered(t, proc() {
		{ calendar({id = "c", name = "due", value = Date{2026, 7, 30}}) }
	})
	testing.expect_value(t, strings.count(single, `type="hidden"`), 1)
	testing.expect(
		t,
		strings.contains(
			single,
			`<input type="hidden" name="due" value="2026-07-30" id="c-hidden" data-oh-calendar-hidden-input>`,
		),
	)

	ranged := rendered(t, proc() {
			{calendar(
					{id = "c", name = "due", mode = .Range, value = Date{2026, 7, 30}, end_value = Date{2026, 8, 2}},
				)}
		})
	testing.expect_value(t, strings.count(ranged, `type="hidden"`), 2)
	testing.expect(
		t,
		strings.contains(
			ranged,
			`name="due-end" value="2026-08-02" id="c-hidden-end" data-oh-calendar-hidden-end-input>`,
		),
	)
}

/* end_value is ignored outside range mode, as upstream ignores it. */
@(test)
test_calendar_end_value_needs_range_mode :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ calendar({id = "c", end_value = Date{2026, 8, 2}}) }
		})
	testing.expect(t, strings.contains(out, `data-oh-calendar-end-date=""`))
}

/* Names default off the id and off each other. */
@(test)
test_calendar_name_defaults :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ calendar({id = "c", mode = .Range}) }
	})
	testing.expect(t, strings.contains(out, `name="c-value"`))
	testing.expect(t, strings.contains(out, `name="c-value-end"`))
}

/* For a parent that owns the field -- two inputs with one name would post
twice. */
@(test)
test_calendar_hide_hidden_input :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ calendar({id = "c", hide_hidden_input = true, mode = .Range}) }
	})
	testing.expect(t, !strings.contains(out, `type="hidden"`))
	testing.expect(t, strings.contains(out, `data-oh-calendar-container="true"`))
}

/* Twelve month options and the whole span of years, newest first. */
@(test)
test_calendar_select_options :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ calendar({id = "c", initial_year = 2026, initial_month = 7}) }
	})
	testing.expect_value(t, strings.count(out, "data-oh-calendar-month-index="), 12)
	testing.expect_value(t, strings.count(out, "<option"), 12 + (YEAR_MAX - YEAR_MIN + 1))
	testing.expect(t, strings.contains(out, `<option value="2100">2100</option>`))
	testing.expect(t, strings.contains(out, `<option value="2026" selected>2026</option>`))

	// Exactly one month and one year are marked, and `selected` is a bare
	// boolean rather than selected="false" on the rest.
	testing.expect_value(t, strings.count(out, " selected"), 2)
}

/* The captions are English until calendar.ts localises them, and they are what
the script writes into. */
@(test)
test_calendar_captions :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ calendar({id = "c", initial_year = 2026, initial_month = 7}) }
	})
	testing.expect(t, strings.contains(out, `<span id="c-month-value" data-oh-calendar-month-value>Jul</span>`))
	testing.expect(t, strings.contains(out, `<span id="c-year-value" data-oh-calendar-year-value>2026</span>`))
}

/* It takes no children: what follows the call is a sibling of the wrapper. */
@(test)
test_calendar_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ calendar({id = "c"}) }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "</oh-calendar>after"))
}

@(test)
test_calendar_class_and_attrs_go_to_the_wrapper :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ calendar({id = "c", class = "w-full"}, hx.get("/c"), a.data("testid", "c")) }
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-calendar class="contents"><div class="` +
			WRAPPER +
			` w-full" id="c-wrapper" data-oh-calendar-wrapper="true" hx-get="/c" data-testid="c">`,
		),
	)
}

/* The structural contract (README.md, "The contract test"): calendar.ts declares in
calendar.contract.json everything it reads from this component's markup, and
this test asserts the rendered markup carries all of it. The day-cell
attributes the class writes into the grid stay out: nothing on this side
renders or matches them, so there is no agreement to test. */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/calendar.contract.json"

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
test_calendar_contract :: proc(t: ^testing.T) {
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
		{ calendar({id = "c", mode = .Range, value = Date{2026, 7, 30}}) }
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
