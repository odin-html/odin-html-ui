/* Separator, ported from templui's components/separator/separator.templ.

A rule with an optional label sitting on it. Three elements deep either way: an
outer div carrying the role, an inner one that centres, a span drawing the line,
and a second span the caller's children land in.

    {separator.separator()}                          -- a plain rule
    {separator.separator(); h.text("or")}            -- a rule with a label

It takes children, so it is an _open component and the braces are not optional.
The two orientations open different elements in different scopes, which holds
together here for the same reason button's two tags do: _open records the tag
for the caller's close_all rather than deferring a close of its own.

Two things to know, both upstream's and both visible.

The label span is written whether or not there is a label, and it carries
horizontal padding and the page background. An empty separator therefore has a
gap in the middle of its line the width of that padding -- the line is drawn
behind the span and the span paints over it. It reads as a deliberate break at
small widths and as an obvious hole at large ones.

The colour it paints is bg-background, the page's, so a separator laid over a
card or anything else with its own surface paints the wrong colour into that
gap. Nothing in Props reaches that span -- class and attrs both land on the
outer div -- so there is no way to correct it from the call site. Keep
separators on the page background, or write the rule directly.

A vertical separator needs a height from somewhere -- h-full against a parent
that has one -- or it is a zero-tall element with a label floating in it.

No TwMerge, so a caller's class is appended rather than merged. Note the
decoration is applied to the line span rather than the outer div, and is not
reachable from Props.class for the same reason the background is not. */
package separator

import "html:html/a"
import "html:html/h"

Orientation :: enum {
	Horizontal,
	Vertical,
}

/* None is the zero value and upstream's default: its switch returns the empty
string for anything that is not dashed or dotted, which leaves the border solid.
*/
Decoration :: enum {
	None,
	Dashed,
	Dotted,
}

Props :: struct {
	id:          string,
	class:       string,
	orientation: Orientation,
	decoration:  Decoration,
}

/* One constant per string literal upstream, so a diff against it still lines
up. */
@(private)
H_OUTER :: "shrink-0 w-full"
@(private)
H_INNER :: "relative flex items-center w-full"
@(private)
H_LINE :: "absolute w-full border-t h-[1px]"
@(private)
H_LABEL :: "relative mx-auto bg-background px-2 text-xs text-muted-foreground"

@(private)
V_OUTER :: "shrink-0 h-full"
@(private)
V_INNER :: "relative flex flex-col items-center h-full"
@(private)
V_LINE :: "absolute h-full border-l w-[1px]"
@(private)
V_LABEL :: "relative my-auto bg-background py-2 text-xs text-muted-foreground"

@(private, rodata)
DECORATION_CLASSES := [Decoration]string {
	.None   = "",
	.Dashed = "border-dashed",
	.Dotted = "border-dotted",
}

/* aria-orientation is set on both branches and role="separator" on both, which
is what makes this a separator to assistive technology rather than three nested
divs. A labelled separator announces its label, which is usually what a caller
wanted the label for.

`attrs` is spread last, so a caller can override anything on the outer div --
including the role, for a separator that is decoration rather than structure. */
@(deferred_none = h.close_all)
separator :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		if props.orientation == .Horizontal {
			{h.div_open(
					..a.join(
						[]a.Attr {
							a.attr_if(props.id != "", a.id(props.id)),
							a.role("separator"),
							a.aria("orientation", "horizontal"),
							a.class(H_OUTER, props.class),
						},
						attrs,
					),
				)
				{h.div_open(a.class(H_INNER))
					{h.span(a.class(H_LINE, DECORATION_CLASSES[props.decoration]), a.aria("hidden", "true"))
					}
					{h.span_open(a.class(H_LABEL))
					}
				}
			}
		} else {
			{h.div_open(
					..a.join(
						[]a.Attr {
							a.attr_if(props.id != "", a.id(props.id)),
							a.role("separator"),
							a.aria("orientation", "vertical"),
							a.class(V_OUTER, props.class),
						},
						attrs,
					),
				)
				{h.div_open(a.class(V_INNER))
					{h.span(a.class(V_LINE, DECORATION_CLASSES[props.decoration]), a.aria("hidden", "true"))
					}
					{h.span_open(a.class(V_LABEL))
					}
				}
			}
		}
	}
}
