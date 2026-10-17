/* Textarea, ported from templui's components/textarea/textarea.templ -- and
onto the authoring model (the checklist in web/src/ui/README.md):
the markup is wrapped in <oh-textarea class="contents">, whose behaviour is one
custom element in web/src/ui/textarea.ts. What the element reads from this
markup is declared in web/src/ui/textarea.contract.json and asserted against the
rendered output by textarea_test.odin.

contents rather than block, like input and unlike progress: the textarea below
is already the component's box and the caller's flex or grid item, so a wrapper
generating a second box would change the layout of every field that was laid out
before the port. The utility is still explicit -- an unknown element is
display:inline otherwise, and only in the pre-upgrade window.

    {textarea.textarea({name = "notes", rows = 4, value = job.notes})}

It takes no children -- the value is a prop, because a textarea's content *is*
its value and writing it as children would let a caller put elements somewhere
only text is allowed. So its braces are the void-element kind even though the
element itself is not void.

auto_resize hands the field to web/src/ui/textarea.ts, which grows it to fit on
every input event and once when the element connects. It also adds
overflow-hidden and resize-none: the scrollbar would flicker on each keystroke,
and a manual resize handle would fight the element for the height.

Upstream generates a random id when the caller gives none. This port writes one
only when asked -- the element works from data-oh-textarea and never looks an
element up by id. See toggle's file comment for why that is worth keeping.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package textarea

import "html:html/a"
import "html:html/h"

Props :: struct {
	id:          string,
	class:       string,
	name:        string,
	value:       string,
	form:        string,
	placeholder: string,

	// Written only when positive, so the browser's own default stands.
	rows:        int,
	auto_resize: bool,
	disabled:    bool,
	readonly:    bool,
	has_error:   bool,
}

/* Grouped the way upstream's own comments group these, rather than one
constant per string literal. */
@(private)
BASE ::
	"flex w-full min-w-0 rounded-md border border-input bg-transparent px-3 py-1 " +
	"text-base shadow-xs transition-[color,box-shadow] outline-none md:text-sm"

// A floor rather than a height: the box is two lines tall before rows or the
// auto-resize script have any say.
@(private)
BASE_MIN_HEIGHT :: "min-h-[80px]"
@(private)
BASE_DARK :: "dark:bg-input/30"
@(private)
BASE_SELECTION :: "selection:bg-primary selection:text-primary-foreground"
@(private)
BASE_PLACEHOLDER :: "placeholder:text-muted-foreground"
@(private)
BASE_FOCUS :: "focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]"
@(private)
BASE_DISABLED :: "disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50"
@(private)
BASE_INVALID ::
	"aria-invalid:ring-destructive/20 aria-invalid:border-destructive " + "dark:aria-invalid:ring-destructive/40"

@(private)
ERROR_CLASS :: "border-destructive ring-destructive/20 dark:ring-destructive/40"

/* Both halves of not fighting the element: the scrollbar would appear and
vanish on every keystroke, and the drag handle would set a height the next
input event overwrites. */
@(private)
AUTO_RESIZE_CLASS :: "overflow-hidden resize-none"

textarea :: proc(props := Props{}, attrs: ..a.Attr) {
	// The wrapper is the element boundary and nothing else: an explicit
	// display utility (an unknown element is display:inline before upgrade),
	// with everything the caller configures on the markup inside, unchanged.
	{h.elem("oh-textarea", a.class("contents"))
		{h.textarea(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.data("oh-textarea", true),
						a.attr_if(props.name != "", a.name(props.name)),
						a.attr_if(props.form != "", a.form(props.form)),
						a.attr_if(props.placeholder != "", a.placeholder(props.placeholder)),
						a.attr_if(props.rows > 0, a.rows(props.rows)),
						a.disabled(props.disabled),
						a.readonly(props.readonly),
						a.attr_if(props.has_error, a.aria("invalid", "true")),
						a.attr_if(props.auto_resize, a.data("oh-textarea-auto-resize", "true")),
						a.class(
							BASE,
							BASE_MIN_HEIGHT,
							BASE_DARK,
							BASE_SELECTION,
							BASE_PLACEHOLDER,
							BASE_FOCUS,
							BASE_DISABLED,
							BASE_INVALID,
							props.has_error ? ERROR_CLASS : "",
							props.auto_resize ? AUTO_RESIZE_CLASS : "",
							props.class,
						),
					},
					attrs,
				),
			)
			h.text(props.value)
		}
	}
}
