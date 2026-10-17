/* Calendar, ported from templui's components/calendar/calendar.templ.

A month view with a header, two selects and a grid of days:

    {calendar.calendar({id = "due", name = "due_date", value = calendar.Date{2026, 7, 30}})}

One component, and it takes no children -- its braces are the void-element
kind.

## The grid is not here

data-oh-calendar-weekdays and data-oh-calendar-days are rendered empty, and
web/src/ui/calendar.ts fills both. So a page without the bundle shows the
header, the month and year selects, and nothing under them. That is upstream's
arrangement: the grid depends on the locale and on which month is being looked
at, and both change without a round trip.

What *is* rendered is the state the script starts from -- the selected date,
the range end, the initial month and year, the locale and the first day of the
week, all as data attributes on the container -- plus the hidden inputs that
post.

## id is required

Unlike every other component in this collection, calendar cannot do without
one. The old calendar.js reached the month and year captions with
`#${container.id}-month-value` -- with no id, a syntax error that threw and
took every other calendar on the page down. The element now finds the captions
by role attribute, so that hazard is gone, but the requirement stays: the id
still names the wrapper, the two hidden inputs, the two selects and the two
captions, and an API that sometimes requires the id and sometimes does not is
worse than one that always does.

Upstream avoids this by generating a random id. This port does not invent ids
(see toggle's file comment), so an id-less calendar renders an error span and
nothing else.

The id is used seven more times -- the wrapper, the two hidden inputs, the
two selects, and the two captions -- so it wants to be unique on the page
rather than merely present.

## initial_month is 1-12 here, and that is a deviation

Upstream takes 0-11 and then cannot tell January from unset, so it treats a
zero as "unset" unless InitialYear was also given: `{InitialMonth: 0}` alone
silently shows the current month instead of January.

Here the prop is 1-12 with 0 meaning unset, which makes January reachable on
its own. The attribute the script reads is still 0-11.

## Dates

value and end_value are core:time/datetime's Date, wrapped in Maybe so that
"no date" is expressible -- upstream uses a *time.Time for the same reason.
Only the date part is used; a calendar has no opinion about the time of day.

The month and year the view opens on come from the server's clock when nothing
else decides them, which is the one place this component is not a pure function
of its props.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package calendar

import "core:fmt"
import "core:strings"
import "core:time"
import "core:time/datetime"

import "html:html/a"
import "html:html/h"

import "ui:ui/icon"

/* core:time's, so a caller already holding one passes it straight in. month is
1-12 and day is 1-31. */
Date :: datetime.Date

/* The locales upstream names. Any BCP 47 tag works -- the string is handed to
Intl.DateTimeFormat in the browser, not parsed here -- so this is a list of the
ones templui documents rather than a closed set. */
Locale :: enum {
	En_US,
	Zh_CN,
	Fr_FR,
	De_DE,
	It_IT,
	Ja_JP,
	Pt_PT,
	Es_ES,
}

Day :: enum {
	Sunday,
	Monday,
	Tuesday,
	Wednesday,
	Thursday,
	Friday,
	Saturday,
}

Mode :: enum {
	Single,
	Range,
}

Props :: struct {
	// Required -- see the file comment.
	id:                string,
	class:             string,
	locale:            Locale,
	mode:              Mode,

	// The selected date, or the range's start.
	value:             Maybe(Date),

	// The range's end. Ignored unless mode is .Range.
	end_value:         Maybe(Date),

	// Hidden input name for value. Defaults to <id>-value.
	name:              string,

	// Hidden input name for end_value. Defaults to <name>-end.
	end_name:          string,

	// 1-12, or 0 for unset -- see the file comment.
	initial_month:     int,

	// Zero or negative means unset.
	initial_year:      int,

	// Defaults to Monday.
	start_of_week:     Maybe(Day),

	/* For a parent that owns the form field -- datepicker does, and two
	inputs with the same name would post twice. */
	hide_hidden_input: bool,
}

@(private)
WRAPPER_BASE :: "inline-flex flex-col [--cell-size:2rem]"
@(private)
CONTAINER_BASE :: "inline-flex flex-col"

@(private)
HEADER_BASE :: "flex w-full items-center gap-2 mb-4"
@(private)
ARROW_BASE ::
	"inline-flex items-center justify-center rounded-md text-sm font-medium h-7 w-7 " +
	"hover:bg-accent hover:text-accent-foreground focus:outline-none " +
	"disabled:opacity-50 shrink-0"

@(private)
SELECTS_BASE :: "flex gap-2 flex-1 min-w-0"

