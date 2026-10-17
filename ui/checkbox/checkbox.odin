/* Checkbox, ported from templui's components/checkbox/checkbox.templ -- and onto
the authoring model (the checklist in web/src/ui/README.md): the
markup is wrapped in <oh-checkbox class="contents">, whose behaviour is one custom
element in web/src/ui/checkbox.ts. What the element reads from this markup is
declared in web/src/ui/checkbox.contract.json and asserted against the rendered
output by checkbox_test.odin.

contents rather than block, like input and unlike progress: the div below is
already the component's single box -- and the box a caller's flex or grid item
lands on -- so a wrapper generating a second one would change the layout of every
checkbox that was laid out before the port. The utility is still explicit: an
unknown element is display:inline otherwise, and only in the pre-upgrade window.

    {checkbox.checkbox({name = "terms", checked = job.accepted})}

It takes no children -- a caption goes beside it, in a label -- so its braces
are the void-element kind.

Three elements inside the wrapper: the input, and two absolutely positioned
overlays holding the tick and the dash. The input is `appearance-none`, so the
box is the input's own border and background and the mark on top of it is one of
these overlays, shown by a peer-checked / peer-indeterminate rule. Nothing
scripts the ordinary case; both marks are in the markup from the start and CSS
picks. An ungrouped checkbox is therefore complete before upgrade, and the
element does nothing for it.

## Groups

group and group_parent are the parent/child checkbox pair -- one box that ticks
and unticks a set, and shows a dash when the set is partly ticked.
web/src/ui/checkbox.ts does the work, matching a parent to its children by the
string in data-oh-checkbox-group.

The element is one checkbox rather than one group, this component taking no
children and there being no group component to wrap the set: so the string is
still what pairs them, and checkbox.ts keeps a registry keyed by it, joined and
left as each box connects and disconnects.

The dash is the only part of this that a script has to reach: `indeterminate`
is a DOM property with no HTML attribute behind it, so it cannot be rendered at
all. A partly-ticked group is therefore correct only once the script has run.

The other thing checkbox.ts does is override the `checked` property setter on
child boxes so that setting it in code fires a change event. That is what lets a
parent update when something else ticks a child.

## icon

A proc rather than upstream's templ.Component, and called where the tick would
go. It replaces the tick only -- the dash on the indeterminate overlay stays
whatever it is, since that one means "partly", not "yes".

    {checkbox.checkbox({icon = proc() { icon.icon(.Heart, {class = "size-3.5"}) }})}

Sizing is the caller's: the default is size-3.5 to sit inside a size-4 box.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package checkbox

import "html:html/a"
import "html:html/h"

import "ui:ui/icon"

Props :: struct {
	id:           string,
	class:        string,
	name:         string,
	value:        string,
	disabled:     bool,
	checked:      bool,

	/* The name tying a parent box to its children. Any string; it is compared
	for equality by checkbox.ts and means nothing here. */
	group:        string,
	group_parent: bool,
	form:         string,

	/* Replaces the tick. Called with the render in progress, like any
	component, so it writes rather than returns. */
	icon:         proc(),
}

@(private)
WRAPPER :: "relative inline-flex items-center"

/* Grouped the way upstream's own comments group these, rather than one
constant per string literal. */
@(private)
BOX :: "peer size-4 shrink-0 rounded-[4px] border border-input shadow-xs"
@(private)
BOX_FOCUS :: "focus-visible:outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:border-ring"
@(private)
BOX_DISABLED :: "disabled:cursor-not-allowed disabled:opacity-50"
@(private)
BOX_CHECKED :: "checked:bg-primary checked:text-primary-foreground checked:border-primary"
@(private)
BOX_INDETERMINATE :: "indeterminate:bg-primary indeterminate:text-primary-foreground indeterminate:border-primary"

/* appearance-none is what makes the box drawable: without it the platform
control is painted over everything below. */
@(private)
BOX_APPEARANCE :: "appearance-none cursor-pointer transition-shadow"
@(private)
BOX_POSITION :: "relative"

/* The mark overlays. Both are always written and both start invisible; the
peer-* rule at the end of each is the whole of the switching. */
@(private)
MARK_BASE :: "absolute inset-0 pointer-events-none flex items-center justify-center text-primary-foreground opacity-0"
@(private)
MARK_CHECKED :: "peer-checked:opacity-100"
@(private)
MARK_INDETERMINATE :: "peer-indeterminate:opacity-100"

@(private)
ICON_CLASS :: "size-3.5"

checkbox :: proc(props := Props{}, attrs: ..a.Attr) {
	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged.
	{h.elem("oh-checkbox", a.class("contents"))
		{h.div(a.class(WRAPPER))
			{h.input(
					..a.join(
						[]a.Attr {
							a.checked(props.checked),
							a.disabled(props.disabled),
							a.attr_if(props.id != "", a.id(props.id)),
							a.attr_if(props.name != "", a.name(props.name)),
							a.value(props.value != "" ? props.value : "on"),
							a.attr_if(props.form != "", a.form(props.form)),
							a.attr_if(props.group != "", a.data("oh-checkbox-group", props.group)),
							a.attr_if(props.group_parent, a.data("oh-checkbox-parent", "true")),
							a.type("checkbox"),
							a.class(
								BOX,
								BOX_FOCUS,
								BOX_DISABLED,
								BOX_CHECKED,
								BOX_INDETERMINATE,
								BOX_APPEARANCE,
								BOX_POSITION,
								props.class,
							),
						},
						attrs,
					),
				)
			}

			{h.div(a.class(MARK_BASE, MARK_CHECKED))
				if props.icon != nil {
					props.icon()
				} else {
					{ icon.icon(.Check, {class = ICON_CLASS}) }
				}
			}

			// The dash, for a group that is partly ticked. Nothing renders it:
			// `indeterminate` is a property with no attribute, so this overlay is
			// dark until checkbox.ts sets one.
			{h.div(a.class(MARK_BASE, MARK_INDETERMINATE))
				{ icon.icon(.Minus, {class = ICON_CLASS}) }
			}
		}
	}
}
