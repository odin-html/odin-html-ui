/* Accordion, ported from templui's components/accordion/accordion.templ.

Four components and no JavaScript. This is <details>/<summary>, so the open
state lives in the browser and nothing here has to track it -- which is why the
port is four wrappers and a chevron rather than a script:

    {accordion.accordion()
        {accordion.item()
            {accordion.trigger()
                h.text("Is it accessible?")
            }
            {accordion.content()
                h.text("Yes -- details and summary, no script.")
            }
        }
        {accordion.item()
            ...
        }
    }

All four take children, so all four are _open components and all four need
braces at the call site -- see odin-html-builder's html/h/component.odin.

One of them needs more than that. trigger() writes the chevron *after* whatever
the caller put in the summary, and a component cannot normally write anything
after its caller's block: the deferred half emits closing tags and nothing
else. The way out is for the component to own its deferred proc instead of
handing it straight to the close -- trigger_close below. That runs at the end of
the caller's block, with the children already written and nothing closed yet,
which is exactly the seam upstream writes into.

The two middle components are also coupled by CSS rather than by any Odin type:
item()'s class list reaches through summary into the svg that trigger() writes.
Neither can be trimmed alone. It is called out on the constant. */
package accordion

import "html:html/a"
import "html:html/h"

import "ui:ui/icon"

/* Four Props types with the same two fields, as upstream has them. Kept
separate rather than shared so that one component can gain a prop without the
other three growing it -- which is what already happened to Item below. */
Props :: struct {
	id:    string,
	class: string,
}

Item_Props :: struct {
	id:    string,
	class: string,

	/* Not upstream's, and the one deliberate deviation in this file.
	<details name=...> is what makes a group exclusive: opening one item closes
	its siblings. Upstream hardcodes "accordion", so every item on a page joins
	a single group and two separate accordions fight over it -- opening one
	silently collapses an item in the other. Left empty this behaves exactly as
	upstream does; setting it scopes a group to itself. */
	name:  string,
}

Trigger_Props :: struct {
	id:    string,
	class: string,
}

Content_Props :: struct {
	id:    string,
	class: string,
}

@(private)
GROUP_NAME :: "accordion"

@(private)
ITEM_BASE :: "group border-b last:border-b-0"

/* Reaches out of this component and into the icon trigger() writes. The two
are coupled by this selector and by nothing the compiler can see, so removing
it here does not break a build, it just stops the chevron turning. */
@(private)
ITEM_OPEN_ICON :: "[&[open]>summary>svg]:rotate-180"

/* One constant per string literal upstream, so a diff against it still lines
up. */
@(private)
TRIGGER_LAYOUT :: "flex flex-1 items-start justify-between gap-4 py-4"
@(private)
TRIGGER_TEXT :: "text-left text-sm font-medium"
@(private)
TRIGGER_MOTION :: "transition-all hover:underline cursor-pointer"
@(private)
TRIGGER_FOCUS :: "outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:border-ring rounded-md"
@(private)
TRIGGER_DISABLED :: "disabled:pointer-events-none disabled:opacity-50"

/* A summary renders a disclosure triangle by default, which would sit next to
the chevron. list-none removes it in every engine except WebKit, which needs
its pseudo-element hidden as well -- hence two rules for one marker. */
@(private)
TRIGGER_MARKER :: "list-none [&::-webkit-details-marker]:hidden"

@(private)
CONTENT_BASE :: "pt-0 pb-4 text-sm overflow-hidden"

@(private)
ICON_CLASS :: "size-4 shrink-0 translate-y-0.5 transition-transform duration-200 text-muted-foreground pointer-events-none"

/* The outer wrapper carries no classes of its own: upstream passes Class
through TwMerge alone, which means an accordion with no class still renders
class="" rather than no attribute. Kept, because a.class of an empty string
produces exactly that and the point is to match. */
@(deferred_none = h.close_all)
accordion :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(props.class)}, attrs))
		}
	}
}

@(deferred_none = h.close_all)
item :: proc(props := Item_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.details_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.name(props.name != "" ? props.name : GROUP_NAME),
						a.class(ITEM_BASE, ITEM_OPEN_ICON, props.class),
					},
					attrs,
				),
			)
		}
	}
}

/* The children land in the summary, then the chevron, then the close -- see
trigger_close, which is the whole reason this one does not use the ordinary
deferred half. */
@(deferred_none = trigger_close)
trigger :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.summary_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(
							TRIGGER_LAYOUT,
							TRIGGER_TEXT,
							TRIGGER_MOTION,
							TRIGGER_FOCUS,
							TRIGGER_DISABLED,
							TRIGGER_MARKER,
							props.class,
						),
					},
					attrs,
				),
			)
		}
	}
}

/* Runs at the end of the caller's block: the children are on the wire and the
summary is still open, so this is the only place a component gets to write
trailing content. Closing has to be the last thing it does, and it has to
happen -- an early return here would leave the summary open and fail the
render. */
@(private)
trigger_close :: proc() {
	chevron_down()
	h.close_all()
}

@(deferred_none = h.close_all)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(CONTENT_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}

/* aria-hidden is not upstream's. The chevron duplicates state the <details>
already exposes to assistive technology, so announcing it is noise -- and it is
cheap to add here because the icon package leaves its attributes open. */
@(private)
chevron_down :: proc() {
	{ icon.icon(.Chevron_Down, {class = ICON_CLASS}, a.aria("hidden", "true")) }
}
