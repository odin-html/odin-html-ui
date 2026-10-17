/* Switch, ported from templui's components/switch/switch.templ.

Named toggle here, package and proc both, because `switch` is an Odin keyword
and cannot be either. Upstream hit the same wall and called its Go package
switchcomp; this picks a word rather than a suffix. It is the only renamed
component in the collection, so it is worth saying plainly: if you are looking
for templui's switch, this is it.

    {toggle.toggle({name = "notify", checked = true})}

It takes no children -- upstream's label wraps the input and the track and
nothing else -- so this is not an _open component and its braces are the
void-element kind. A caption goes beside it, not inside.

Three elements: a label, a checkbox hidden inside it, and a div that is the
whole of what you see. The checkbox is `peer sr-only`, so every visible state --
the fill, the focus ring, the dimming, the thumb sliding across -- is a peer-*
rule on that div reading the input's state. Nothing scripts it, which is why
this component has no .js upstream while most inputs do.

Two consequences of that arrangement, both worth knowing at the call site:

Props.class lands on the track, not on the label, because the track is the part
worth restyling. And `attrs` is spread onto the input, not the label, so htmx
and the like reach the control that actually changes.

Upstream gives the label a `for` and invents a random ID when the caller gives
none, because a `for` needs something to point at. This port does not: the input
is nested inside the label, which associates the two on its own, so `for` is
written only when there is a caller's id to write. A rendered page therefore has
nothing random in it -- the same markup twice, which is what the golden tests
need and what makes the output diffable. */
package toggle

import "html:html/a"
import "html:html/h"

Props :: struct {
	id:       string,
	class:    string,
	name:     string,
	value:    string,
	form:     string,
	disabled: bool,
	checked:  bool,
}

@(private)
LABEL_BASE :: "inline-flex cursor-pointer items-center gap-2"

/* Upstream's utils.If on the label. The pointer over the label says the control
is unusable before the click that does nothing proves it. */
@(private)
LABEL_DISABLED :: "cursor-not-allowed"

/* sr-only rather than upstream's hidden, and the one deliberate deviation in
this file.

`hidden` is display:none, which takes the input out of the tab order entirely:
the switch cannot be reached by keyboard, cannot be toggled with space, and is a
mouse-only control. sr-only hides it just as completely while leaving it
focusable, which is the usual way to hide the input behind a drawn one.

Upstream's own class list is the argument that this is a defect rather than a
choice. It carries five peer-focus-visible rules to ring the track when the
input is focused, and display:none means none of them can ever fire. They fire
now. */
@(private)
INPUT_CLASS :: "peer sr-only"

/* Grouped the way upstream's own comments group these, rather than one constant
per string literal: the literals there are line continuations of one idea, and
splitting them further would name things upstream did not. */
@(private)
TRACK ::
	"relative inline-flex h-5 w-9 shrink-0 cursor-pointer items-center " +
	"rounded-full border-2 border-transparent " +
	"transition-colors"
@(private)
TRACK_COLORS :: "bg-input peer-checked:bg-primary"
@(private)
TRACK_FOCUS ::
	"peer-focus-visible:outline-none peer-focus-visible:ring-2 " +
	"peer-focus-visible:ring-ring peer-focus-visible:ring-offset-2 " +
	"peer-focus-visible:ring-offset-background"
@(private)
TRACK_DISABLED :: "peer-disabled:cursor-not-allowed peer-disabled:opacity-50"

/* The thumb is an ::after, and its content utility is spelled correctly here --
unlike radio's, which is worth knowing only because the two are otherwise
written the same way. */
@(private)
THUMB ::
	"after:pointer-events-none after:block " +
	"after:h-4 after:w-4 " +
	"after:rounded-full after:bg-background " +
	"after:shadow-lg after:ring-0 " +
	"after:transition-transform " +
	"after:content-['']"
@(private)
THUMB_CHECKED :: "peer-checked:after:translate-x-4"

/* checked and disabled are bare booleans: absent rather than checked="false",
which would check it.

value defaults to "on" as upstream writes it, which is also what a browser
submits for a checkbox with no value -- stated rather than left implicit, so the
markup says what will be posted. */
toggle :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.label(a.attr_if(props.id != "", a.for_(props.id)), a.class(LABEL_BASE, props.disabled ? LABEL_DISABLED : ""))
		{h.input(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.attr_if(props.name != "", a.name(props.name)),
						a.type("checkbox"),
						a.value(props.value != "" ? props.value : "on"),
						a.attr_if(props.form != "", a.form(props.form)),
						a.checked(props.checked),
						a.disabled(props.disabled),
						a.class(INPUT_CLASS),
						a.role("switch"),
					},
					attrs,
				),
			)
		}

		{h.div(
				a.class(TRACK, TRACK_COLORS, TRACK_FOCUS, TRACK_DISABLED, THUMB, THUMB_CHECKED, props.class),
				a.aria("hidden", "true"),
			)
		}
	}
}
