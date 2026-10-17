/* Dropdown, ported from templui's components/dropdown/dropdown.templ.

A menu on a popover, with eleven components:

    {dropdown.dropdown()
        {dropdown.trigger()
            {button.button({variant = .Outline}); h.text("Actions")}
        }
        {dropdown.content()
            {dropdown.group()
                {dropdown.label(); h.text("Bearing 6203")}
                {dropdown.item({href = "/b/1"}); h.text("Open")}
                {dropdown.item()
                    h.text("Copy id")
                    {dropdown.shortcut(); h.text("⌘C")}
                }
            }
            {dropdown.separator()}
            {dropdown.sub()
                {dropdown.sub_trigger({for_ = "move-menu"}); h.text("Move to")}
                {dropdown.sub_content({id = "move-menu"})
                    {dropdown.item(); h.text("Shelf A")}
                }
            }
        }
    }

All eleven take children except separator(), whose braces are the void-element
kind. Everything else needs braces at the call site.

The root, the trigger and both halves of a submenu are popover's elements --
see the _open block there for why a wrapper opens them rather than calling
popover's own components. The whole thing is wrapped in <oh-dropdown>, whose
element (web/src/ui/dropdown.ts) adds one thing on top: a click on an item
closes the popover around it, unless the item says otherwise. Everything else
-- open on click, light dismiss, Escape, one-menu-at-a-time -- is the
platform's, since popover moved onto popover="auto". The old `exclusive` flag
is gone with it: auto popovers are natively one-at-a-time.

## Items

An item with an href is an <a> and one without is a <button>, which is the
whole of the difference -- the classes differ only by `w-full`, which a button
needs and an anchor gets from being a flex child.

`disabled` on the anchor is classes only: there is no disabled attribute for a
link, so it is dimmed and pointer-events-none'd. The button gets the real
attribute as well. Neither is announced as disabled to assistive technology,
which is upstream's behaviour and worth knowing before using this for anything
that must be.

prevent_close is read by dropdown.ts and keeps the menu open on click -- for a
checkbox row, or anything that changes state without navigating.

Upstream gives every item a random id. Nothing reads it, so this port writes
one only when asked. See toggle's file comment for why.

## Submenus

A submenu opens on hover, and hover popovers are interest invokers now
(see "Popovers, and hover" in web/src/ui/README.md): the sub_trigger's button carries
interestfor naming the sub_content's id, with the enter/leave delays as
interest-delay inline style. Which is why the pair needs ids where nothing
else here does -- interestfor is an idref, and this collection does not invent
ids. The two are given by the caller and have to agree, the same deviation
dialog makes for `open`; either half missing renders an error span, loudly.
Chromium runs the attribute natively; web/src/ui/interestfor.ts emulates the
same vocabulary where the browser does not yet.

sub_trigger is the awkward one: it is popover's trigger wrapping a button whose
content is the caller's children in a span, followed by a chevron. Three
elements open, and the chevron has to land between the span's close and the
button's -- which the ordinary pairing cannot express, so the span is written
raw and closed by hand in sub_trigger_close, the same shape popover's own arrow
uses.

The chevron is upstream's own inline SVG rather than the icon package's
chevron-right: a different path, on a 16-unit viewBox. Kept, so the markup
matches.

Upstream also declares a PortalProps with no component using it. Not carried
across.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package dropdown

import "core:strings"

import "html:html/a"
import "html:html/h"

import "ui:ui/popover"

/* popover's twelve, re-declared rather than aliased, so that Bottom_Start is
the zero value.

Upstream aliases popover's type and defaults an empty Placement to
Bottom_Start. Go can do that because its zero value is the empty string, which
is not one of the twelve. Odin's zero value is a real member -- aliasing
popover's would make Bottom the default and leave no way to ask for
Bottom_Start's opposite, since "unset" and "Bottom" would be the same value.

So the enum is restated with the member a menu actually wants first, and
placement() maps it across. The cost is two lists to keep in step; the
alternative was one of the twelve being unreachable. */
Placement :: enum {
	Bottom_Start,
	Bottom,
	Bottom_End,
	Top,
	Top_Start,
	Top_End,
	Right,
	Right_Start,
	Right_End,
	Left,
	Left_Start,
	Left_End,
}

