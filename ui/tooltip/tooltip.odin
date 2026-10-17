/* Tooltip, ported from templui's components/tooltip/tooltip.templ.

A popover with the decisions already made: it opens on hover, it is dark, and
it goes above the thing it describes unless told otherwise.

    {tooltip.tooltip()
        {tooltip.trigger({for_ = "runs-tip"})
            {button.button({variant = .Ghost}); h.text("?")}
        }
        {tooltip.content({id = "runs-tip", show_arrow = true}); h.text("Runs nightly at 02:00")}
    }

All three take children and all three need braces at the call site.

There is no markup of its own here. Each component opens the popover element
its name suggests and defers a close of its own -- calling popover.root()
directly would close it at the end of *this* body, before the caller has
written anything into it, which is what popover's _open half exists for.

## Hover is the standard's now

A tooltip is an interest invoker (see "Popovers, and hover" in
web/src/ui/README.md): the trigger carries interestfor naming the content's id, with
the delays as interest-delay inline style, and the content is popover="hint".
Which is why the pair needs ids -- interestfor is an idref, and this
collection does not invent ids. The caller gives trigger a for_ and content an
id, and the two have to agree, the same deviation dialog makes for `open`;
either half missing renders an error span, loudly.

One honest wrinkle: the attribute sits on
popover's trigger span, because the button underneath is the caller's and this
component cannot reach into it -- and native interest invokers are buttons and
links only. web/src/ui/interestfor.ts therefore drives spans everywhere and
self-retires only for the invokers browsers actually handle (dropdown's
submenu button today).

Two things it fixes rather than exposes: the trigger type is manual (a click
must not toggle a tooltip), and the content colours invert -- foreground on
background, with two `!` rules that reach into the arrow popover draws, since
an arrow keeping the popover's own background against an inverted body would
read as a seam.

Position is four-sided where popover has twelve placements: a tooltip is
centred on its trigger, and the -start/-end variants are not a thing anyone
asks a tooltip for. Top is the zero value, as upstream falls back to.

delay and end_delay are milliseconds on the trigger and default to 0, so a
tooltip appears the moment the pointer arrives. hovercard is the same
component with delays and a light body -- that is the whole difference between
them. */
package tooltip

import "core:strings"

import "html:html/a"
import "html:html/h"

import "ui:ui/popover"

Position :: enum {
	Top,
	Right,
	Bottom,
	Left,
}

Props :: struct {
	id:    string,
	class: string,
}

Trigger_Props :: struct {
	id:        string,
	class:     string,

	// The content's id -- required, and the two have to agree. See the file
	// comment.
	for_:      string,

	// Milliseconds before the tooltip opens, and before it closes again.
	delay:     int,
	end_delay: int,
}

Content_Props :: struct {
	// Required -- what the trigger's interestfor names.
	id:         string,
	class:      string,
	show_arrow: bool,
	position:   Position,
}

/* Inverted against the page, and the two `!` rules drag popover's arrow along
with it -- the arrow is popover's element, drawn with popover's background, so
without these a dark tooltip would have a light triangle stuck to it. */
@(private)
CONTENT_BASE ::
	"px-4 py-1 bg-foreground text-background " +
	"[&_[data-oh-popover-arrow]]:!bg-foreground [&_[data-oh-popover-arrow]]:!border-0"

@(private)
ERROR_CLASS :: "text-xs text-destructive"

@(private)
placement :: proc(p: Position) -> popover.Placement {
	switch p {
	case .Top:
		return .Top
	case .Right:
		return .Right
	case .Bottom:
		return .Bottom
	case .Left:
		return .Left
	}
	return .Top
}

@(deferred_none = h.close_all)
tooltip :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		popover.root_open({id = props.id, class = props.class}, ..attrs)
	}
}

@(deferred_none = h.close_all)
trigger :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		if props.for_ == "" {
			{h.span(a.class(ERROR_CLASS))
				h.text("Error: Tooltip trigger missing required 'for_' attribute.")
			}
		}

		// The blank line above is load bearing: an element block directly
		// under the close of an if trips -strict-style, which reads it as an
		// else.
		popover.trigger_open(
			{id = props.id, class = props.class, trigger_type = .Manual},
			..a.join(
				[]a.Attr {
					a.attr_if(props.for_ != "", a.interestfor(props.for_)),
					a.attr_if(props.for_ != "", a.style(popover.interest_delays(props.delay, props.end_delay))),
				},
				attrs,
			),
		)
	}
}

/* Returns the arrow state for the deferred half, exactly as popover.content
does -- see the comment there for why it rides the return value. */
@(deferred_out = content_close)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) -> popover.Content_State {
	state: popover.Content_State

	{h.open_scope()
		if props.id == "" {
			{h.span(a.class(ERROR_CLASS))
				h.text("Error: Tooltip content missing required 'ID' attribute.")
			}
		}

		// The blank line above is load bearing: see trigger.
		state = popover.content_open(
			{
				id = props.id,
				class = joined(CONTENT_BASE, props.class),
				placement = placement(props.position),
				show_arrow = props.show_arrow,
				kind = .Hint,
			},
			..attrs,
		)
	}
	return state
}

/* popover writes the trailing markup, this closes back to its own mark. Both
halves are needed: the trailing part is popover's business and the close is
this component's. */
@(private)
content_close :: proc(state: popover.Content_State) {
	popover.content_trailing(state)
	h.close_all()
}

/* popover's Props.class is a string rather than an attribute list, so a
component adding to it joins by hand -- the same helper pagination and
copybutton have. Into the temp allocator, which is the render arena. */
@(private)
joined :: proc(base, extra: string) -> string {
	if extra == "" {
		return base
	}
	return strings.concatenate({base, " ", extra}, context.temp_allocator)
}
