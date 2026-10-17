/* Sheet, ported from templui's components/sheet/sheet.templ.

A dialog that slides in from an edge instead of appearing in the middle:

    {sheet.sheet({id = "filters", side = .Left})
        {sheet.trigger()
            {button.button({variant = .Outline}); h.text("Filters")}
        }
        {sheet.content({side = .Left})
            {sheet.header()
                {sheet.title(); h.text("Filters")}
            }
            {sheet.footer()
                {sheet.close()
                    {button.button(); h.text("Apply")}
                }
            }
        }
    }

All eight take children and all eight need braces at the call site.

Every one of them is dialog's element with different classes -- there is no
markup of its own here. So the browser still owns the top layer, the backdrop
and the focus trap, and dialog's <oh-dialog> element still drives it; a sheet
is a dialog as far as both are concerned, which is why there is no sheet.ts.
The slide states are keyed on the native `open` attribute with @starting-style
for the way in, exactly as dialog's own fade is.

## How it overrides dialog

dialog centres its content and scales it in. A sheet has to undo both, and does
it with `!` utilities rather than by not setting them -- !translate-x-0 against
dialog's -translate-x-1/2, !scale-100 against its scale-95, !rounded-none
against its rounded-lg, !p-0 so the header and footer own their own padding.

That is upstream's approach and it survives the port unchanged, which is worth
saying because this collection has no TwMerge: without the `!` prefixes the two
class lists would simply both apply and the later-declared utility would win by
stylesheet order rather than by intent. Upstream needed them for TwMerge to
keep them; this port needs them for the cascade to.

## Where that does not hold

content is the only one upstream marked. header, title and footer override
dialog's spacing and alignment with ordinary utilities, and relied on TwMerge
to drop the ones they replace. Here both sets reach the element, and which
applies is decided by the stylesheet's source order rather than by this file --
the same caveat button/button.odin records for a caller's class, except that
here it is the component itself colliding rather than the caller.

So a sheet's header and footer may take dialog's spacing instead of their own.
Left as upstream wrote it rather than papered over with `!` prefixes it does
not have: adding them would be inventing a fix for a problem the whole
collection shares, and the place to solve it is a TwMerge, once.

## side, and the deviation

Upstream puts the side in the Go context in Sheet() and reads it back in
Content(). There is no context here, so both take it, and they have to agree --
the deviation dialog used to make for `open`, kept here for `side` after
dialog's own copy dissolved with the state attributes.

Right is the zero value, as upstream falls back to.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package sheet

import "core:strings"

import "html:html/a"
import "html:html/h"

import "ui:ui/dialog"

Side :: enum {
	Right,
	Left,
	Top,
	Bottom,
}

Props :: struct {
	id:                 string,
	class:              string,
	side:               Side,
	disable_click_away: bool,
	disable_esc:        bool,
}

Trigger_Props :: struct {
	id:    string,
	class: string,

	// The sheet root's id, for a trigger that is not inside it.
	for_:  string,
}

/* No id, as dialog's content has none. side has to match the root's -- see
the file comment. open is dialog's initial-open: consumed once at connect. */
Content_Props :: struct {
	class:             string,
	hide_close_button: bool,
	side:              Side,
	open:              bool,
}

Header_Props :: struct {
	id:    string,
	class: string,
}

Footer_Props :: struct {
	id:    string,
	class: string,
}

Title_Props :: struct {
	id:    string,
	class: string,
}

Description_Props :: struct {
	id:    string,
	class: string,
}

Close_Props :: struct {
	id:    string,
	class: string,
	for_:  string,
}

/* Shared by all four sides. The transition property list replaces dialog's
transition-all so only the slide animates -- a sheet that also faded would
show the page through itself on the way in -- but display and overlay stay in
the list: the discrete transition of those two is what holds a closing sheet
visible and in the top layer through its slide out.

The two durations are upstream's: quicker to leave than to arrive. */
@(private)
SIDE_BASE ::
	"fixed z-50 flex flex-col bg-background shadow-lg " +
	"!transition-[transform,display,overlay] transition-discrete ease-in-out " +
	"duration-300 open:duration-500"

/* One constant per side, each in upstream's order: position, size, border,
the transform reset, then the slide -- off-screen at rest and in
@starting-style, home while open. The reset is what undoes dialog's centring
-- without it the sheet would sit half a viewport off. */
@(private)
SIDE_RIGHT ::
	"!top-0 !bottom-0 !right-0 !left-auto " +
	"!h-dvh !max-h-dvh w-3/4 sm:!max-w-sm " +
	"border-l border-t-0 border-r-0 border-b-0 " +
	"!translate-y-0 !translate-x-full " +
	"open:!translate-x-0 starting:open:!translate-x-full"

@(private)
SIDE_LEFT ::
	"!top-0 !bottom-0 !left-0 !right-auto " +
	"!h-dvh !max-h-dvh w-3/4 sm:!max-w-sm " +
	"border-r border-t-0 border-l-0 border-b-0 " +
	"!translate-y-0 !-translate-x-full " +
	"open:!translate-x-0 starting:open:!-translate-x-full"

