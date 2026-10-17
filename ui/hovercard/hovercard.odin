/* Hover card, ported from templui's components/hovercard/hovercard.templ.

The other popover-with-decisions-made, beside tooltip: it opens on hover like a
tooltip, but it is a card -- the page's own colours, room for real content, and
delays long enough that brushing past does not open it.

    {hovercard.root()
        {hovercard.trigger({for_ = "ada-card"})
            {h.a(a.href("/u/ada")); h.text("@ada")}
        }
        {hovercard.content({id = "ada-card"})
            {avatar.avatar()
                {avatar.fallback(); h.text("AL")}
            }
            {h.p(); h.text("Joined March 2024")}
        }
    }

All three take children and all three need braces at the call site.

Like tooltip, it has no markup of its own: each component opens the popover
element its name suggests and defers its own close. See the _open block in
popover for why it cannot simply call popover.root().

Hover is an interest invoker -- interestfor on the
trigger naming the content's id, delays as interest-delay inline style,
popover="hint" on the content. The two ids have to agree and either half
missing renders an error span; tooltip's file comment carries the full story,
including why the invoker is the trigger span and what that means for the
shim.

Placement is popover's, aliased rather than re-declared -- a hover card is
large enough that the -start and -end variants matter, unlike a tooltip's.

The three defaults are the component: 150ms before it opens, 300ms before it
closes, and w-64 p-4 so there is somewhere to put a face and two lines. Zero
means unset for both delays, so a hover card that opens instantly is not
expressible -- upstream has the same hole, and a card that appears the moment
the pointer crosses it is the behaviour the delays exist to prevent. */
package hovercard

import "core:strings"

import "html:html/a"
import "html:html/h"

import "ui:ui/popover"

/* popover's, aliased rather than restated: a hover card is placed the same
twelve ways, and a second enum would only be something to keep in step. */
Placement :: popover.Placement

Props :: struct {
	id:    string,
	class: string,
}

Trigger_Props :: struct {
	id:          string,
	class:       string,

	// The content's id -- required, and the two have to agree. See the file
	// comment.
	for_:        string,

	// Milliseconds. Zero means the defaults below.
	open_delay:  int,
	close_delay: int,
}

Content_Props :: struct {
	// Required -- what the trigger's interestfor names.
	id:         string,
	class:      string,
	placement:  Placement,
	offset:     int,
	show_arrow: bool,
}

@(private)
CONTENT_BASE :: "w-64 p-4"

@(private)
ERROR_CLASS :: "text-xs text-destructive"

/* Long enough that a pointer crossing the trigger on its way somewhere else
does not open the card, and that moving from the trigger onto the card itself
does not close it in the gap between them. */
@(private)
DEFAULT_OPEN_DELAY :: 150
@(private)
DEFAULT_CLOSE_DELAY :: 300

@(deferred_none = h.close_all)
root :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		popover.root_open({id = props.id, class = props.class}, ..attrs)
	}
}

@(deferred_none = h.close_all)
trigger :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	open_delay := props.open_delay != 0 ? props.open_delay : DEFAULT_OPEN_DELAY
	close_delay := props.close_delay != 0 ? props.close_delay : DEFAULT_CLOSE_DELAY

	{h.open_scope()
		if props.for_ == "" {
			{h.span(a.class(ERROR_CLASS))
				h.text("Error: HoverCard trigger missing required 'for_' attribute.")
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
					a.attr_if(props.for_ != "", a.style(popover.interest_delays(open_delay, close_delay))),
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
				h.text("Error: HoverCard content missing required 'ID' attribute.")
			}
		}

		// The blank line above is load bearing: see trigger.
		state = popover.content_open(
			{
				id = props.id,
				class = joined(CONTENT_BASE, props.class),
				placement = props.placement,
				offset = props.offset,
				show_arrow = props.show_arrow,
				kind = .Hint,
			},
			..attrs,
		)
	}
	return state
}

/* popover writes the trailing markup, this closes back to its own mark. */
@(private)
content_close :: proc(state: popover.Content_State) {
	popover.content_trailing(state)
	h.close_all()
}

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