/* The frame around each native select. has-[:focus] is what gives it a focus
ring, since the select itself is invisible. */
@(private)
SELECT_FRAME ::
	"relative flex-1 has-[:focus]:border-ring border border-input shadow-xs " +
	"has-[:focus]:ring-ring/50 has-[:focus]:ring-[3px] rounded-md"

/* The real control, laid over the caption and transparent: the platform's own
dropdown, with the styled span showing through beneath it.

bg-card is upstream's fix for dark-mode Chrome, which paints an opaque
background behind a transparent select. */
@(private)
SELECT_INPUT :: "absolute inset-0 opacity-0 cursor-pointer w-full bg-card"

@(private)
SELECT_CAPTION ::
	"select-none font-medium rounded-md px-2 flex items-center justify-center gap-1 " +
	"text-sm h-7 pointer-events-none"
@(private)
SELECT_CHEVRON :: "size-3.5 text-muted-foreground"

/* Both grids are seven cells wide and both are empty until calendar.ts fills
them. --cell-size is set on the wrapper, so a caller can widen the whole
calendar by overriding one variable.

Two constants rather than one plus a margin, because upstream writes two string
literals and they differ by where mb-1 sits in the list. */
@(private)
WEEKDAYS_BASE :: "inline-grid grid-cols-[repeat(7,var(--cell-size))] gap-1 mb-1 place-items-center"
@(private)
GRID_BASE :: "inline-grid grid-cols-[repeat(7,var(--cell-size))] gap-1 place-items-center"

@(private)
ERROR_CLASS :: "text-xs text-destructive"

