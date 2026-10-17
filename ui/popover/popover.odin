/* Popover, ported from templui's components/popover/popover.templ -- and onto
the platform: the browser owns everything upstream's popover.js hand-rolled.

Three components -- a root, a trigger, and the floating content:

    {popover.root()
        {popover.trigger()
            {button.button(); h.text("Open")}
        }
        {popover.content({placement = .Bottom_Start, show_arrow = true})
            {h.p(); h.text("Anything at all.")}
        }
    }

All three take children and all three need braces at the call site -- see
odin-html-builder's html/h/component.odin.

This is the component the most others are built on: dropdown, tooltip,
hovercard, selectbox, tagsinput, timepicker and datepicker all render a
popover root/trigger/content underneath. So the wiring below is worth reading
once even if this component is never called directly.

## What the browser owns

The content is popover="auto": light dismiss, Escape, and top-layer stacking
are native, and none of them is scripted here or anywhere (the equivalence
was measured, per root). Two behaviours changed with that, both
the platform standard: Escape closes one level per press rather than every
open popover at once, and opening a popover closes an unrelated open one --
what data-tui-popover-exclusive used to opt into is simply how auto popovers
behave, so the option is gone. Nested popovers (content inside content) keep
their ancestors open, exactly as the old contains() skip did.

Positioning is CSS anchor positioning, with no ids and no script:

  - the root, <oh-popover>, scopes the anchor name to its own subtree
    (anchor-scope), so nested popovers cannot cross-wire;
  - the trigger is `contents` and has no box of its own to anchor to, so its
    *children* carry the anchor name -- the caller's button is the box the
    content attaches to;
  - the content is anchored (position-anchor) with a position-area utility
    computed from the placement at render time, and flip fallbacks for the
    viewport edge (position-try-fallbacks).

The three dashed-ident declarations (anchor-scope, anchor-name,
position-anchor) live in web/src/index.css as rules on this component's
element and roles -- Tailwind's arbitrary-property syntax cannot carry a bare
dashed ident as a value, and generates nothing for it. The rest are ordinary
utilities below.

The offset is the one dynamic value and is written as an inline margin on the
anchor-facing side: a Tailwind class cannot carry a runtime number, and the
flip tactics flip margins along with the area.

Enter and exit animation is @starting-style plus discrete transitions, keyed
on :popover-open. The old data-tui-popover-open attribute, the timer that held
the node open through its fade, and the fade classes that read the attribute
are all gone with it.

What is left for web/src/ui/popover.ts is the one thing the platform has no
declarative form for here: a click on the trigger toggles the content. (The
trigger wraps the caller's button, and popovertarget cannot be written onto an
element the component does not render.) See the class for the one subtlety --
native light dismiss races the very click that would toggle.

## Hover popovers

There is no hover trigger type any more. Tooltip, hovercard and dropdown's
submenus emit the standard interest-invoker vocabulary -- `interestfor` naming
the content's id, with the delays as interest-delay-start/-end inline style on
the invoker -- and web/src/ui/interestfor.ts emulates exactly that vocabulary
where the browser does not yet. The property names are stated once, in
interest_delays below and a.interestfor, so a spec rename is a one-line
change. Their triggers pass .Manual, which is true: this component's click
toggle must not fire on them.

## The manual holdout

tagsinput's suggestions root keeps popover="manual" ({kind = .Manual}): its
open/close is tagsinput behaviour (typing filters, focus leaves), scripted in
tagsinput.ts through the content's own showPopover()/hidePopover(). Manual
popovers get no light dismiss and no Escape, which is the point -- this root
is manual by design.

## offset

Zero means "unset" and becomes 8 with an arrow, 4 without -- the arrow needs
the extra space to sit in. Which does mean an offset of exactly 0 is not
expressible; upstream has the same hole, and asking for the popover to touch
its trigger is not a thing anything wants.

## The arrow

The placement is known when the markup renders, so the arrow's side is a
render-time class rather than the script decision it used to be. It is centred
on the content, not on the anchor -- the same point for the centred placements
tooltip uses, one square off for -start/-end placements -- and when a flip
fallback repositions the content at a viewport edge, the arrow keeps pointing
the declared way. Both are accepted trade-offs.

## The inner wrapper, and why it is written raw

The content is two elements: an overflow-hidden div holding the children, and
-- with show_arrow -- an arrow div after it, inside the outer content box but
outside the overflow. The arrow has to be outside it, or the very thing that
clips the content would clip the arrow.

That ordering cannot be written with the ordinary component pairing, which
closes every tag it opened at once and has nowhere to put a sibling in between.
So the outer div is a normal _open element and the inner wrapper is written as
two raw strings, closed by hand in content_close before the arrow goes out.
Both strings share CONTENT_INNER, so the class is still stated once.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package popover

import "core:fmt"

import "html:html/a"
import "html:html/h"

/* The placement names, kept from floating-ui days: they are this component's
vocabulary now, mapped to position-area utilities at render time. Bottom is
the zero value, which is also upstream's fallback for an empty Placement. */
Placement :: enum {
	Bottom,
	Bottom_Start,
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

/* Click is the zero value, matching upstream's fallback. Manual means the
click toggle in popover.ts must not fire: either a composing component's
element drives the content itself (tagsinput), or an interest invoker does
(tooltip, hovercard, dropdown submenus). The old Hover member is gone -- see
the file comment. */
Trigger_Type :: enum {
	Click,
	Manual,
}

/* The popover attribute's value. Auto is the default, and what every click-type
root uses. Hint is for hover content -- in browsers with it, a
hint does not dismiss an open auto popover (a tooltip over an open menu leaves
the menu alone); in browsers without it the value is invalid and falls back to
manual state, which the interestfor shim drives anyway. Manual is the
tagsinput holdout. */
Kind :: enum {
	Auto,
	Manual,
	Hint,
}

Root_Props :: struct {
	id:    string,
	class: string,
}

Trigger_Props :: struct {
	id:           string,
	class:        string,
	trigger_type: Trigger_Type,
}

Content_Props :: struct {
	id:         string,
	class:      string,
	placement:  Placement,

	// Distance from the trigger, in px. Zero means the default -- see the file
	// comment.
	offset:     int,
	show_arrow: bool,
	kind:       Kind,
}

/* What content() hands its deferred half: the arrow needs both whether to be
drawn and which side to sit on. Rides the call stack rather than a package
flag, so nested popovers cannot confuse each other -- which is what
@(deferred_out) is for. */
Content_State :: struct {
	show_arrow: bool,
	placement:  Placement,
}

/* `contents` on both the root and the trigger: no box, no layout of their own,
so wrapping a button in a trigger does not change how the button sits. The
anchor-name/-scope/position-anchor plumbing rides these same element and role
names from index.css -- see the file comment. */
@(private)
ROOT_BASE :: "contents"
@(private)
TRIGGER_BASE :: "contents"

/* One constant per idea, as the old constants were split. */
@(private)
CONTENT_LOOK :: "bg-popover rounded-lg border text-popover-foreground text-sm shadow-lg"

/* inset-auto and m-0 undo the UA popover rules (inset:0, margin:auto), which
would otherwise fight position-area. The offset margin is inline style and
wins over m-0 for its one side. */
@(private)
CONTENT_POSITION ::
	"pointer-events-auto fixed inset-auto m-0 " +
	"[position-try-fallbacks:flip-block,flip-inline]"
@(private)
CONTENT_SIZE :: "max-w-[min(24rem,calc(100vw-2rem))] overflow-visible outline-none"

/* The fade, on the platform's own state: @starting-style (the `starting:`
variant) animates the way in, and discrete transitions of display and overlay
hold the node visible through the way out -- which is what the old close timer
existed to fake. */
@(private)
CONTENT_FADE ::
	"opacity-0 [&:popover-open]:opacity-100 [&:popover-open]:starting:opacity-0 " +
	"transition-[opacity,display,overlay] transition-discrete duration-150 ease-out " +
	"motion-reduce:transition-none"

/* The wrapper the children go in. Written raw rather than as an element
because the arrow has to follow it as a sibling -- see the file comment. */
@(private)
CONTENT_INNER :: "w-full overflow-hidden"
@(private)
CONTENT_INNER_OPEN :: `<div class="` + CONTENT_INNER + `">`
@(private)
CONTENT_INNER_CLOSE :: "</div>"

@(private)
ARROW_BASE :: "absolute h-2.5 w-2.5 rotate-45 bg-popover border border-border"

// Defaults for a zero offset: room for the arrow, or just clear of the trigger.
@(private)
OFFSET_WITH_ARROW :: 8
@(private)
OFFSET_PLAIN :: 4

/* The placement, as a position-area utility. span-right keeps the area
flush with the anchor's start edge (the popover grows rightward), which is
what floating-ui's -start meant; span-left is -end. These are class literals
so Tailwind's scan of this file generates them. */
@(private)
placement_class :: proc(p: Placement) -> string {
	switch p {
	case .Bottom:
		return "[position-area:bottom]"
	case .Bottom_Start:
		return "[position-area:bottom_span-right]"
	case .Bottom_End:
		return "[position-area:bottom_span-left]"
	case .Top:
		return "[position-area:top]"
	case .Top_Start:
		return "[position-area:top_span-right]"
	case .Top_End:
		return "[position-area:top_span-left]"
	case .Right:
		return "[position-area:right]"
	case .Right_Start:
		return "[position-area:right_span-bottom]"
	case .Right_End:
		return "[position-area:right_span-top]"
	case .Left:
		return "[position-area:left]"
	case .Left_Start:
		return "[position-area:left_span-bottom]"
	case .Left_End:
		return "[position-area:left_span-top]"
	}
	return "[position-area:bottom]"
}

/* The offset, as an inline margin on the side facing the anchor. Inline
because the number is a runtime value no class can carry; a single side
because within a position-area the cross-axis margins would drag a -start/-end
popover off its alignment. The flip tactics flip margins with the area. Into
the temp allocator, which is the render arena. */
@(private)
offset_style :: proc(p: Placement, offset: int) -> string {
	side: string
	switch p {
	case .Bottom, .Bottom_Start, .Bottom_End:
		side = "margin-top"
	case .Top, .Top_Start, .Top_End:
		side = "margin-bottom"
	case .Right, .Right_Start, .Right_End:
		side = "margin-left"
	case .Left, .Left_Start, .Left_End:
		side = "margin-right"
	}
	return fmt.tprintf("%s:%dpx", side, offset)
}

/* The arrow's side is the opposite of the placement's, with the transparent
border pair that turns the rotated square into a triangle -- the same four
groups arrowClassForPlacement held in popover.js, now decided at render time.
Centred on the content; see the file comment. */
@(private)
arrow_class :: proc(p: Placement) -> string {
	switch p {
	case .Top, .Top_Start, .Top_End:
		return ARROW_BASE + " -bottom-[5px] left-1/2 -translate-x-1/2 border-t-transparent border-l-transparent"
	case .Right, .Right_Start, .Right_End:
		return ARROW_BASE + " -left-[5px] top-1/2 -translate-y-1/2 border-r-transparent border-t-transparent"
	case .Left, .Left_Start, .Left_End:
		return ARROW_BASE + " -right-[5px] top-1/2 -translate-y-1/2 border-l-transparent border-b-transparent"
	case .Bottom, .Bottom_Start, .Bottom_End:
		return ARROW_BASE + " -top-[5px] left-1/2 -translate-x-1/2 border-b-transparent border-r-transparent"
	}
	return ARROW_BASE + " -top-[5px] left-1/2 -translate-x-1/2 border-b-transparent border-r-transparent"
}

@(private)
trigger_type_attr :: proc(t: Trigger_Type) -> string {
	switch t {
	case .Click:
		return "click"
	case .Manual:
		return "manual"
	}
	return "click"
}

@(private)
kind_attr :: proc(k: Kind) -> string {
	switch k {
	case .Auto:
		return "auto"
	case .Manual:
		return "manual"
	case .Hint:
		return "hint"
	}
	return "auto"
}

@(private)
offset_or_default :: proc(offset: int, show_arrow: bool) -> int {
	if offset != 0 {
		return offset
	}
	return show_arrow ? OFFSET_WITH_ARROW : OFFSET_PLAIN
}

/* The interest-invoker delays, as the inline style an invoker carries beside
a.interestfor. Stated once, here: the property names are the still-new
standard's, and interestfor.ts parses this attribute text where the browser
does not know them yet -- an unknown property never reaches the CSSOM, but the
attribute string survives. Milliseconds in, seconds-free ms text out. */
interest_delays :: proc(delay_ms, end_delay_ms: int) -> string {
	return fmt.tprintf("interest-delay-start:%dms;interest-delay-end:%dms", delay_ms, end_delay_ms)
}

/* ---------------------------------------------------------------------------
The _open halves, for the components built on this one.

tooltip, hovercard and the rest are popovers with some of the props decided for
them. None of them can call root() or trigger() to get that: those defer their
close, and a close deferred inside a wrapper's body runs at the end of *that
body*, closing the element before the wrapper's caller has written anything
into it.

So the three below write the opening tag and nothing else, and a wrapper pairs
one with its own open_scope and its own deferred close -- the same split
elements.odin makes between div() and div_open(), one level up.

They are components' tools, not templates': each ends in an h.*_open, which
fails the render when there is no mark to record against. See
odin-html-builder's html/h/component.odin.
--------------------------------------------------------------------------- */

root_open :: proc(props := Root_Props{}, attrs: ..a.Attr) {
	{h.elem_open(
			"oh-popover",
			..a.join(
				[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(ROOT_BASE, props.class)},
				attrs,
			),
		)
	}
}

trigger_open :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	{h.span_open(
			..a.join(
				[]a.Attr {
					a.attr_if(props.id != "", a.id(props.id)),
					a.class(TRIGGER_BASE, props.class),
					a.data("oh-popover-trigger", true),
					a.data("oh-popover-type", trigger_type_attr(props.trigger_type)),
				},
				attrs,
			),
		)
	}
}