@(private)
placement :: proc(p: Placement) -> popover.Placement {
	switch p {
	case .Bottom_Start:
		return .Bottom_Start
	case .Bottom:
		return .Bottom
	case .Bottom_End:
		return .Bottom_End
	case .Top:
		return .Top
	case .Top_Start:
		return .Top_Start
	case .Top_End:
		return .Top_End
	case .Right:
		return .Right
	case .Right_Start:
		return .Right_Start
	case .Right_End:
		return .Right_End
	case .Left:
		return .Left
	case .Left_Start:
		return .Left_Start
	case .Left_End:
		return .Left_End
	}
	return .Bottom_Start
}

Props :: struct {
	id: string,
}

Trigger_Props :: struct {
	class: string,
}

Content_Props :: struct {
	class:     string,
	placement: Placement,
}

Group_Props :: struct {
	id:    string,
	class: string,
}

Label_Props :: struct {
	id:    string,
	class: string,
}

Item_Props :: struct {
	id:            string,
	class:         string,
	disabled:      bool,

	// With one, the item is an <a>; without, a <button>.
	href:          string,
	target:        string,

	// Keeps the menu open when this item is clicked. Read by dropdown.js.
	prevent_close: bool,
}

Separator_Props :: struct {
	id:    string,
	class: string,
}

Shortcut_Props :: struct {
	id:    string,
	class: string,
}

Sub_Props :: struct {
	id:    string,
	class: string,
}

Sub_Trigger_Props :: struct {
	class: string,

	// The sub_content's id -- required, and the two have to agree. See the
	// file comment.
	for_:  string,
}

Sub_Content_Props :: struct {
	// Required -- what the sub_trigger's interestfor names.
	id:    string,
	class: string,
}

/* One constant per string literal upstream, in upstream's order. */
@(private)
CONTENT_BASE :: "z-50 rounded-md bg-popover p-1 shadow-md focus:outline-none " + "overflow-y-auto overflow-x-hidden"
@(private)
CONTENT_BORDER :: "border border-border"
@(private)
CONTENT_SIZE :: "min-w-[8rem] max-h-[min(24rem,calc(100dvh_-_2rem))]"

@(private)
GROUP_BASE :: "py-1"
@(private)
LABEL_BASE :: "px-2 py-1.5 text-sm font-semibold"

/* The anchor and the button differ by w-full alone: a button does not fill its
parent on its own, an anchor laid out as a flex child does. */
@(private)
ITEM_LINK_BASE :: "flex text-left items-center justify-between px-2 py-1.5 text-sm rounded-sm"
@(private)
ITEM_BUTTON_BASE :: "w-full text-left flex items-center justify-between px-2 py-1.5 text-sm rounded-sm"
@(private)
ITEM_ENABLED ::
	"focus:bg-accent focus:text-accent-foreground hover:bg-accent " + "hover:text-accent-foreground cursor-default"

/* Classes only. There is no disabled attribute for an anchor, and a button
gets the real one as well as these. */
@(private)
ITEM_DISABLED :: "opacity-50 pointer-events-none"

/* -mx-1 pulls the rule out to the menu's edges, past the p-1 padding. */
@(private)
SEPARATOR_BASE :: "h-px my-1 -mx-1 bg-muted"

@(private)
SHORTCUT_BASE :: "ml-auto text-xs tracking-widest opacity-60"

@(private)
SUB_TRIGGER_BASE :: "w-full text-left flex items-center justify-between px-2 py-1.5 text-sm rounded-sm"
@(private)
SUB_TRIGGER_HOVER ::
	"focus:bg-accent focus:text-accent-foreground hover:bg-accent " + "hover:text-accent-foreground cursor-default"

@(private)
SUB_CONTENT_BASE :: "z-[9999] min-w-[8rem] rounded-md border bg-popover p-1 shadow-lg"

/* A submenu opens beside its trigger and slightly above it, quickly, and
lingers on the way out so the pointer can cross the gap. The delays ride the
trigger as interest-delay style now -- see the file comment. */
@(private)
SUB_OFFSET :: -4
@(private)
SUB_HOVER_DELAY :: 100
@(private)
SUB_HOVER_OUT_DELAY :: 200

