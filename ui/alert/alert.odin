/* Alert, ported from templui's components/alert/alert.templ.

Three components, all of which take children, so all three are _open components
and all three need braces at the call site -- see odin-html-builder's html/h/component.odin:

    {alert.alert({variant = .Destructive})
        {icon.icon(.Triangle_Alert)}
        {alert.title()
            h.text("Payment failed")
        }
        {alert.description()
            {h.p(); h.text("Your card was declined.")}
        }
    }

The icon is a child rather than a prop, and that is what the outer class list
is built around. An alert is a two-column grid: column one holds the icon,
column two everything else, which is why title and description both pin
themselves to the second column instead of flowing. The `has-[>svg]` pair sizes
column one from whether a direct-child svg exists at all, so an alert without
one collapses it to zero width and no caller has to say which shape it wanted.
The consequence is that the icon has to be a *direct* child of alert(), not
wrapped in anything, or both the column and the sizing rules stop matching.

data-slot is upstream's, kept, and on description it is load bearing: the
destructive variant reaches through it to recolour the description, so removing
the attribute silently changes what that variant renders. On the other two it
is a hook for callers and nothing here reads it.

As in button, there is no TwMerge: the parts are concatenated in order and a
caller's class is appended rather than merged, so two conflicting utilities both
land on the element and the stylesheet's source order decides. See the file
comment in button/button.odin, including why that example is described rather
than spelled. */
package alert

import "html:html/a"
import "html:html/h"

/* The zero value is upstream's "default", so Props{} needs no normalizing. */
Variant :: enum {
	Default,
	Destructive,
}

Props :: struct {
	id:      string,
	class:   string,
	variant: Variant,
}

/* Two Props types with the same two fields, as upstream has them, and kept
separate for the same reason accordion's four are: one can gain a prop without
the other growing it. */
Title_Props :: struct {
	id:    string,
	class: string,
}

Description_Props :: struct {
	id:    string,
	class: string,
}

/* One constant per string literal in alert.templ rather than one blob, so a
diff against upstream still lines up. */
@(private)
BASE_BOX :: "relative w-full rounded-lg border px-4 py-3 text-sm"
@(private)
BASE_GRID :: "grid has-[>svg]:grid-cols-[1rem_1fr] grid-cols-[0_1fr] has-[>svg]:gap-x-3 gap-y-0.5 items-start"
@(private)
BASE_ICON :: "[&>svg]:size-4 [&>svg]:translate-y-0.5 [&>svg]:text-current"

/* An enumerated array rather than the switch upstream uses: the mapping is
total either way, but this one the compiler checks for completeness. rodata
rather than a constant because the index is a runtime value. */
@(private, rodata)
VARIANT_CLASSES := [Variant]string {
	.Default     = "bg-card text-card-foreground",
	.Destructive = "text-destructive bg-card [&>svg]:text-current *:data-[slot=alert-description]:text-destructive/90",
}

@(private)
TITLE_BASE :: "col-start-2 line-clamp-1 min-h-4 font-medium tracking-tight"

@(private)
DESCRIPTION_BASE :: "text-muted-foreground col-start-2 grid justify-items-start gap-1 text-sm [&_p]:leading-relaxed"

/* role="alert" is an assertive live region: rendered into a page that is
already up, it interrupts whatever a screen reader was saying. That is right
for the failure this component is usually reporting and wrong for an alert
present at page load, which announces itself for no reason. Upstream stamps it
unconditionally and so does this; `attrs` is spread last, so a caller wanting
the quieter form passes a.role("status") and wins.

Same for everything else set here, class included -- but a.class from a caller
replaces this list wholesale rather than adding to it, so use Props.class to
add. */
@(deferred_none = h.close_all)
alert :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.data("slot", "alert"),
						a.class(BASE_BOX, BASE_GRID, BASE_ICON, VARIANT_CLASSES[props.variant], props.class),
						a.role("alert"),
					},
					attrs,
				),
			)
		}
	}
}

/* h5 rather than a heading chosen from context, as upstream has it. The level
is wrong for most documents an alert lands in; it carries no landmark role and
nothing here depends on the tag, so a caller who cares reads this and writes the
heading itself. */
@(deferred_none = h.close_all)
title :: proc(props := Title_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.h5_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.data("slot", "alert-title"),
						a.class(TITLE_BASE, props.class),
					},
					attrs,
				),
			)
		}
	}
}

/* A grid of its own, so paragraphs stack rather than run together -- which is
why the body of an alert is written as elements and not as bare text. */
@(deferred_none = h.close_all)
description :: proc(props := Description_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.data("slot", "alert-description"),
						a.class(DESCRIPTION_BASE, props.class),
					},
					attrs,
				),
			)
		}
	}
}