@(deferred_none = h.close_all)
root :: proc(props := Root_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		root_open(props, ..attrs)
	}
}

@(deferred_none = h.close_all)
trigger :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		trigger_open(props, ..attrs)
	}
}

/* Returns what the deferred half needs to draw the arrow. That half takes no
arguments of its own, and a package-level flag would be wrong the moment two
popovers nest -- the state rides the call stack instead, which is what
@(deferred_out) is for. */
content_open :: proc(props := Content_Props{}, attrs: ..a.Attr) -> Content_State {
	{h.div_open(
			..a.join(
				[]a.Attr {
					a.attr_if(props.id != "", a.id(props.id)),
					a.popover(kind_attr(props.kind)),
					a.data("oh-popover-content", true),
					a.style(offset_style(props.placement, offset_or_default(props.offset, props.show_arrow))),
					a.class(
						CONTENT_LOOK,
						CONTENT_POSITION,
						placement_class(props.placement),
						CONTENT_SIZE,
						CONTENT_FADE,
						props.class,
					),
				},
				attrs,
			),
		)
		h.raw(CONTENT_INNER_OPEN)
	}
	return {props.show_arrow, props.placement}
}

/* Everything that goes out after the caller's children and before the content
div closes: the inner wrapper's own closing tag, then the arrow if there is
one. Separate from the close so that a wrapper component can write the same
trailing markup and then close back to *its* own mark -- see the _open block
above.

Closing the wrapper by hand is what lets the arrow out of the overflow-hidden
box while staying inside the popover. */
content_trailing :: proc(state: Content_State) {
	h.raw(CONTENT_INNER_CLOSE)
	if state.show_arrow {
		{ h.div(a.data("oh-popover-arrow", true), a.class(arrow_class(state.placement))) }
	}
}

@(deferred_out = content_close)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) -> Content_State {
	{h.open_scope()
		return content_open(props, ..attrs)
	}
}

/* Runs at the end of the caller's block: children written, inner wrapper still
open, outer div still on the pending stack. close_all has to be last, and has
to happen -- an early return here would leave the popover open and fail the
render. */
@(private)
content_close :: proc(state: Content_State) {
	content_trailing(state)
	h.close_all()
}
