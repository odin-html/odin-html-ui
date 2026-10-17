/* Skeleton, ported from templui's components/skeleton/skeleton.templ.

The smallest component here: one div, no children, no variants. Upstream renders
it as `></div>` -- nothing goes inside -- so this is not an _open component and
its braces are the void-element kind, marking its extent and nothing more:

    {skeleton.skeleton({class = "h-4 w-32"})}

That class is not decoration. The div has no content and therefore no height, so
a skeleton with no size given is zero pixels tall and invisible. Every shape a
skeleton takes -- a line of text, an avatar, a card -- is the caller's classes;
the component contributes the colour and the pulse and nothing else. */
package skeleton

import "html:html/a"
import "html:html/h"

Props :: struct {
	id:    string,
	class: string,
}

@(private)
BASE :: "animate-pulse rounded bg-muted"

/* `attrs` is spread last, so a caller can override anything set here. That
includes class, which replaces BASE wholesale rather than adding to it -- use
Props.class to add, which is the additive way in and the one that keeps the
pulse. */
skeleton :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.div(..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(BASE, props.class)}, attrs))
	}
}
