/* Tags input, ported from templui's components/tagsinput/tagsinput.templ -- and
onto the authoring model (the checklist in web/src/ui/README.md):
the markup is wrapped in <oh-tagsinput class="contents">, whose behaviour is one
custom element in web/src/ui/tagsinput.ts. What the element reads from this
markup is declared in web/src/ui/tagsinput.contract.json and asserted against the
rendered output by tagsinput_test.odin.

contents rather than block: the root div below is already the component's box
(flex flex-col ... w-full), so a wrapper generating a second box would put one
between the caller's layout and it. The utility is still explicit -- an unknown
element is display:inline otherwise, and only in the pre-upgrade window, where a
field laid out inline is exactly what it must not be.

The wrapper goes around the component, not around the error span: a tags input
that cannot be rendered has no behaviour to enhance.

A box of removable chips with a text field under them:

    {tagsinput.tagsinput({
        id = "labels",
        name = "labels",
        value = job.labels,
        suggestions = {"urgent", "warranty", "rework"},
    })}

One component, and it takes no children -- the tags are a prop, since they are
data rather than markup. Its braces are the void-element kind.

## What posts

One hidden input per tag, all sharing `name`, in a container the browser sees
but nobody looks at. web/src/ui/tagsinput.ts adds and removes those as chips
come and go, which is what makes the field a list rather than a string.

So the rendered page already posts the tags it was given, with or without the
bundle. What needs the element is adding and removing them.

## Suggestions

With any, the text field is wrapped in a popover whose trigger type is manual:
tagsinput.ts opens it as the field is typed in rather than on click. The
popover needs an id to be addressed, and this port does not invent ids -- so
suggestions without an id render an error span and nothing else, the same shape
calendar takes. Without suggestions, no id is needed and none is written.

The suggestion list is rendered in full and filtered in the browser, so a long
list is a long page.

The popover is popover.odin's with {kind = .Manual}: manual is this
component's by design -- its open and close
are tagsinput behaviour (typing filters, focus leaves), driven by tagsinput.ts
through the content's own showPopover()/hidePopover(), so light dismiss and
Escape must not fight it. The list matches the field's width by anchor-size()
now, which retired the --trigger-width variable the element used to measure
and write.

## attrs

Upstream spreads the caller's attributes onto the container *and* onto the text
input, so anything passed lands twice -- an id would appear on two elements.
Here they go to the container alone, which is the component's root and where
every other component in this collection puts them.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package tagsinput

import "core:strings"

import "html:html/a"
import "html:html/h"

import "ui:ui/badge"
import "ui:ui/input"
import "ui:ui/popover"

Props :: struct {
	// Required when suggestions are given -- see the file comment.
	id:          string,
	name:        string,

	// The tags to start with. One hidden input each.
	value:       []string,
	form:        string,
	placeholder: string,
	class:       string,
	has_error:   bool,
	disabled:    bool,
	readonly:    bool,

	// Rendered in full and filtered in the browser.
	suggestions: []string,
}

/* Grouped the way upstream's own comments group these. focus-within rather
than focus, because the thing that takes focus is the input inside. */
@(private)
ROOT_BASE ::
	"flex flex-col gap-2 p-2 rounded-md border border-input bg-transparent " +
	"shadow-xs transition-[color,box-shadow] outline-none"
@(private)
ROOT_DARK :: "dark:bg-input/30"
@(private)
ROOT_FOCUS :: "focus-within:border-ring focus-within:ring-ring/50 focus-within:ring-[3px]"
@(private)
ROOT_DISABLED :: "opacity-50 cursor-not-allowed"
@(private)
ROOT_WIDTH :: "w-full"
@(private)
ROOT_ERROR :: "border-destructive ring-destructive/20 dark:ring-destructive/40"

// empty:hidden, so the gap above the field closes when there are no tags.
@(private)
CHIPS_CLASS :: "flex flex-wrap gap-2 empty:hidden"

@(private)
REMOVE_CLASS ::
	"ml-1 text-current hover:text-destructive disabled:opacity-50 " + "disabled:cursor-not-allowed cursor-pointer"
@(private)
REMOVE_ICON_CLASS :: "h-3 w-3 pointer-events-none"

@(private)
FIELD_WRAPPER :: "relative w-full"

/* The input is stripped back to nothing so that the box around it -- the root
-- is what looks like a field. */
@(private)
FIELD_CLASS ::
	"border-0 shadow-none focus-visible:ring-0 h-auto py-0 px-0 bg-transparent " +
	"rounded-none min-h-0 disabled:opacity-100 dark:bg-transparent w-full"

/* anchor-size() matches the list to the field's width -- the anchor is the
field's wrapper div, per popover's anchoring -- with no measuring script. */
@(private)
SUGGESTIONS_CLASS ::
	"p-1 max-h-[200px] overflow-y-auto min-w-[anchor-size(width)] " + "w-[anchor-size(width)]"
