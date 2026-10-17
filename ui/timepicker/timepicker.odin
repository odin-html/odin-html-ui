/* Time picker, ported from templui's components/timepicker/timepicker.templ.

A button that opens two scrolling lists in a popover, and posts what was
picked:

    {timepicker.timepicker({id = "start", name = "start_at", step = 15})}

One component, and it takes no children -- its braces are the void-element
kind. Like datepicker it is a composition: popover, button and card, with a
hidden input in front.

## What is rendered, and what is not

Every hour and every minute the step allows is written out as a button, with
data-oh-timepicker-selected="false" on all of them. web/src/ui/timepicker.ts
marks one of each when a value is chosen and writes the formatted time into the
caption. So the lists are complete before any script runs, and nothing in them
is selected -- including when the server sent a value, which reaches the page
only in the hidden input and in data-oh-timepicker-value on the popup.

step is what decides how long the minute list is: 1 gives sixty buttons, 15
gives four. Minutes only -- the hour list is always whole hours.

## 12 or 24 hours

use_12_hours swaps the hour list for 12 and 01-11, and adds the AM/PM pair
below. The value in the hidden input is 24-hour either way, which is what makes
the choice presentational: `13:30` posts the same whether it was picked as
13:30 or 1:30 PM.

The AM and PM captions are props because they are words -- some locales write
them differently -- but the data attribute the script matches on stays "AM" and
"PM".

## id

Not needed by the script, which works from data attributes throughout. It is
the button's id and the fallback for `name`, so a picker with neither renders a
hidden input with no name and posts nothing.

min_time and max_time are handed to the script as "HH:MM" and bound what it
will accept; nothing here removes the buttons outside them.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package timepicker

import "core:fmt"
import "core:strings"
import "core:time/datetime"

import "html:html/a"
import "html:html/h"

import "ui:ui/button"
import "ui:ui/card"
import "ui:ui/icon"
import "ui:ui/popover"

/* core:time's, so a caller already holding one passes it straight in. Only
hour and minute are used -- a picker with a seconds column is not this
component. */
Time :: datetime.Time

Props :: struct {
	id:           string,
	class:        string,

	// Defaults to the id.
	name:         string,
	form:         string,
	value:        Maybe(Time),

	// Bounds the script accepts, as "HH:MM". The lists are drawn in full
	// regardless.
	min_time:     Maybe(Time),
	max_time:     Maybe(Time),

	// Minutes between entries in the minute list. Zero or negative means 1.
	step:         int,
	use_12_hours: bool,

	// The words on the two period buttons. The attribute stays AM/PM.
	am_label:     string,
	pm_label:     string,
	placeholder:  string,
	disabled:     bool,
	has_error:    bool,
}

@(private)
ROOT_BASE :: "relative inline-block w-full"

/* Grouped the way upstream's own comments group these -- the same list
datepicker's trigger carries, for the same reason: it is a button dressed as an
input. */
@(private)
TRIGGER_BASE :: "w-full h-9 px-3 py-1 text-base md:text-sm"
@(private)
TRIGGER_LAYOUT :: "flex items-center justify-between"
@(private)
TRIGGER_BOX ::
	"rounded-md border border-input bg-transparent shadow-xs " + "transition-[color,box-shadow] outline-none"
@(private)
TRIGGER_DARK :: "dark:bg-input/30"
@(private)
TRIGGER_SELECTION :: "selection:bg-primary selection:text-primary-foreground"
@(private)
TRIGGER_FOCUS :: "focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]"
@(private)
TRIGGER_INVALID ::
	"aria-invalid:ring-destructive/20 aria-invalid:border-destructive " + "dark:aria-invalid:ring-destructive/40"
@(private)
TRIGGER_ERROR :: "border-destructive ring-destructive/20 dark:ring-destructive/40"

@(private)
DISPLAY_CLASS :: "text-left grow text-muted-foreground"
@(private)
ICON_WRAPPER :: "text-muted-foreground flex items-center ml-2"
@(private)
ICON_CLASS :: "size-4"

@(private)
CONTENT_CLASS :: "p-0 w-80"
@(private)
CARD_CLASS :: "border-0 shadow-none"
@(private)
CARD_CONTENT_CLASS :: "p-4"

