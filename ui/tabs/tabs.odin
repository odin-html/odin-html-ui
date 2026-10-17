/* Tabs, ported from templui's components/tabs/tabs.templ -- and onto the
authoring model (the checklist in web/src/ui/README.md): the
markup is wrapped in <oh-tabs class="contents">, whose behaviour is one custom
element in web/src/ui/tabs.ts. What the element reads from this markup is
declared in web/src/ui/tabs.contract.json and asserted against the rendered
output by tabs_test.odin.

contents rather than block, like collapsible and unlike progress: the root below
is already the component's single box -- `flex flex-col gap-2`, and the box a
caller's class, flex item or grid item lands on -- so a wrapper generating a
second one would change the layout of every tabs group that was laid out before
the port. The utility is still explicit: an unknown element is display:inline
otherwise, and only in the pre-upgrade window.

Four components: the group, the row of buttons, a button, and a panel.

    {tabs.tabs({id = "settings"})
        {tabs.list({tabs_id = "settings"})
            {tabs.trigger({tabs_id = "settings", value = "general", is_active = true})
                h.text("General")
            }
            {tabs.trigger({tabs_id = "settings", value = "keys"})
                h.text("API keys")
            }
        }
        {tabs.content({tabs_id = "settings", value = "general", is_active = true})
            h.text("...")
        }
        {tabs.content({tabs_id = "settings", value = "keys"})
            h.text("...")
        }
    }

All four take children and all four need braces at the call site. The wrapper
goes on the group alone -- list(), trigger() and content() are found by their
data-oh-* roles from inside it, so none of them carries an element of its own.

## tabs_id, and what the wrapper did to it

Nothing here is nested in the DOM sense: a trigger and the panel it opens are
siblings under the group, not parent and child. The document-delegating
tabs.js paired them by a shared string -- data-tui-tabs-id -- and scanned the
whole document for it, because it had no other way to know which panels a
trigger owned.

Upstream fills that string in for you. It generates a random id in Tabs, puts
it in the Go context, and List, Trigger and Content read it back out. templ has
a context on every component for exactly this. This port has neither the
context nor the random id, so the string is a prop and every part of the group
carries it.

<oh-tabs> is the grouping now: web/src/ui/tabs.ts switches the triggers and
panels inside the nearest element above the clicked trigger, and never reads
the id. So the trap this section used to warn about is gone -- a trigger whose
tabs_id does not match its group still works, and a group with no id at all
works, where tabs.js skipped it and nothing switched. The attribute is kept and
still rendered on all four parts as the group's name for callers to hook onto;
nothing in the port depends on it, which is why it is not in the contract
manifest.

## is_active

The initial state, and the only state the server decides. tabs.ts takes over
from there -- and it also runs a pass on connect that makes the first trigger
active if none is, so a group with no is_active anywhere still works once the
element has upgraded. Until it does, that group shows no panel at all rather
than the first one: a panel is hidden by a class rather than by an attribute the
browser understands, and with the stylesheet in and the element not yet, every
panel carries it. Mark one active and the page is right before any script runs,
which is the reason to.

A value is required, on both a trigger and a panel: it is what the two are
matched by. Missing one renders an error span, as upstream does -- but unlike
upstream, a panel missing its value still renders its wrapper, so the caller's
children stay inside it rather than escaping into the group.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package tabs

import "html:html/a"
import "html:html/h"

Props :: struct {
	// Doubles as the group's name -- see the file comment.
	id:    string,
	class: string,
}

List_Props :: struct {
	id:      string,
	class:   string,
	tabs_id: string,
}

Trigger_Props :: struct {
	id:        string,
	class:     string,

	// What this trigger opens. Matched against a panel's value.
	value:     string,
	is_active: bool,
	tabs_id:   string,
}

Content_Props :: struct {
	id:        string,
	class:     string,
	value:     string,
	is_active: bool,
	tabs_id:   string,
}

@(private)
ROOT_BASE :: "flex flex-col gap-2"

@(private)
LIST_BASE :: "bg-muted text-muted-foreground inline-flex h-9 w-fit items-center justify-center " + "rounded-lg p-[3px]"

/* One string literal upstream, and kept as one here.

Its groups are interleaved -- active, focus, active again, layout, focus again,
disabled, active a third time, icons -- which is upstream's own disorder rather
than anything meaningful. Splitting it into named constants would read better
and would silently reorder the attribute, so it stays in sequence and the line
breaks fall where the groups change.

The active look is a data-[oh-tabs-state=active] rule rather than a class the
script swaps, so the only thing tabs.ts writes on a trigger is the attribute --
and this table and that element are one mechanism: the attribute's name and the
"active" value both come from the contract manifest, and renaming either alone
leaves a tab that never lights up. */
@(private)
TRIGGER_BASE ::
	"data-[oh-tabs-state=active]:bg-background " +
	"dark:data-[oh-tabs-state=active]:text-foreground " +
	"focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:outline-ring " +
	"dark:data-[oh-tabs-state=active]:border-input " +
	"dark:data-[oh-tabs-state=active]:bg-input/30 " +
	"text-foreground dark:text-muted-foreground inline-flex h-[calc(100%-1px)] flex-1 " +
	"items-center justify-center gap-1.5 rounded-md border border-transparent px-2 py-1 " +
	"text-sm font-medium whitespace-nowrap transition-[color,box-shadow] " +
	"focus-visible:ring-[3px] focus-visible:outline-1 " +
	"disabled:pointer-events-none disabled:opacity-50 " +
	"data-[oh-tabs-state=active]:shadow-sm " +
	"[&_svg]:pointer-events-none [&_svg]:shrink-0 " +
	"[&_svg:not([class*='size-'])]:size-4"

