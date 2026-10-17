/* Date picker, ported from templui's components/datepicker/datepicker.templ.

A button that opens a calendar in a popover, and posts what was picked:

    {datepicker.datepicker({id = "due", name = "due_date", value = calendar.Date{2026, 7, 30}})}

One component, and it takes no children -- its braces are the void-element
kind. It is a composition rather than markup of its own: popover, button, card
and calendar, with a hidden input in front.

## Where the value lives

The hidden input is the field that posts, in ISO 8601. The button's caption is
a placeholder until the <oh-datepicker> element (web/src/ui/datepicker.ts)
writes a formatted date into it, and the calendar inside carries
hide_hidden_input so that only one input is posting -- two with the same name
would send the date twice.

Opening and closing the calendar popover is the browser's
(popover="auto"); the element's one interaction with it is closing on a
completed selection, through the content's own hidePopover().

Which means a page without the bundle shows the placeholder even when the
server sent a value, and posts the value correctly. The formatting is the
browser's: `format` and `locale` are handed to Intl.DateTimeFormat, so the
same date reads 30/07/2026 or Jul 30, 2026 or 30. Juli 2026 without the server
knowing which.

## id is required

Not for datepicker's own sake -- datepicker.ts works entirely from data
attributes -- but for the calendar inside it, which needs one and cannot invent
one. See calendar's file comment for why that failure is loud rather than
quiet.

The calendar's id is this one with "-calendar" appended, so a page can hold
several pickers without their calendars colliding.

## Attribute precedence, which is upstream's rather than this collection's

Everywhere else here a caller's attributes are spread last and win. Upstream
merges the other way for this component, so the data-oh-datepicker-* group
overrides anything passed in. Kept: those attributes are what the element
reads, and a caller who overwrites data-oh-datepicker-mode gets a picker that
no longer agrees with its own calendar.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package datepicker

import "core:strings"

import "html:html/a"
import "html:html/h"

import "ui:ui/button"
import cal "ui:ui/calendar"
import "ui:ui/card"
import "ui:ui/icon"
import "ui:ui/popover"

/* Intl.DateTimeFormat's dateStyle values. The browser turns one of these plus
a locale into a date; nothing here formats anything. */
Format :: enum {
	Locale_Medium,
	Locale_Short,
	Locale_Long,
	Locale_Full,
}

/* calendar's, reused rather than restated -- upstream declares the same eight
tags in both packages, and one of them would drift. */
Locale :: cal.Locale

Props :: struct {
	// Required -- see the file comment.
	id:              string,
	class:           string,
	name:            string,
	value:           Maybe(cal.Date),
	form:            string,
	format:          Format,
	locale:          Locale,

	// Defaults to Monday, as calendar's does.
	start_of_week:   Maybe(cal.Day),
	placeholder:     string,
	disabled:        bool,
	has_error:       bool,
	mode:            cal.Mode,

	// Range mode only.
	end_value:       Maybe(cal.Date),
	end_name:        string,
	end_placeholder: string,
}

@(private)
ROOT_BASE :: "relative inline-block w-full"

/* Grouped the way upstream's own comments group these. The button is made to
look like an input rather than a button, which is why it repeats input's
border, shadow and focus ring. */
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

/* text-muted-foreground because what is in it is a placeholder. datepicker.js
does not change the class when it writes a real date, so a chosen date is drawn
in the same muted colour -- upstream's, and visible in the demo. */
@(private)
DISPLAY_CLASS :: "text-left grow text-muted-foreground"
@(private)
ICON_WRAPPER :: "text-muted-foreground flex items-center ml-2"
@(private)
ICON_CLASS :: "size-4"

@(private)
CONTENT_CLASS :: "p-0"
@(private)
CARD_CLASS :: "border-0 shadow-none"
@(private)
CARD_CONTENT_CLASS :: "p-3"

@(private)
DEFAULT_PLACEHOLDER :: "Select a date"
@(private)
DEFAULT_END_PLACEHOLDER :: "End date"

// An en dash, with spaces, between the two placeholders of a range.
@(private)
RANGE_SEPARATOR :: " – "

@(private)
ERROR_CLASS :: "text-xs text-destructive"

