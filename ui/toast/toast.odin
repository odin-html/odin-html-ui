/* Toast, ported from templui's components/toast/toast.templ -- and onto the
authoring model (the checklist in web/src/ui/README.md): the
markup is wrapped in <oh-toast class="contents">, whose behaviour is one custom
element in web/src/ui/toast.ts. What the element reads from this markup is
declared in web/src/ui/toast.contract.json and asserted against the rendered
output by toast_test.odin.

contents rather than block: the div below is already the component's own box,
and a `fixed` one pinned to a corner of the viewport -- a wrapper generating a
second box would put a stray inline box in the flow wherever the toast was
rendered.

A notification that places itself against a corner of the viewport and goes
away on its own:

    {toast.toast({
        title = "Saved",
        description = "Bearing 6203 updated.",
        variant = .Success,
        icon = true,
        dismissible = true,
        show_indicator = true,
    })}

It takes no children -- the title and description are props -- so its braces
are the void-element kind.

The whole of it is a prop rather than a slot because a toast is usually
rendered by a handler and swapped in, not written into a page by hand: the
server decides what it says, and htmx puts it on the page.

## Position, and why it is a data attribute

The corner is `data-position`, and every corner's rules are in the class list
at once, each behind a data-[position=...] selector. So changing the corner is
changing one attribute, which is what lets a swap move a toast without
rewriting its classes. The slide-in direction is picked the same way, with the
two data-[position*=top] / [*=bottom] partial matches.

## Duration and the progress bar

duration is milliseconds and defaults to 3000. toast.ts reads it from
data-oh-toast-duration, starts a timer, and animates the bar -- which is a plain
div here with no width or transform, so an unscripted page shows a full bar that
never moves and a toast that never leaves. A negative duration is the way to ask
for one that stays: nothing counts down, and only the close button removes it.

show_indicator only draws the bar when there is a duration to count down: a
toast that stays until dismissed has nothing to show.

## icon

A bool, not an icon: which glyph is drawn follows from the variant. The default
variant has none, so `icon = true` with no variant renders nothing there --
upstream's switch has no default branch, and that is the one combination that
looks like it should do something and does not.

Upstream generates a random id. This port writes one only when asked: <oh-toast>
is what marks a toast now, its parts carry roles (data-oh-toast="root", the bar's
"indicator", the close button's "dismiss"), and the countdown is state on the
element -- where toast.js kept it in a module Map keyed by the node.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package toast

import "html:html/a"
import "html:html/h"

import "ui:ui/button"
import "ui:ui/icon"

Variant :: enum {
	Default,
	Success,
	Error,
	Warning,
	Info,
}

Position :: enum {
	Bottom_Right,
	Bottom_Left,
	Bottom_Center,
	Top_Right,
	Top_Left,
	Top_Center,
}

Props :: struct {
	id:             string,
	class:          string,
	title:          string,
	description:    string,
	variant:        Variant,
	position:       Position,

	// Milliseconds. Zero means 3000 -- see the file comment.
	duration:       int,
	dismissible:    bool,
	show_indicator: bool,

	// Draws the variant's glyph. There is none for .Default.
	icon:           bool,
}

@(private)
DEFAULT_DURATION :: 3000

/* Grouped the way upstream's own comments group these. Every corner's rules
are present at once and selected by data-position, which is what makes the
corner one attribute rather than a class list. */
@(private)
ROOT_BASE :: "z-50 fixed pointer-events-auto p-4 w-full md:max-w-[420px]"
@(private)
ROOT_ANIMATION :: "animate-in fade-in slide-in-from-bottom-4 duration-300"
@(private)
ROOT_TOP_RIGHT :: "data-[position=top-right]:top-0 data-[position=top-right]:right-0"
@(private)
ROOT_TOP_LEFT :: "data-[position=top-left]:top-0 data-[position=top-left]:left-0"
@(private)
ROOT_TOP_CENTER ::
	"data-[position=top-center]:top-0 data-[position=top-center]:left-1/2 " +
	"data-[position=top-center]:-translate-x-1/2"
@(private)
ROOT_BOTTOM_RIGHT :: "data-[position=bottom-right]:bottom-0 data-[position=bottom-right]:right-0"
@(private)
ROOT_BOTTOM_LEFT :: "data-[position=bottom-left]:bottom-0 data-[position=bottom-left]:left-0"
@(private)
ROOT_BOTTOM_CENTER ::
	"data-[position=bottom-center]:bottom-0 data-[position=bottom-center]:left-1/2 " +
	"data-[position=bottom-center]:-translate-x-1/2"

// Partial matches, so both top corners slide down and both bottom ones up.
@(private)
ROOT_SLIDE_TOP :: "data-[position*=top]:slide-in-from-top-4"
@(private)
ROOT_SLIDE_BOTTOM :: "data-[position*=bottom]:slide-in-from-bottom-4"

@(private)
CARD ::
	"w-full bg-popover text-popover-foreground rounded-lg shadow-xs border pt-5 pb-4 px-4 " +
	"flex items-center justify-center relative overflow-hidden group"

