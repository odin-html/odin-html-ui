/* Collapsible, ported from templui's components/collapsible/collapsible.templ
-- and onto the authoring model (the checklist in
web/src/ui/README.md): the markup is wrapped in <oh-collapsible class="contents">,
whose behaviour is one custom element in web/src/ui/collapsible.ts. What the
element reads from this markup is declared in
web/src/ui/collapsible.contract.json and asserted against the rendered output by
collapsible_test.odin.

contents rather than block, like avatar and unlike progress: the root below is
already the component's single box -- and the box a caller's class, flex item or
grid item lands on -- so a wrapper generating a second one would change the
layout of every collapsible that was laid out before the port. The utility is
still explicit: an unknown element is display:inline otherwise, and only in the
pre-upgrade window.

Three components -- a root, a trigger, and content that opens and closes:

    {collapsible.collapsible({open = true})
        {collapsible.trigger(); h.text("Details")}
        {collapsible.content()
            {h.p(); h.text("Hidden until asked for.")}
        }
    }

The wrapper goes on the root alone. trigger() and content() are the root's
children and are found by their data-oh-* roles from inside it, so neither
carries an element of its own.

Unlike accordion, which is <details>/<summary> and needs no script, this one is
scripted: web/src/ui/collapsible.ts toggles data-oh-collapsible-state on the root
and an `oh-collapsible-open` class on the content. Which is why the same shape
appears twice in the collection -- accordion is the version the browser animates
for you and cannot be nested inside a form control, this is the version that
goes anywhere and costs a script.

open is the initial state and nothing more, and the class that draws it is the
element's to write: before upgrade an open collapsible is drawn closed, the grid
row sitting at 0fr until collapsible.ts connects and catches it up. Upstream had
the same window; closing it would mean rendering the open class here, which is a
change to the component rather than to its script.

The open and closed heights are a grid trick rather than a height animation:
the content is a one-row grid at 0fr, the inner div is overflow-hidden, and
opening moves the row to 1fr. That transitions between "nothing" and "whatever
the content turns out to be" without anyone measuring it, which is the thing
CSS cannot do with height:auto.

So content() writes two elements, not one -- the grid and the overflow-hidden
inner div -- and the caller's children land inside both. Nothing at the call
site says so; it is why the close_all pairing exists.

The trigger is a div, as upstream has it, which means it is not a button: no
implicit role, and no keyboard behaviour except what collapsible.ts adds
(space and enter, matching a button) -- which a div reaches only once the caller
makes it focusable. A caller wanting the real thing puts a <button> inside the
trigger.

Upstream generates a random id for the root when the caller gives none. This
port writes one only when asked, because nothing needs it: the element works
entirely from data attributes and closest(), so the id was never load bearing.
The same choice as toggle -- see the file comment there for why a rendered page
having nothing random in it is worth keeping.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package collapsible

import "html:html/a"
import "html:html/h"

Props :: struct {
	id:    string,
	class: string,
	open:  bool,
}

Trigger_Props :: struct {
	id:    string,
	class: string,
}

Content_Props :: struct {
	id:    string,
	class: string,
}

/* The grid the animation runs on. `[&.oh-collapsible-open]` is the class
collapsible.ts toggles -- it reads the name from the contract manifest -- so this
selector and that element are one mechanism: renaming either alone leaves a
collapsible that never opens. */
@(private)
CONTENT_BASE ::
	"grid grid-rows-[0fr] transition-[grid-template-rows] duration-200 ease-out " +
	"[&.oh-collapsible-open]:grid-rows-[1fr]"

/* The inner element the grid row measures. Without overflow-hidden the content
is fully visible at 0fr and nothing appears to collapse. */
@(private)
CONTENT_INNER :: "overflow-hidden"

/* Like accordion's root, this carries no classes of its own: upstream passes
Class through TwMerge alone, so a collapsible with none still renders class=""
rather than no attribute. */
@(deferred_none = h.close_all)
collapsible :: proc(props := Props{}, attrs: ..a.Attr) {
	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged. It is
	// opened into the same scope as the root, so close_all writes both closing
	// tags at the end of the caller's block, innermost first.
	{h.open_scope()
		{h.elem_open("oh-collapsible", a.class("contents"))
			{h.div_open(
					..a.join(
						[]a.Attr {
							a.attr_if(props.id != "", a.id(props.id)),
							a.class(props.class),
							a.data("oh-collapsible", "root"),
							a.data("oh-collapsible-state", props.open ? "open" : "closed"),
						},
						attrs,
					),
				)
			}
		}
	}
}

@(deferred_none = h.close_all)
trigger :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(props.class),
						a.data("oh-collapsible", "trigger"),
					},
					attrs,
				),
			)
		}
	}
}

/* Two elements from one component. close_all closes both, innermost first, at
the end of the caller's block -- so the children sit inside the inner div and
the grid row has something to measure. */
@(deferred_none = h.close_all)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(CONTENT_BASE, props.class),
						a.data("oh-collapsible", "content"),
					},
					attrs,
				),
			)
			{h.div_open(a.class(CONTENT_INNER))
			}
		}
	}
}
