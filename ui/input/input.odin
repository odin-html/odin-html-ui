/* Input, ported from templui's components/input/input.templ -- and onto the
authoring model (the checklist in web/src/ui/README.md): the
markup is wrapped in <oh-input class="contents">, whose behaviour is one custom
element in web/src/ui/input.ts. What the element reads from this markup is
declared in web/src/ui/input.contract.json and asserted against the rendered
output by input_test.odin.

contents rather than block, unlike progress: the relative w-full div below is
already the component's box and the caller's flex or grid item, so a wrapper
generating a second box would change the layout of every field that was laid
out before the port. The utility is still explicit -- an unknown element is
display:inline otherwise, and only in the pre-upgrade window.

A text field, wrapped in a relative div so that a password toggle can sit on
top of it:

    {input.input({name = "email", type = .Email, placeholder = "you@example.com"})}

It takes no children, so its braces are the void-element kind.

The wrapper is written whatever the type, and is `relative w-full` -- so an
input is always as wide as what it is put in, and a row of them wants a grid
rather than widths here.

## The password toggle, and the one deviation

A password field gets an eye button that flips the input between password and
text. web/src/ui/input.ts does the flipping, and finds the input by id:
data-oh-toggle-password holds the id, and the element looks it up among its own
descendants. So the id is load bearing for exactly this one case.

Upstream invents a random id when the caller gives none, which makes the toggle
always work and makes the markup differ between two renders of the same page.
This port does not invent ids -- see toggle's file comment for why -- so the
toggle is written only when there *is* an id to point at. A password input with
no id renders as a plain password input: no button, and no pr-8 either, since
the padding is only there to leave room for the button.

For a caller who passes an id, which is what a labelled field does anyway, the
output is upstream's exactly.

## has_error

Sets aria-invalid and adds the destructive ring. It does not render a message;
the message belongs to whatever the form uses for errors, and label's `error`
colours the label to match.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package input

import "html:html/a"
import "html:html/h"

import "ui:ui/button"
import "ui:ui/icon"

/* Text is the zero value, which is also what upstream falls back to when Type
is empty. Date_Time is "datetime-local" -- the only member whose attribute
value is not its name lowercased. */
Type :: enum {
	Text,
	Password,
	Email,
	Number,
	Tel,
	Url,
	Search,
	Date,
	Date_Time,
	Time,
	File,
	Color,
	Week,
	Month,
}

Props :: struct {
	id:                 string,
	class:              string,
	name:               string,
	type:               Type,
	form:               string,
	placeholder:        string,
	value:              string,
	disabled:           bool,
	readonly:           bool,
	required:           bool,

	// Only written when type is .File.
	file_accept:        string,
	has_error:          bool,

	// Suppresses the eye button on a password field.
	no_toggle_password: bool,
}

@(private)
WRAPPER :: "relative w-full"

/* Grouped the way upstream's own comments group these, rather than one
constant per string literal. */
@(private)
BASE ::
	"flex h-9 w-full min-w-0 rounded-md border border-input bg-transparent px-3 py-1 " +
	"text-base shadow-xs transition-[color,box-shadow] outline-none md:text-sm"
@(private)
BASE_DARK :: "dark:bg-input/30"
@(private)
BASE_SELECTION :: "selection:bg-primary selection:text-primary-foreground"
@(private)
BASE_PLACEHOLDER :: "placeholder:text-muted-foreground"
@(private)
BASE_FILE ::
	"file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm " +
	"file:font-medium file:text-foreground"
@(private)
BASE_FOCUS :: "focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]"
@(private)
BASE_DISABLED :: "disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50"
@(private)
BASE_INVALID ::
	"aria-invalid:ring-destructive/20 aria-invalid:border-destructive " + "dark:aria-invalid:ring-destructive/40"

@(private)
ERROR_CLASS :: "border-destructive ring-destructive/20 dark:ring-destructive/40"

// Room for the eye button, and written only when there is one.
@(private)
TOGGLE_PADDING :: "pr-8"

@(private)
TOGGLE_BUTTON :: "absolute right-0 top-1/2 -translate-y-1/2 opacity-50 cursor-pointer"

@(private)
TOGGLE_ICON :: "size-[18px]"

/* The two spans input.ts switches between. It toggles `hidden` on them, so the
starting state has to be exactly one of each. */
@(private)
ICON_OPEN :: "icon-open block"
@(private)
ICON_CLOSED :: "icon-closed hidden"

@(private)
type_attr :: proc(t: Type) -> string {
	switch t {
	case .Text:
		return "text"
	case .Password:
		return "password"
	case .Email:
		return "email"
	case .Number:
		return "number"
	case .Tel:
		return "tel"
	case .Url:
		return "url"
	case .Search:
		return "search"
	case .Date:
		return "date"
	case .Date_Time:
		return "datetime-local"
	case .Time:
		return "time"
	case .File:
		return "file"
	case .Color:
		return "color"
	case .Week:
		return "week"
	case .Month:
		return "month"
	}
	return "text"
}

input :: proc(props := Props{}, attrs: ..a.Attr) {
	// Both the padding and the button hang off this, so a field cannot end up
	// with room reserved for a control that was never written.
	toggle := props.type == .Password && !props.no_toggle_password && props.id != ""

	// The wrapper is the element boundary and nothing else: an explicit
	// display utility (an unknown element is display:inline before upgrade),
	// with everything the caller configures on the markup inside, unchanged.
	{h.elem("oh-input", a.class("contents"))
		{h.div(a.class(WRAPPER))
			{h.input(
					..a.join(
						[]a.Attr {
							a.attr_if(props.id != "", a.id(props.id)),
							a.type(type_attr(props.type)),
							a.attr_if(props.name != "", a.name(props.name)),
							a.attr_if(props.placeholder != "", a.placeholder(props.placeholder)),
							a.attr_if(props.value != "", a.value(props.value)),
							a.attr_if(
								props.type == .File && props.file_accept != "",
								a.accept(props.file_accept),
							),
							a.attr_if(props.form != "", a.form(props.form)),
							a.disabled(props.disabled),
							a.readonly(props.readonly),
							a.required(props.required),
							a.attr_if(props.has_error, a.aria("invalid", "true")),
							a.class(
								BASE,
								BASE_DARK,
								BASE_SELECTION,
								BASE_PLACEHOLDER,
								BASE_FILE,
								BASE_FOCUS,
								BASE_DISABLED,
								BASE_INVALID,
								props.has_error ? ERROR_CLASS : "",
								toggle ? TOGGLE_PADDING : "",
								props.class,
							),
						},
						attrs,
					),
				)
			}

			if toggle {
				{button.button(
						{size = .Icon, variant = .Ghost, class = TOGGLE_BUTTON},
						a.data("oh-toggle-password", props.id),
					)
					{h.span(a.class(ICON_OPEN))
						{ icon.icon(.Eye, {class = TOGGLE_ICON}) }
					}
					{h.span(a.class(ICON_CLOSED))
						{ icon.icon(.Eye_Off, {class = TOGGLE_ICON}) }
					}
				}
			}
		}
	}
}