@(private)
CALENDAR_SUFFIX :: "-calendar"

@(private)
format_attr :: proc(f: Format) -> string {
	switch f {
	case .Locale_Medium:
		return "locale-medium"
	case .Locale_Short:
		return "locale-short"
	case .Locale_Long:
		return "locale-long"
	case .Locale_Full:
		return "locale-full"
	}
	return "locale-medium"
}

/* ISO 8601 for the hidden inputs, and the empty string for no date -- the same
shape calendar posts. */
@(private)
iso :: proc(d: Maybe(cal.Date)) -> string {
	return cal.iso_date(d)
}

@(private)
suffixed :: proc(id, suffix: string) -> string {
	return strings.concatenate({id, suffix}, context.temp_allocator)
}

datepicker :: proc(props := Props{}, attrs: ..a.Attr) {
	/* The calendar inside needs an id and will not invent one, so a picker
	without one cannot be assembled. Failing here rather than there keeps the
	message about the component the caller actually wrote. */
	if props.id == "" {
		{h.span(a.class(ERROR_CLASS))
			h.text("Error: DatePicker missing required 'ID' attribute.")
		}
		return
	}

	is_range := props.mode == .Range

	name := props.name != "" ? props.name : props.id
	end_name := props.end_name != "" ? props.end_name : suffixed(name, "-end")

	placeholder := props.placeholder != "" ? props.placeholder : DEFAULT_PLACEHOLDER
	end_placeholder := props.end_placeholder != "" ? props.end_placeholder : DEFAULT_END_PLACEHOLDER

	start_iso := iso(props.value)
	end_iso := is_range ? iso(props.end_value) : ""

	{h.elem("oh-datepicker", a.class("contents"))
		{h.div(a.class(ROOT_BASE))
			{popover.root()
				{h.input(
						a.type("hidden"),
						a.name(name),
						a.value(start_iso),
						a.attr_if(props.form != "", a.form(props.form)),
						a.data("oh-datepicker-hidden-input", true),
					)
				}

				// The blank line above is load bearing: an element block
				// directly under the close of an if trips -strict-style, which
				// reads it as an else.
				if is_range {
					{h.input(
							a.type("hidden"),
							a.name(end_name),
							a.value(end_iso),
							a.attr_if(props.form != "", a.form(props.form)),
							a.data("oh-datepicker-hidden-end-input", true),
						)
					}
				}

				{popover.trigger()
					{button.button(
							{
								id = props.id,
								variant = .Outline,
								class = trigger_class(props),
								disabled = props.disabled,
							},
							// Upstream's precedence: the caller's first, the
							// element's own last -- see the file comment.
							..a.join(
								attrs,
								[]a.Attr {
									a.data("oh-datepicker-trigger", "true"),
									a.data("oh-datepicker-display-format", format_attr(props.format)),
									a.data("oh-datepicker-locale-tag", cal.locale_tag(props.locale)),
									a.data("oh-datepicker-placeholder", placeholder),
									a.data("oh-datepicker-mode", cal.mode_attr(props.mode)),
									a.data("oh-datepicker-end-placeholder", is_range ? end_placeholder : ""),
									a.attr_if(props.has_error, a.aria("invalid", "true")),
								},
							),
						)
						{h.span(a.data("oh-datepicker-display", true), a.class(DISPLAY_CLASS))
							if is_range {
								h.text(placeholder)
								h.text(RANGE_SEPARATOR)
								h.text(end_placeholder)
							} else {
								h.text(placeholder)
							}
						}

						{h.span(a.class(ICON_WRAPPER))
							{ icon.icon(.Calendar, {class = ICON_CLASS}) }
						}
					}
				}

				{popover.content({placement = .Bottom_Start, class = CONTENT_CLASS})
					{card.card({class = CARD_CLASS})
						{card.content({class = CARD_CONTENT_CLASS})
							{cal.calendar(
									{
										id = suffixed(props.id, CALENDAR_SUFFIX),
										locale = props.locale,
										start_of_week = props.start_of_week,
										mode = props.mode,
										value = props.value,
										end_value = props.end_value,
										hide_hidden_input = true,
									},
								)}
						}
					}
				}
			}
		}
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
