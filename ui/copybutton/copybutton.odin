/* Copy button, ported from templui's components/copybutton/copybutton.templ --
and onto the authoring model (the checklist in
web/src/ui/README.md): the markup is wrapped in <oh-copybutton class="contents">,
whose behaviour is one custom element in web/src/ui/copybutton.ts. What the
element reads from this markup is declared in web/src/ui/copybutton.contract.json
and asserted against the rendered output by copybutton_test.odin.

contents rather than block, like input and unlike progress: the inline-block div
below is already the component's own box, and an inline-block one at that -- a
copy button sits in a line of text or beside a field. A wrapper generating a
second box would change the layout of every one of them.

A ghost icon button that copies the text of another element to the clipboard:

    {h.pre(a.id("install")); h.text("go get ./...")}
    {copybutton.copybutton({target_id = "install"})}

It takes no children -- the two icons are the whole of its content -- so its
braces are the void-element kind.

target_id is the point of the component and is not optional in any useful
sense. copybutton.ts reads it from data-oh-copybutton-target, looks the element up
by id, and takes `value` if the target has one and textContent otherwise -- so an
input, a textarea and a <pre> all work without the caller saying which it is.
With no target_id the element logs and gives up. Nothing here enforces it: a
required field in a Props struct with defaults cannot be expressed, and rendering
a button that does nothing is upstream's behaviour too.

The lookup is by id through the document rather than inside the element, and
deliberately so: what a copy button copies is somewhere else on the page. That is
the same shape as label's target, and the one thing an element boundary cannot
narrow.

Both icons are always written, the check hidden by a class, and the element swaps
their inline display on a successful copy. Which means the swap is a style change
on elements that are already there -- no DOM building, nothing to re-init after a
swap.

## inline-block is layout again

It used to be load bearing. copybutton.js climbed from the button with
closest(".inline-block") to find a tooltip caption to rewrite while the copy was
confirmed, so changing that class to another inline utility silently cost the
tooltip text. <oh-copybutton> now sits exactly where that div sits in the tree, so
copybutton.ts starts the climb from the element itself and lands on the same
ancestor -- the class is free to be a layout choice again, and is left as
upstream's for that reason alone. (The caption it looks for is templui's
data-copy-tooltip-text, which nothing in this kit renders; the read is ported as
it stands and is not part of the contract, there being no agreement to test.)

Upstream generates a "copybutton-" id when the caller gives none. This port
writes id only when asked: the element reaches the button through
data-oh-copybutton="root" and the icons through their own roles, so the id was
never read. See toggle's file comment for why a rendered page having nothing
random in it is worth keeping.

props.class and attrs go to the button, not to the wrapper -- the button is the
part worth restyling, and htmx belongs on the thing that is clicked. */
package copybutton

import "core:strings"

import "html:html/a"
import "html:html/h"

import "ui:ui/button"
import "ui:ui/icon"

Props :: struct {
	id:        string,
	class:     string,

	// The id of the element to copy from. Read by copybutton.ts, not here.
	target_id: string,
}

/* Layout, and upstream's: an inline box, so a copy button sits in a line of
text. Nothing reads it any more -- see the file comment. */
@(private)
WRAPPER_CLASS :: "inline-block"

@(private)
BUTTON_BASE :: "h-7 w-7 text-muted-foreground hover:text-accent-foreground"

@(private)
ICON_CLASS :: "size-4"

/* The check starts hidden; copybutton.ts clears the inline display of one and
sets the other's to none. It never touches this class again, which is why the
element sets style rather than toggling `hidden`: after the first copy the class
is stale and the inline style is what decides. */
@(private)
CHECK_HIDDEN :: "hidden"

copybutton :: proc(props := Props{}, attrs: ..a.Attr) {
	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged.
	{h.elem("oh-copybutton", a.class("contents"))
		{h.div(
				a.data("oh-copybutton", "root"),
				a.data("oh-copybutton-target", props.target_id),
				a.class(WRAPPER_CLASS),
			)
			{button.button(
					{
						id = props.id,
						class = joined(BUTTON_BASE, props.class),
						size = .Icon,
						variant = .Ghost,
						type = .Button,
					},
					..attrs,
				)
				{h.span(a.data("oh-copybutton", "clipboard"))
					{ icon.icon(.Clipboard, {class = ICON_CLASS}) }
				}
				{h.span(a.data("oh-copybutton", "check"), a.class(CHECK_HIDDEN))
					{ icon.icon(.Check, {class = ICON_CLASS}) }
				}
			}
		}
	}
}

/* Props.class on button is a string rather than an attribute list, so a
component adding to it joins by hand -- the same helper pagination has, for the
same reason. Into the temp allocator, which is the render arena and freed with
the page. */
@(private)
joined :: proc(base, extra: string) -> string {
	if extra == "" {
		return base
	}
	return strings.concatenate({base, " ", extra}, context.temp_allocator)
}