@(private)
ERROR_CLASS :: "text-xs text-destructive"

@(private)
CHEVRON_CLASS :: "h-4 w-4 ml-auto"

/* The caller's children go in this, and the chevron after it -- see the file
comment for why it is raw. */
@(private)
SUB_TRIGGER_SPAN_OPEN :: "<span>"
@(private)
SUB_TRIGGER_SPAN_CLOSE :: "</span>"

/* popover's Props.class is a string rather than an attribute list, so a
component adding to it joins by hand -- the same helper pagination, copybutton
and tooltip have. Into the temp allocator, which is the render arena. */
@(private)
joined :: proc(base, extra: string) -> string {
	if extra == "" {
		return base
	}
	return strings.concatenate({base, " ", extra}, context.temp_allocator)
}

@(private)
CONTENT_CLASS :: CONTENT_BASE + " " + CONTENT_BORDER + " " + CONTENT_SIZE

/* Two elements: <oh-dropdown>, whose class closes the menu on item clicks, and
popover's root inside it. Both close at the end of the caller's block. */
@(deferred_none = h.close_all)
dropdown :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.elem_open("oh-dropdown", a.class("contents"))
			popover.root_open({id = props.id}, ..attrs)
		}
	}
}

@(deferred_none = h.close_all)
trigger :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		popover.trigger_open({class = props.class, trigger_type = .Click}, ..attrs)
	}
}

/* Bottom_Start by default rather than popover's Bottom: a menu lines its left
edge up with its trigger rather than centring on it. */
@(deferred_out = content_close)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) -> popover.Content_State {
	{h.open_scope()
		return popover.content_open(
			{class = joined(CONTENT_CLASS, props.class), placement = placement(props.placement)},
			..attrs,
		)
	}
}

@(private)
content_close :: proc(state: popover.Content_State) {
	popover.content_trailing(state)
	h.close_all()
}

@(deferred_none = h.close_all)
group :: proc(props := Group_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(GROUP_BASE, props.class),
						a.role("group"),
					},
					attrs,
				),
			)
		}
	}
}

/* A caption for a group, not a <label> -- it labels nothing focusable. */
@(deferred_none = h.close_all)
label :: proc(props := Label_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(LABEL_BASE, props.class)}, attrs),
			)
		}
	}
}

/* An anchor with an href, a button without. Both are role="menuitem" and both
carry data-oh-dropdown-item, which is what dropdown.ts closes the menu on. */
@(deferred_none = h.close_all)
item :: proc(props := Item_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		if props.href != "" {
			{h.a_open(
					..a.join(
						[]a.Attr {
							a.attr_if(props.id != "", a.id(props.id)),
							a.href(props.href),
							a.attr_if(props.target != "", a.target(props.target)),
							a.class(
								ITEM_LINK_BASE,
								props.disabled ? "" : ITEM_ENABLED,
								props.disabled ? ITEM_DISABLED : "",
								props.class,
							),
							a.role("menuitem"),
							a.data("oh-dropdown-item", true),
							a.attr_if(props.prevent_close, a.data("oh-dropdown-prevent-close", "true")),
						},
						attrs,
					),
				)
			}
		} else {
			{h.button_open(
					..a.join(
						[]a.Attr {
							a.attr_if(props.id != "", a.id(props.id)),
							a.class(
								ITEM_BUTTON_BASE,
								props.disabled ? "" : ITEM_ENABLED,
								props.disabled ? ITEM_DISABLED : "",
								props.class,
							),
							a.role("menuitem"),
							a.data("oh-dropdown-item", true),
							a.disabled(props.disabled),
							a.attr_if(props.prevent_close, a.data("oh-dropdown-prevent-close", "true")),
						},
						attrs,
					),
				)
			}
		}
	}
}

separator :: proc(props := Separator_Props{}, attrs: ..a.Attr) {
	{h.div(
			..a.join(
				[]a.Attr {
					a.attr_if(props.id != "", a.id(props.id)),
					a.class(SEPARATOR_BASE, props.class),
					a.role("separator"),
				},
				attrs,
			),
		)
	}
}