@(private)
SIDE_TOP ::
	"!inset-x-0 !top-0 !bottom-auto !left-0 !right-0 " +
	"!w-full !max-w-full h-auto " +
	"border-b border-t-0 border-l-0 border-r-0 " +
	"!translate-x-0 !-translate-y-full " +
	"open:!translate-y-0 starting:open:!-translate-y-full"

@(private)
SIDE_BOTTOM ::
	"!inset-x-0 !bottom-0 !top-auto !left-0 !right-0 " +
	"!w-full !max-w-full h-auto " +
	"border-t border-b-0 border-l-0 border-r-0 " +
	"!translate-x-0 !translate-y-full " +
	"open:!translate-y-0 starting:open:!translate-y-full"

/* What dialog set that a sheet has to unset. Each is `!` because dialog's own
utility is still in the class list beside it -- including dialog's state and
starting-style rules, which the unconditional `!` outranks in the cascade. */
@(private)
CONTENT_OVERRIDES :: "!p-0 !scale-100 !rounded-none !opacity-100"

@(private)
HEADER_BASE :: "gap-1.5 p-4 text-left"
@(private)
TITLE_BASE :: "text-base leading-normal"
@(private)
FOOTER_BASE :: "mt-auto flex flex-col gap-2 p-4"

@(private)
side_attr :: proc(s: Side) -> string {
	switch s {
	case .Right:
		return "right"
	case .Left:
		return "left"
	case .Top:
		return "top"
	case .Bottom:
		return "bottom"
	}
	return "right"
}

@(private)
side_classes :: proc(s: Side) -> string {
	switch s {
	case .Right:
		return SIDE_RIGHT
	case .Left:
		return SIDE_LEFT
	case .Top:
		return SIDE_TOP
	case .Bottom:
		return SIDE_BOTTOM
	}
	return SIDE_RIGHT
}

/* dialog's Props.class is a string rather than an attribute list, so the parts
are joined by hand. Into the temp allocator, which is the render arena and
freed with the page. */
@(private)
joined :: proc(parts: ..string) -> string {
	kept := make([dynamic]string, 0, len(parts) * 2, context.temp_allocator)
	for p in parts {
		if p == "" {
			continue
		}
		if len(kept) > 0 {
			append(&kept, " ")
		}
		append(&kept, p)
	}
	return strings.concatenate(kept[:], context.temp_allocator)
}

@(deferred_none = h.close_all)
sheet :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		dialog.dialog_open(
			{
				id = props.id,
				class = props.class,
				disable_click_away = props.disable_click_away,
				disable_esc = props.disable_esc,
			},
			..a.join([]a.Attr{a.data("oh-sheet", "true"), a.data("oh-sheet-side", side_attr(props.side))}, attrs),
		)
	}
}

@(deferred_none = h.close_all)
trigger :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		dialog.trigger_open({id = props.id, class = props.class, for_ = props.for_}, ..attrs)
	}
}

/* Returns hide_close_button for the deferred half -- see the comment on
popover.content for why the flag rides the return value. */
@(deferred_out = content_close)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) -> bool {
	{h.open_scope()
		return dialog.content_open(
			{
				class = joined(SIDE_BASE, side_classes(props.side), CONTENT_OVERRIDES, props.class),
				hide_close_button = props.hide_close_button,
				open = props.open,
			},
			..a.join(
				[]a.Attr{a.data("oh-sheet-content", "true"), a.data("oh-sheet-side", side_attr(props.side))},
				attrs,
			),
		)
	}
}

/* dialog writes the trailing close button, this closes back to its own mark. */
@(private)
content_close :: proc(hide_close_button: bool) {
	dialog.content_trailing(hide_close_button)
	h.close_all()
}

@(deferred_none = h.close_all)
header :: proc(props := Header_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		dialog.header_open({id = props.id, class = joined(HEADER_BASE, props.class)}, ..attrs)
	}
}

@(deferred_none = h.close_all)
title :: proc(props := Title_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		dialog.title_open({id = props.id, class = joined(TITLE_BASE, props.class)}, ..attrs)
	}
}

/* dialog's, unchanged -- the only one of the eight that adds nothing. Kept as
its own proc so a sheet reads as a sheet throughout. */
@(deferred_none = h.close_all)
description :: proc(props := Description_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		dialog.description_open({id = props.id, class = props.class}, ..attrs)
	}
}

/* mt-auto, so a footer sits at the bottom of a full-height sheet however
little is above it. */
@(deferred_none = h.close_all)
footer :: proc(props := Footer_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		dialog.footer_open({id = props.id, class = joined(FOOTER_BASE, props.class)}, ..attrs)
	}
}

@(deferred_none = h.close_all)
close :: proc(props := Close_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		dialog.close_open({id = props.id, class = props.class, for_ = props.for_}, ..attrs)
	}
}