@(private)
SUGGESTION_CLASS ::
	"relative flex w-full cursor-pointer select-none items-center rounded-sm " +
	"py-1.5 px-2 text-sm outline-none hover:bg-accent hover:text-accent-foreground"

@(private)
ERROR_CLASS :: "text-xs text-destructive"

@(private)
CONTAINER_SUFFIX :: "-container"
@(private)
SUGGESTIONS_SUFFIX :: "-suggestions"

@(private)
suffixed :: proc(id, suffix: string) -> string {
	return strings.concatenate({id, suffix}, context.temp_allocator)
}

tagsinput :: proc(props := Props{}, attrs: ..a.Attr) {
	/* The suggestions popover is addressed by id, and this port will not
	invent one. Without suggestions nothing needs an id, so the requirement
	only bites where it has to. */
	if len(props.suggestions) > 0 && props.id == "" {
		{h.span(a.class(ERROR_CLASS))
			h.text("Error: TagsInput with suggestions is missing required 'ID' attribute.")
		}
		return
	}

	has_suggestions := len(props.suggestions) > 0
	suggestions_id := has_suggestions ? suffixed(props.id, SUGGESTIONS_SUFFIX) : ""

	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged.
	{h.elem("oh-tagsinput", a.class("contents"))
		{h.div(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(suffixed(props.id, CONTAINER_SUFFIX))),
						a.class(
							ROOT_BASE,
							ROOT_DARK,
							ROOT_FOCUS,
							props.disabled ? ROOT_DISABLED : "",
							ROOT_WIDTH,
							props.has_error ? ROOT_ERROR : "",
							props.class,
						),
						a.data("oh-tagsinput", true),
						a.data("oh-tagsinput-name", props.name),
						a.data("oh-tagsinput-form", props.form),
						a.attr_if(has_suggestions, a.data("oh-tagsinput-suggestions-id", suggestions_id)),
					},
					attrs,
				),
			)
			{h.div(a.class(CHIPS_CLASS), a.data("oh-tagsinput-chips", true))
				for tag in props.value {
					chip(tag, props.disabled)
				}
			}

			if has_suggestions {
				{popover.root({id = suggestions_id})
					{popover.trigger({trigger_type = .Manual})
						field(props)
					}

					{popover.content(
							{placement = .Bottom_Start, kind = .Manual, class = SUGGESTIONS_CLASS},
							a.data("oh-tagsinput-suggestions-content", "true"),
						)
						for suggestion in props.suggestions {
							{h.div(
									a.class(SUGGESTION_CLASS),
									a.data("oh-tagsinput-suggestion", true),
									a.data("oh-tagsinput-suggestion-value", suggestion),
								)
								h.text(suggestion)
							}
						}
					}
				}
			} else {
				field(props)
			}

			// What the form actually sends. Hidden as a group rather than one by
			// one, so tagsinput.ts can add and remove them without restyling.
			{h.div(a.data("oh-tagsinput-hidden-inputs", true), a.class("hidden"))
				for tag in props.value {
					{ h.input(a.type("hidden"), a.name(props.name), a.value(tag)) }
				}
			}
		}
	}
}

/* One tag. The badge is the chip and the button inside it is the remove -- the
attributes are what tagsinput.ts works from, not the classes. The span holding
the text is load bearing too: it is what the element reads a chip's tag from
when the chip is taken off. */
@(private)
chip :: proc(tag: string, disabled: bool) {
	{badge.badge({}, a.data("oh-tagsinput-chip", ""))
		{ h.span(); h.text(tag) }
		{h.button(a.type("button"), a.class(REMOVE_CLASS), a.disabled(disabled), a.data("oh-tagsinput-remove", true))
			remove_icon()
		}
	}
}

/* Upstream's own inline SVG rather than the icon package's x: a 2-unit stroke
on a 24-unit viewBox, sized to the chip. Kept so the markup matches. */
@(private)
remove_icon :: proc() {
	{h.svg(
			a.xmlns("http://www.w3.org/2000/svg"),
			a.class(REMOVE_ICON_CLASS),
			a.fill("none"),
			a.view_box("0 0 24 24"),
			a.stroke("currentColor"),
			a.stroke_width("2"),
		)
		{h.path(a.stroke_linecap("round"), a.stroke_linejoin("round"), a.d("M6 18L18 6M6 6l12 12"))
		}
	}
}

/* The text field, in both arms of the suggestions branch -- identical either
way, which is why it is a proc rather than written twice. */
@(private)
field :: proc(props: Props) {
	{h.div(a.class(FIELD_WRAPPER))
		{input.input(
				{
					id = props.id,
					class = FIELD_CLASS,
					type = .Text,
					placeholder = props.placeholder,
					disabled = props.disabled,
					readonly = props.readonly,
				},
				a.data("oh-tagsinput-text-input", ""),
			)}
	}
}
