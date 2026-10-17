/* Dialog, ported from templui's components/dialog/dialog.templ.

Eight components: the group, a trigger, the dialog itself, a close, and four
wrappers for laying its contents out.

    {dialog.dialog({id = "confirm"})
        {dialog.trigger()
            {button.button({variant = .Destructive}); h.text("Delete")}
        }
        {dialog.content()
            {dialog.header()
                {dialog.title(); h.text("Delete this bearing?")}
                {dialog.description(); h.text("This cannot be undone.")}
            }
            {dialog.footer()
                {dialog.close()
                    {button.button({variant = .Outline}); h.text("Cancel")}
                }
                {button.button({variant = .Destructive}, hx.delete("/b/1"))
                    h.text("Delete")
                }
            }
        }
    }

All eight take children and all eight need braces at the call site.

## What the browser does and what the element does

content() is a real <dialog>, so the top layer, the backdrop and the focus trap
are the browser's. The <oh-dialog> element (web/src/ui/dialog.ts) calls
showModal() and close() on it, and that is nearly all it does: the
animation classes read the native `open` attribute, with
@starting-style for the way in and discrete display/overlay transitions
holding the node through the way out -- the old data-tui-dialog-open and
-closing attributes, and the timer that sequenced them, are gone. Escape is
the browser's `cancel` event; disable_esc is a preventDefault on it.

The group and the trigger are `contents`: no box of their own, so wrapping a
button leaves the button laid out exactly as it was. The group is the
<oh-dialog> element itself.

A dialog that is `open` on the server still needs the element: showModal() is
the only way into the top layer, and there is no attribute that asks for it.
That is data-oh-dialog-initial-open, which the element consumes once at
connect, so a re-connect never re-opens a dialog the user has closed. Upstream
kept a second, group-level `open`; it reflected state the CSS no longer reads,
and is gone.

## The close button

Written after the caller's children, inside the dialog, which the ordinary
component pairing cannot do -- so content() defers a proc of its own, exactly
as popover's does. hide_close_button rides the return value rather than a
package-level flag, so nested dialogs cannot confuse each other.

trigger() and close() take a `for_` when they sit outside the dialog they act
on; inside it, the script finds the dialog by walking up and they need nothing.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package dialog

import "html:html/a"
import "html:html/h"

import "ui:ui/icon"

Props :: struct {
	id:                 string,
	class:              string,
	disable_click_away: bool,
	disable_esc:        bool,
}

Trigger_Props :: struct {
	id:    string,
	class: string,

	// The dialog root's id, for a trigger that is not inside it.
	for_:  string,
}

/* No id, as upstream has it: the <dialog> is found through the group rather
than by name. */
Content_Props :: struct {
	class:             string,
	hide_close_button: bool,

	/* Opens it without a modal backdrop -- show() rather than showModal(), so
	the page behind stays interactive. */
	disable_modal:     bool,

	// Opened by the element once at connect -- see the file comment.
	open:              bool,
}

Close_Props :: struct {
	id:    string,
	class: string,

	// The dialog root's id, for a close that is not inside it.
	for_:  string,
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

@(private)
ROOT_BASE :: "contents"
@(private)
TRIGGER_BASE :: "contents"
@(private)
CLOSE_BASE :: "contents cursor-pointer"

/* One constant per idea, keyed on the native `open` attribute. */
@(private)
CONTENT_BOX ::
	"fixed left-[50%] top-[50%] z-50 m-0 w-full max-w-[calc(100%-2rem)] " +
	"-translate-x-1/2 -translate-y-1/2 flex-col gap-4 overflow-hidden border " +
	"bg-background p-6 text-foreground shadow-lg outline-none sm:max-w-lg"

/* Closed is display:none and open is flex -- as a transitioned pair, because
the discrete display transition is what holds the node visible through the
exit fade. The UA's own dialog:not([open]) rule would be display:none too, but
the flex above has to be conditional or it would win over it. */
@(private)
CONTENT_HIDDEN :: "hidden open:flex"
@(private)
CONTENT_ROUNDED :: "rounded-lg"

/* The backdrop fades with the dialog: transparent at rest and in
@starting-style, black while open. */
@(private)
CONTENT_BACKDROP ::
	"backdrop:transition-all backdrop:duration-200 backdrop:bg-black/0 " +
	"open:backdrop:bg-black/50 starting:open:backdrop:bg-black/0"

/* transition-all with allow-discrete covers opacity, scale, display and
overlay -- overlay is what keeps a closing dialog in the top layer until the
fade ends. */
@(private)
CONTENT_TRANSITION :: "transition-all transition-discrete duration-200"
@(private)
CONTENT_SCALE :: "scale-95 open:scale-100 starting:open:scale-95"
@(private)
CONTENT_FADE :: "opacity-0 open:opacity-100 starting:open:opacity-0"

/* Grouped the way upstream's own comments group these. Upstream also keyed a
hover look on the button's own data-tui-dialog-open, which nothing ever set --
dead on arrival, deleted with the attribute. */
@(private)
CLOSE_BUTTON_POSITION :: "absolute top-4 right-4"
@(private)
CLOSE_BUTTON_STYLE :: "rounded-xs opacity-70"
@(private)
CLOSE_BUTTON_HOVER :: "transition-opacity hover:opacity-100"
@(private)
CLOSE_BUTTON_FOCUS ::
	"focus:outline-none focus:ring-2 " + "focus:ring-ring focus:ring-offset-2 " + "ring-offset-background"
@(private)
CLOSE_BUTTON_DISABLED :: "disabled:pointer-events-none"
@(private)
CLOSE_BUTTON_ICON :: "[&_svg]:pointer-events-none " + "[&_svg]:shrink-0 " + "[&_svg:not([class*='size-'])]:size-4"

@(private)
HEADER_BASE :: "flex flex-col gap-2 text-center sm:text-left"
@(private)
FOOTER_BASE :: "flex flex-col-reverse gap-2 sm:flex-row sm:justify-end"
@(private)
TITLE_BASE :: "text-lg leading-none font-semibold"
@(private)
DESCRIPTION_BASE :: "text-muted-foreground text-sm"

@(private)
bool_attr :: proc(b: bool) -> string {
	return b ? "true" : "false"
}

dialog_open :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.elem_open(
			"oh-dialog",
			..a.join(
				[]a.Attr {
					a.attr_if(props.id != "", a.id(props.id)),
					a.attr_if(props.disable_click_away, a.data("oh-dialog-disable-click-away", "true")),
					a.attr_if(props.disable_esc, a.data("oh-dialog-disable-esc", "true")),
					a.class(ROOT_BASE, props.class),
				},
				attrs,
			),
		)
	}
}