/* ml-auto, so it sits against the right edge of an item however long the
label beside it is. */
@(deferred_none = h.close_all)
shortcut :: proc(props := Shortcut_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.span_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(SHORTCUT_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}

/* A submenu is a whole popover of its own, nested inside the menu's content.
The native popover stack keeps them straight by containment, so nothing here
has to say which menu a submenu belongs to -- only the interestfor pair needs
naming, and that is the trigger's and content's ids agreeing. */
@(deferred_none = h.close_all)
sub :: proc(props := Sub_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		popover.root_open({id = props.id, class = props.class}, ..attrs)
	}
}

/* Three elements: popover's trigger, a button, and the span holding the
caller's children -- which is written raw so the chevron can land after it and
still be inside the button. See sub_trigger_close.

The button is the interest invoker: interestfor is valid on a button, so the
submenu is native where the browser has interest invokers, shimmed where it
does not. Manual as popover trigger type, because a click on it must not
toggle anything. */
@(deferred_none = sub_trigger_close)
sub_trigger :: proc(props := Sub_Trigger_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		popover.trigger_open({trigger_type = .Manual})
		if props.for_ == "" {
			{h.span(a.class(ERROR_CLASS))
				h.text("Error: Dropdown sub_trigger missing required 'for_' attribute.")
			}
		}

		// The blank line above is load bearing: an element block directly
		// under the close of an if trips -strict-style, which reads it as an
		// else.
		{h.button_open(
				..a.join(
					[]a.Attr {
						a.type("button"),
						a.data("oh-dropdown-submenu-trigger", true),
						a.attr_if(props.for_ != "", a.interestfor(props.for_)),
						a.attr_if(
							props.for_ != "",
							a.style(popover.interest_delays(SUB_HOVER_DELAY, SUB_HOVER_OUT_DELAY)),
						),
						a.class(SUB_TRIGGER_BASE, SUB_TRIGGER_HOVER, props.class),
					},
					attrs,
				),
			)
			h.raw(SUB_TRIGGER_SPAN_OPEN)
		}
	}
}

/* Runs at the end of the caller's block: children written, span still open,
button and popover trigger still on the pending stack. close_all has to be
last, and has to happen. */
@(private)
sub_trigger_close :: proc() {
	h.raw(SUB_TRIGGER_SPAN_CLOSE)
	chevron_right()
	h.close_all()
}

/* Upstream's own inline SVG, not the icon package's chevron-right: a different
path on a 16-unit viewBox. Kept so the markup matches. */
@(private)
chevron_right :: proc() {
	{h.svg(
			a.width("16"),
			a.height("16"),
			a.view_box("0 0 16 16"),
			a.fill("none"),
			a.xmlns("http://www.w3.org/2000/svg"),
			a.class(CHEVRON_CLASS),
		)
		{h.path(
				a.d("M6.5 3L11.5 8L6.5 13"),
				a.stroke("currentColor"),
				a.stroke_width("1.5"),
				a.stroke_linecap("round"),
				a.stroke_linejoin("round"),
			)
		}
	}
}

/* Right_Start and a negative offset, so a submenu overlaps its parent's edge
slightly rather than floating clear of it. The delays that let a pointer cross
the gap ride the sub_trigger, not this -- interest-delay is the invoker's
property. The id is what its interestfor names; missing, the error is loud. */
@(deferred_out = sub_content_close)
sub_content :: proc(props := Sub_Content_Props{}, attrs: ..a.Attr) -> popover.Content_State {
	state: popover.Content_State

	{h.open_scope()
		if props.id == "" {
			{h.span(a.class(ERROR_CLASS))
				h.text("Error: Dropdown sub_content missing required 'ID' attribute.")
			}
		}

		// The blank line above is load bearing: see sub_trigger.
		state = popover.content_open(
			{
				id = props.id,
				class = joined(SUB_CONTENT_BASE, props.class),
				placement = .Right_Start,
				offset = SUB_OFFSET,
			},
			..attrs,
		)
	}
	return state
}

@(private)
sub_content_close :: proc(state: popover.Content_State) {
	popover.content_trailing(state)
	h.close_all()
}