@(private)
GRID_CLASS :: "grid grid-cols-2 gap-3 mb-4"
@(private)
COLUMN_CLASS :: "space-y-2"
@(private)
COLUMN_LABEL :: "text-sm font-medium"

// max-h-32 with overflow-y-auto is what makes each column a scrolling list
// rather than a very tall one.
@(private)
LIST_FRAME :: "max-h-32 overflow-y-auto border rounded-md bg-background"
@(private)
LIST_INNER :: "p-1 space-y-0.5"

/* The selected look is a data-[oh-timepicker-selected=true] rule, so the only
thing the script writes is the attribute. */
@(private)
ENTRY_CLASS ::
	"w-full px-2 py-1 text-sm rounded transition-colors text-left " +
	"hover:bg-accent hover:text-accent-foreground " +
	"data-[oh-timepicker-selected=true]:bg-primary " +
	"data-[oh-timepicker-selected=true]:text-primary-foreground " +
	"data-[oh-timepicker-selected=true]:hover:bg-primary/90"

@(private)
FOOTER_CLASS :: "flex justify-between items-center"
@(private)
PERIOD_GROUP :: "flex gap-1"
@(private)
PERIOD_CLASS ::
	"px-3 py-1 text-sm rounded-md border transition-colors " +
	"hover:bg-accent hover:text-accent-foreground " +
	"data-[oh-timepicker-active=true]:bg-primary " +
	"data-[oh-timepicker-active=true]:text-primary-foreground " +
	"data-[oh-timepicker-active=true]:hover:bg-primary/90"

@(private)
DEFAULT_PLACEHOLDER :: "Select time"
@(private)
DEFAULT_AM :: "AM"
@(private)
DEFAULT_PM :: "PM"
@(private)
DEFAULT_STEP :: 1

/* "HH:MM", which is what the hidden input posts and what timepicker.ts parses.
An unset time is the empty string. */
@(private)
hhmm :: proc(t: Maybe(Time)) -> string {
	v, ok := t.?
	if !ok {
		return ""
	}
	return fmt.tprintf("%02d:%02d", v.hour, v.minute)
}

@(private)
bool_attr :: proc(b: bool) -> string {
	return b ? "true" : "false"
}

timepicker :: proc(props := Props{}, attrs: ..a.Attr) {
	name := props.name != "" ? props.name : props.id
	placeholder := props.placeholder != "" ? props.placeholder : DEFAULT_PLACEHOLDER
	am := props.am_label != "" ? props.am_label : DEFAULT_AM
	pm := props.pm_label != "" ? props.pm_label : DEFAULT_PM
	step := props.step > 0 ? props.step : DEFAULT_STEP

	value := hhmm(props.value)

	{h.elem("oh-timepicker", a.class("contents"))
		{h.div(a.class(ROOT_BASE))
			{popover.root()
				{h.input(
						a.type("hidden"),
						a.attr_if(name != "", a.name(name)),
						a.value(value),
						a.attr_if(props.form != "", a.form(props.form)),
						a.data("oh-timepicker-hidden-input", "true"),
					)
				}

				{popover.trigger()
					{button.button(
							{id = props.id, variant = .Outline, class = trigger_class(props), disabled = props.disabled},
							/* Upstream's precedence, and this collection's
						 exception: the caller's attributes first, the script's own
						 last -- the same arrangement datepicker makes, for the
						 same reason. */
							..a.join(
								attrs,
								[]a.Attr {
									a.data("oh-timepicker-trigger", "true"),
									a.data("oh-timepicker-use12hours", bool_attr(props.use_12_hours)),
									a.data("oh-timepicker-am-label", am),
									a.data("oh-timepicker-pm-label", pm),
									a.data("oh-timepicker-placeholder", placeholder),
									a.data("oh-timepicker-step", step),
									a.data("oh-timepicker-min-time", hhmm(props.min_time)),
									a.data("oh-timepicker-max-time", hhmm(props.max_time)),
									a.attr_if(props.has_error, a.aria("invalid", "true")),
								},
							),
						)
						{h.span(a.data("oh-timepicker-display", true), a.class(DISPLAY_CLASS))
							h.text(placeholder)
						}

						{h.span(a.class(ICON_WRAPPER))
							{ icon.icon(.Clock, {class = ICON_CLASS}) }
						}
					}
				}

				{popover.content({placement = .Bottom_Start, class = CONTENT_CLASS})
					{card.card({class = CARD_CLASS})
						{card.content({class = CARD_CONTENT_CLASS})
							{h.div(
									a.data("oh-timepicker-popup", "true"),
									a.data("oh-timepicker-input-name", name),
									a.attr_if(value != "", a.data("oh-timepicker-value", value)),
								)
								{h.div(a.class(GRID_CLASS))
									hour_column(props.use_12_hours)
									minute_column(step)
								}

								{h.div(a.class(FOOTER_CLASS))
									if props.use_12_hours {
										{h.div(a.class(PERIOD_GROUP))
											period("AM", am)
											period("PM", pm)
										}
									} else {
										// An empty div, as upstream has it: the
										// footer is justify-between, so the Done
										// button needs something to be pushed
										// away from.
										{ h.div() }
									}

									{button.button(
											{type = .Button, variant = .Secondary, size = .Sm},
											a.data("oh-timepicker-done", "true"),
										)
										h.text("Done")
									}
								}
							}
						}
					}
				}
			}
		}
	}
}