@(deferred_none = h.close_all)
dialog :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		dialog_open(props, ..attrs)
	}
}

trigger_open :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	{h.span_open(
			..a.join(
				[]a.Attr {
					a.attr_if(props.id != "", a.id(props.id)),
					a.data("oh-dialog-trigger", true),
					a.attr_if(props.for_ != "", a.data("oh-dialog-target", props.for_)),
					a.class(TRIGGER_BASE, props.class),
				},
				attrs,
			),
		)
	}
}

@(deferred_none = h.close_all)
trigger :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		trigger_open(props, ..attrs)
	}
}

/* The _open half, for components built on this one -- sheet is a dialog with
its own geometry. See the same block in popover for why a wrapper cannot call
content(). */
content_open :: proc(props := Content_Props{}, attrs: ..a.Attr) -> bool {
	{h.dialog_open(
			..a.join(
				[]a.Attr {
					a.class(
						CONTENT_BOX,
						CONTENT_HIDDEN,
						CONTENT_ROUNDED,
						CONTENT_BACKDROP,
						CONTENT_TRANSITION,
						CONTENT_SCALE,
						CONTENT_FADE,
						props.class,
					),
					a.data("oh-dialog-content", true),
					a.attr_if(props.open, a.data("oh-dialog-initial-open", "true")),
					a.data("oh-dialog-show-modal", bool_attr(!props.disable_modal)),
				},
				attrs,
			),
		)
	}
	return props.hide_close_button
}

/* What goes out after the caller's children and before the dialog closes.
Separate from the close so a wrapper component can write the same trailing
markup and then close back to its own mark. */
content_trailing :: proc(hide_close_button: bool) {
	if hide_close_button {
		return
	}

	{h.button(
			a.class(
				CLOSE_BUTTON_POSITION,
				CLOSE_BUTTON_STYLE,
				CLOSE_BUTTON_HOVER,
				CLOSE_BUTTON_FOCUS,
				CLOSE_BUTTON_DISABLED,
				CLOSE_BUTTON_ICON,
			),
			a.data("oh-dialog-close", true),
			a.aria("label", "Close"),
			a.type("button"),
		)
		{ icon.icon(.X) }
		{ h.span(a.class("sr-only")); h.text("Close") }
	}
}

/* Returns hide_close_button for the deferred half -- see the comment on
popover.content for why the flag rides the return value. */
@(deferred_out = content_close)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) -> bool {
	{h.open_scope()
		return content_open(props, ..attrs)
	}
}

@(private)
content_close :: proc(hide_close_button: bool) {
	content_trailing(hide_close_button)
	h.close_all()
}

close_open :: proc(props := Close_Props{}, attrs: ..a.Attr) {
	{h.span_open(
			..a.join(
				[]a.Attr {
					a.attr_if(props.id != "", a.id(props.id)),
					a.data("oh-dialog-close", true),
					a.attr_if(props.for_ != "", a.data("oh-dialog-target", props.for_)),
					a.class(CLOSE_BASE, props.class),
				},
				attrs,
			),
		)
	}
}

@(deferred_none = h.close_all)
close :: proc(props := Close_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		close_open(props, ..attrs)
	}
}

header_open :: proc(props := Header_Props{}, attrs: ..a.Attr) {
	{h.div_open(
			..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(HEADER_BASE, props.class)}, attrs),
		)
	}
}

@(deferred_none = h.close_all)
header :: proc(props := Header_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		header_open(props, ..attrs)
	}
}

/* flex-col-reverse below the sm breakpoint, so a stacked footer puts the
confirming button on top -- where a thumb reaches it. */
footer_open :: proc(props := Footer_Props{}, attrs: ..a.Attr) {
	{h.div_open(
			..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(FOOTER_BASE, props.class)}, attrs),
		)
	}
}

@(deferred_none = h.close_all)
footer :: proc(props := Footer_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		footer_open(props, ..attrs)
	}
}

/* h2, as upstream has it, and not tied to the dialog by aria-labelledby --
which would need an id on both. A caller who wants that writes the ids and the
attribute. */
title_open :: proc(props := Title_Props{}, attrs: ..a.Attr) {
	{h.h2_open(..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(TITLE_BASE, props.class)}, attrs))
	}
}

@(deferred_none = h.close_all)
title :: proc(props := Title_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		title_open(props, ..attrs)
	}
}

description_open :: proc(props := Description_Props{}, attrs: ..a.Attr) {
	{h.p_open(
			..a.join(
				[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(DESCRIPTION_BASE, props.class)},
				attrs,
			),
		)
	}
}

@(deferred_none = h.close_all)
description :: proc(props := Description_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		description_open(props, ..attrs)
	}
}