@(private)
INDICATOR_TRACK :: "absolute top-0 left-0 right-0 h-1 overflow-hidden"

/* toast.js animated this by class name -- `toast-progress`, a hook with no
style behind it -- where toast.ts finds it by the role it carries, so the class
list is utilities again. `transition-transform` is upstream's and inert: the
element animates `width` with an inline transition that overrides it. */
@(private)
INDICATOR_BAR :: "h-full origin-left transition-transform ease-linear"
@(private)
INDICATOR_COLOURS ::
	"data-[variant=default]:bg-gray-500 " +
	"data-[variant=success]:bg-green-500 " +
	"data-[variant=error]:bg-red-500 " +
	"data-[variant=warning]:bg-yellow-500 " +
	"data-[variant=info]:bg-blue-500"

@(private)
CONTENT :: "flex-1 min-w-0"
@(private)
TITLE :: "text-sm font-semibold truncate"
@(private)
DESCRIPTION :: "text-sm opacity-90 mt-1"

/* One constant per string literal upstream: the four are written out in full
there rather than composed, and the colour sits in the middle of each. */
@(private)
ICON_SUCCESS :: "size-[22px] text-green-500 mr-3 flex-shrink-0"
@(private)
ICON_ERROR :: "size-[22px] text-red-500 mr-3 flex-shrink-0"
@(private)
ICON_WARNING :: "size-[22px] text-yellow-500 mr-3 flex-shrink-0"
@(private)
ICON_INFO :: "size-[22px] text-blue-500 mr-3 flex-shrink-0"

@(private)
DISMISS_ICON :: "size-[18px] opacity-75 hover:opacity-100"

@(private)
variant_attr :: proc(v: Variant) -> string {
	switch v {
	case .Default:
		return "default"
	case .Success:
		return "success"
	case .Error:
		return "error"
	case .Warning:
		return "warning"
	case .Info:
		return "info"
	}
	return "default"
}

@(private)
position_attr :: proc(p: Position) -> string {
	switch p {
	case .Bottom_Right:
		return "bottom-right"
	case .Bottom_Left:
		return "bottom-left"
	case .Bottom_Center:
		return "bottom-center"
	case .Top_Right:
		return "top-right"
	case .Top_Left:
		return "top-left"
	case .Top_Center:
		return "top-center"
	}
	return "bottom-right"
}

/* The glyph and its class follow the variant. .Default has neither, which is
upstream's switch with no default branch -- so `icon = true` on a default toast
draws nothing. */
@(private)
variant_icon :: proc(v: Variant) -> (icon.Name, string) {
	switch v {
	case .Success:
		return .Circle_Check, ICON_SUCCESS
	case .Error:
		return .Circle_X, ICON_ERROR
	case .Warning:
		return .Triangle_Alert, ICON_WARNING
	case .Info:
		return .Info, ICON_INFO
	case .Default:
		return .None, ""
	}
	return .None, ""
}

toast :: proc(props := Props{}, attrs: ..a.Attr) {
	duration := props.duration == 0 ? DEFAULT_DURATION : props.duration
	variant := variant_attr(props.variant)
	icon_name, icon_class := variant_icon(props.variant)

	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged.
	{h.elem("oh-toast", a.class("contents"))
		{h.div(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.data("oh-toast", "root"),
						a.data("oh-toast-duration", duration),
						a.data("position", position_attr(props.position)),
						a.data("variant", variant),
						a.class(
							ROOT_BASE,
							ROOT_ANIMATION,
							ROOT_TOP_RIGHT,
							ROOT_TOP_LEFT,
							ROOT_TOP_CENTER,
							ROOT_BOTTOM_RIGHT,
							ROOT_BOTTOM_LEFT,
							ROOT_BOTTOM_CENTER,
							ROOT_SLIDE_TOP,
							ROOT_SLIDE_BOTTOM,
							props.class,
						),
					},
					attrs,
				),
			)
			{h.div(a.class(CARD))
				// Only worth drawing when there is a countdown behind it.
				if props.show_indicator && duration > 0 {
					{h.div(a.class(INDICATOR_TRACK))
						{h.div(
								a.data("oh-toast", "indicator"),
								a.class(INDICATOR_BAR, INDICATOR_COLOURS),
								a.data("variant", variant),
								a.data("duration", duration),
							)
						}
					}
				}

				// The blank line above is load bearing: an element block
				// directly under the close of an if trips -strict-style, which
				// reads it as an else.
				if props.icon && icon_name != .None {
					{ icon.icon(icon_name, {class = icon_class}) }
				}

				{h.span(a.class(CONTENT))
					if props.title != "" {
						{ h.p(a.class(TITLE)); h.text(props.title) }
					}

					// Blank line, as above.
					if props.description != "" {
						{ h.p(a.class(DESCRIPTION)); h.text(props.description) }
					}
				}

				if props.dismissible {
					{button.button(
							{size = .Icon, variant = .Ghost, type = .Button},
							a.aria("label", "Close"),
							a.data("oh-toast", "dismiss"),
						)
						{ icon.icon(.X, {class = DISMISS_ICON}) }
					}
				}
			}
		}
	}
}