/* Whole hours, and none of them marked -- timepicker.ts selects one when there
is a value. In 12-hour form the list starts at 12 and runs 01-11, which is how
a clock face reads rather than how the hours count. */
@(private)
hour_column :: proc(use_12_hours: bool) {
	{h.div(a.class(COLUMN_CLASS))
		{ h.label(a.class(COLUMN_LABEL)); h.text("Hour") }

		{h.div(a.class(LIST_FRAME))
			{h.div(a.data("oh-timepicker-hour-list", "true"), a.class(LIST_INNER))
				if use_12_hours {
					entry("oh-timepicker-hour", 0, "12")
					for hour in 1 ..= 11 {
						entry("oh-timepicker-hour", hour, fmt.tprintf("%02d", hour))
					}
				} else {
					for hour in 0 ..< 24 {
						entry("oh-timepicker-hour", hour, fmt.tprintf("%02d", hour))
					}
				}
			}
		}
	}
}

@(private)
minute_column :: proc(step: int) {
	{h.div(a.class(COLUMN_CLASS))
		{ h.label(a.class(COLUMN_LABEL)); h.text("Minute") }

		{h.div(a.class(LIST_FRAME))
			{h.div(a.data("oh-timepicker-minute-list", "true"), a.class(LIST_INNER))
				for minute := 0; minute < 60; minute += step {
					entry("oh-timepicker-minute", minute, fmt.tprintf("%02d", minute))
				}
			}
		}
	}
}

@(private)
entry :: proc(attr: string, value: int, caption: string) {
	{h.button(a.type("button"), a.data(attr, value), a.data("oh-timepicker-selected", "false"), a.class(ENTRY_CLASS))
		h.text(caption)
	}
}

/* The attribute stays AM or PM whatever the caption says, so the script does
not have to know the caller's language. */
@(private)
period :: proc(value, caption: string) {
	{h.button(
			a.type("button"),
			a.data("oh-timepicker-period", value),
			a.data("oh-timepicker-active", "false"),
			a.class(PERIOD_CLASS),
		)
		h.text(caption)
	}
}

/* button's Props.class is a string rather than an attribute list, so the parts
are joined by hand. Into the temp allocator, which is the render arena. */
@(private)
trigger_class :: proc(props: Props) -> string {
	parts := [dynamic]string{}
	parts.allocator = context.temp_allocator

	for p in ([]string {
			TRIGGER_BASE,
			TRIGGER_LAYOUT,
			TRIGGER_BOX,
			TRIGGER_DARK,
			TRIGGER_SELECTION,
			TRIGGER_FOCUS,
			TRIGGER_INVALID,
			props.has_error ? TRIGGER_ERROR : "",
			props.class,
		}) {
		if p == "" {
			continue
		}
		if len(parts) > 0 {
			append(&parts, " ")
		}
		append(&parts, p)
	}
	return strings.concatenate(parts[:], context.temp_allocator)
}