/* English, and replaced by calendar.ts with the locale's own at init. Rendered
anyway so the caption is not blank before the script runs. */
@(private)
MONTH_NAMES :: [12]string{"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}

// The span of years the select offers, newest first, as upstream has it.
@(private)
YEAR_MAX :: 2100
@(private)
YEAR_MIN :: 1900

/* Public because datepicker renders the same tag onto its own trigger and
would otherwise keep a second copy of this list. */
locale_tag :: proc(l: Locale) -> string {
	switch l {
	case .En_US:
		return "en-US"
	case .Zh_CN:
		return "zh-CN"
	case .Fr_FR:
		return "fr-FR"
	case .De_DE:
		return "de-DE"
	case .It_IT:
		return "it-IT"
	case .Ja_JP:
		return "ja-JP"
	case .Pt_PT:
		return "pt-PT"
	case .Es_ES:
		return "es-ES"
	}
	return "en-US"
}

// Public for the same reason as locale_tag.
mode_attr :: proc(m: Mode) -> string {
	return m == .Range ? "range" : "single"
}

/* ISO 8601, which is what the hidden inputs post and what calendar.ts parses
back. An unset date is the empty string rather than a zero date -- the script
tests for emptiness.

Public because datepicker writes the same format into its own hidden inputs. */
iso_date :: proc(d: Maybe(Date)) -> string {
	date, ok := d.?
	if !ok {
		return ""
	}
	return fmt.tprintf("%04d-%02d-%02d", date.year, date.month, date.day)
}

@(private)
suffixed :: proc(id, suffix: string) -> string {
	return strings.concatenate({id, suffix}, context.temp_allocator)
}

/* Which month and year the view opens on. The value wins, then the explicit
props, then the server's clock -- and the month and year are decided
separately, so pinning a year without a month is meaningful. */
@(private)
initial_view :: proc(props: Props) -> (month, year: int) {
	now_year, now_month, _ := time.date(time.now())
	month = int(now_month) - 1
	year = now_year

	if date, ok := props.value.?; ok {
		month = int(date.month) - 1
		year = int(date.year)
	}

	if props.initial_year > 0 {
		year = props.initial_year
	}
	if props.initial_month >= 1 && props.initial_month <= 12 {
		month = props.initial_month - 1
	}
	return
}

calendar :: proc(props := Props{}, attrs: ..a.Attr) {
	/* Nothing renders without an id: calendar.ts would build an invalid
	selector from it and throw, which stops every calendar on the page rather
	than just this one. */
	if props.id == "" {
		{h.span(a.class(ERROR_CLASS))
			h.text("Error: Calendar missing required 'ID' attribute.")
		}
		return
	}

	month, year := initial_view(props)
	selected := iso_date(props.value)
	end := props.mode == .Range ? iso_date(props.end_value) : ""

	name := props.name != "" ? props.name : suffixed(props.id, "-value")
	end_name := props.end_name != "" ? props.end_name : suffixed(name, "-end")

	start_of_week := Day.Monday
	if d, ok := props.start_of_week.?; ok {
		start_of_week = d
	}

	{h.elem("oh-calendar", a.class("contents"))
		{h.div(
				..a.join(
					[]a.Attr {
						a.class(WRAPPER_BASE, props.class),
						a.id(suffixed(props.id, "-wrapper")),
						a.data("oh-calendar-wrapper", "true"),
					},
					attrs,
				),
			)
			if !props.hide_hidden_input {
				{h.input(
						a.type("hidden"),
						a.name(name),
						a.value(selected),
						a.id(suffixed(props.id, "-hidden")),
						a.data("oh-calendar-hidden-input", true),
					)
				}

				// The blank line above is load bearing: an element block directly
				// under the close of an if trips -strict-style, which reads it as
				// an else.
				if props.mode == .Range {
					{h.input(
							a.type("hidden"),
							a.name(end_name),
							a.value(end),
							a.id(suffixed(props.id, "-hidden-end")),
							a.data("oh-calendar-hidden-end-input", true),
						)
					}
				}
			}

			{h.div(
					a.id(props.id),
					a.class(CONTAINER_BASE),
					a.data("oh-calendar-container", "true"),
					a.data("oh-calendar-mode", mode_attr(props.mode)),
					a.data("oh-calendar-locale-tag", locale_tag(props.locale)),
					a.data("oh-calendar-initial-month", month),
					a.data("oh-calendar-initial-year", year),
					a.data("oh-calendar-selected-date", selected),
					a.data("oh-calendar-end-date", end),
					a.data("oh-calendar-start-of-week", int(start_of_week)),
				)
				{h.div(a.class(HEADER_BASE))
					{h.button(a.type("button"), a.data("oh-calendar-prev", true), a.class(ARROW_BASE))
						{ icon.icon(.Chevron_Left) }
					}

					{h.div(a.class(SELECTS_BASE))
						month_select(props.id, month)
						year_select(props.id, year)
					}

					{h.button(a.type("button"), a.data("oh-calendar-next", true), a.class(ARROW_BASE))
						{ icon.icon(.Chevron_Right) }
					}
				}

				{ h.div(a.data("oh-calendar-weekdays", true), a.class(WEEKDAYS_BASE)) }
				{ h.div(a.data("oh-calendar-days", true), a.class(GRID_BASE)) }
			}
		}
	}
}

/* The month picker: a transparent native select over a styled caption. The
caption carries a role attribute for calendar.ts to write the localised month
into -- it used to be found by an id-derived selector, which is what made a
missing id throw; the role lookup cannot. The id stays on the caption because
it always rendered there, and on the select for stability. */
@(private)
month_select :: proc(id: string, month: int) {
	names := MONTH_NAMES

	{h.div(a.class(SELECT_FRAME))
		{h.select(
				a.id(suffixed(id, "-month-select")),
				a.data("oh-calendar-month-select", true),
				a.class(SELECT_INPUT),
				a.aria("label", "Choose the Month"),
			)
			for i in 0 ..< 12 {
				{h.option(a.value(i), a.selected(i == month), a.data("oh-calendar-month-index", i))
					h.text(names[i])
				}
			}
		}

		{h.span(a.class(SELECT_CAPTION), a.aria("hidden", "true"))
			{h.span(a.id(suffixed(id, "-month-value")), a.data("oh-calendar-month-value", true))
				h.text(names[clamp(month, 0, 11)])
			}
			{ icon.icon(.Chevron_Down, {class = SELECT_CHEVRON}) }
		}
	}
}

/* The year picker, newest first. Two hundred and one options, which is what
upstream renders and the reason a page with several calendars is not small. */
@(private)
year_select :: proc(id: string, year: int) {
	{h.div(a.class(SELECT_FRAME))
		{h.select(
				a.id(suffixed(id, "-year-select")),
				a.data("oh-calendar-year-select", true),
				a.class(SELECT_INPUT),
				a.aria("label", "Choose the Year"),
			)
			for y := YEAR_MAX; y >= YEAR_MIN; y -= 1 {
				{h.option(a.value(y), a.selected(y == year))
					h.text(fmt.tprintf("%d", y))
				}
			}
		}

		{h.span(a.class(SELECT_CAPTION), a.aria("hidden", "true"))
			{h.span(a.id(suffixed(id, "-year-value")), a.data("oh-calendar-year-value", true))
				h.text(fmt.tprintf("%d", year))
			}
			{ icon.icon(.Chevron_Down, {class = SELECT_CHEVRON}) }
		}
	}
}