@(private)
CONTENT_BASE :: "flex-1 outline-none"

/* A panel is hidden by a class, so every panel is visible until the stylesheet
and the element have both arrived. The name is the other half of the contract
manifest's `classes.hidden`: tabs.ts toggles this exact class per switch. */
@(private)
CONTENT_HIDDEN :: "hidden"

@(private)
ERROR_CLASS :: "text-xs text-destructive"

@(private)
state_attr :: proc(is_active: bool) -> string {
	return is_active ? "active" : "inactive"
}

@(deferred_none = h.close_all)
tabs :: proc(props := Props{}, attrs: ..a.Attr) {
	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged. It is
	// opened into the same scope as the root, so close_all writes both closing
	// tags at the end of the caller's block, innermost first.
	{h.open_scope()
		{h.elem_open("oh-tabs", a.class("contents"))
			{h.div_open(
					..a.join(
						[]a.Attr {
							a.attr_if(props.id != "", a.id(props.id)),
							a.class(ROOT_BASE, props.class),
							a.data("oh-tabs", "root"),
							a.data("oh-tabs-id", props.id),
						},
						attrs,
					),
				)
			}
		}
	}
}

@(deferred_none = h.close_all)
list :: proc(props := List_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(LIST_BASE, props.class),
						a.data("oh-tabs", "list"),
						a.data("oh-tabs-id", props.tabs_id),
					},
					attrs,
				),
			)
		}
	}
}

/* The error span goes before the button, as upstream writes it, and the button
is still rendered -- a trigger with no value is inert rather than absent, which
is easier to find in a page than a missing tab. */
@(deferred_none = h.close_all)
trigger :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	if props.value == "" {
		{h.span(a.class(ERROR_CLASS))
			h.text("Error: Tab Trigger missing required 'Value' attribute.")
		}
	}

	// The blank line above is load bearing: an element block directly under
	// the close of an if trips -strict-style, which reads it as an else.
	{h.open_scope()
		{h.button_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.type("button"),
						a.class(TRIGGER_BASE, props.class),
						a.data("oh-tabs", "trigger"),
						a.data("oh-tabs-id", props.tabs_id),
						a.data("oh-tabs-value", props.value),
						a.data("oh-tabs-state", state_attr(props.is_active)),
					},
					attrs,
				),
			)
		}
	}
}

/* Upstream stops here when the value is missing, dropping the panel and its
children both. This still opens the wrapper: a component cannot decline its
caller's children, and leaving them to land in the group would put a panel's
contents on the page unwrapped and always visible. */
@(deferred_none = h.close_all)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) {
	if props.value == "" {
		{h.span(a.class(ERROR_CLASS))
			h.text("Error: Tab Content missing required 'Value' attribute.")
		}
	}

	// The blank line above is load bearing -- see trigger().
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(CONTENT_BASE, props.is_active ? "" : CONTENT_HIDDEN, props.class),
						a.data("oh-tabs", "content"),
						a.data("oh-tabs-id", props.tabs_id),
						a.data("oh-tabs-value", props.value),
						a.data("oh-tabs-state", state_attr(props.is_active)),
					},
					attrs,
				),
			)
		}
	}
}
