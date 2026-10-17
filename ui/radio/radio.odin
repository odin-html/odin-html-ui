/* Radio, ported from templui's components/radio/radio.templ.

One void input and nothing else -- no label, no wrapper, no children -- so this
is not an _open component and its braces are the void-element kind:

    {radio.radio({name = "size", value = "sm", checked = true})}

`name` is what makes a group: two radios sharing a name are alternatives, and
two that do not are two independent radios that both stay on. Nothing here can
check that for a caller, and it is the mistake worth knowing about.

The input is appearance-none, so everything on screen is drawn by the class
list: the ring is a border, and the dot is a ::before pseudo-element.

The dot is always there rather than appearing on check. It is drawn in the
background colour, so against an unchecked box -- which has no fill -- it is
invisible, and once `checked:bg-primary` fills the box it shows through as a
hole. Nothing has to toggle it, which is why `checked:before:visible` in the
list changes nothing: no rule ever hides it.

One class in the list is inert, and it is upstream's. Tailwind spells an
arbitrary content value `content-['']`; the list says `content['']` with no
hyphen, which is not a utility and emits no CSS -- the built stylesheet has no
rule for it. It costs nothing: Tailwind v4 emits `content: var(--tw-content)`
for every before: utility on its own, and declares that property with `""` as
its initial value, so the pseudo-element exists whether or not the content class
resolves. Kept verbatim rather than corrected, as badge's inert hover rules are;
here there is not even anything to fix. */
package radio

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

/* One constant per string literal in radio.templ rather than one blob, so a
diff against upstream still lines up. */
@(private)
BOX :: "relative h-4 w-4"
@(private)
DOT_ORIGIN :: "before:absolute before:left-1/2 before:top-1/2"
@(private)
DOT_SIZE :: "before:h-1.5 before:w-1.5 before:-translate-x-1/2 before:-translate-y-1/2"
@(private)
SHAPE :: "appearance-none rounded-full"
@(private)
BORDER :: "border-2 border-primary"
@(private)
DOT :: "before:content[''] before:rounded-full before:bg-background"
@(private)
CHECKED :: "checked:border-primary checked:bg-primary"
@(private)
CHECKED_DOT :: "checked:before:visible"
@(private)
FOCUS :: "focus-visible:outline-hidden focus-visible:ring-2 focus-visible:ring-ring"
@(private)
FOCUS_OFFSET :: "focus-visible:ring-offset-2 focus-visible:ring-offset-background"
@(private)
DISABLED :: "disabled:cursor-not-allowed"

/* checked and disabled are bare booleans: absent rather than checked="false",
which is what a.checked and a.disabled produce for false and is the only correct
rendering -- checked="false" checks the box.

`attrs` is spread last, so a caller can override anything set here, including
the type. */
radio :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.input(
			..a.join(
				[]a.Attr {
					a.type("radio"),
					a.attr_if(props.id != "", a.id(props.id)),
					a.attr_if(props.name != "", a.name(props.name)),
					a.attr_if(props.value != "", a.value(props.value)),
					a.attr_if(props.form != "", a.form(props.form)),
					a.checked(props.checked),
					a.disabled(props.disabled),
					a.class(
						BOX,
						DOT_ORIGIN,
						DOT_SIZE,
						SHAPE,
						BORDER,
						DOT,
						CHECKED,
						CHECKED_DOT,
						FOCUS,
						FOCUS_OFFSET,
						DISABLED,
						props.class,
					),
				},
				attrs,
			),
		)
	}
}
