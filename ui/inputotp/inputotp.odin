/* Input OTP, ported from templui's components/inputotp/inputotp.templ -- and
onto the authoring model (the checklist in web/src/ui/README.md):
the markup is wrapped in <oh-inputotp class="contents">, whose behaviour is one
custom element in web/src/ui/inputotp.ts. What the element reads from this
markup is declared in web/src/ui/inputotp.contract.json and asserted against the
rendered output by inputotp_test.odin.

contents rather than block: the root below is already the component's box --
`flex flex-row items-center gap-2 w-fit`, and the caller's flex or grid item --
so a wrapper generating a second box would change the layout of every code row
that was laid out before the port. The utility is still explicit: an unknown
element is display:inline otherwise, and only in the pre-upgrade window.

A row of one-character boxes for a one-time code:

    {inputotp.inputotp({id = "otp", name = "code"})
        {inputotp.group()
            {inputotp.slot({index = 0})}
            {inputotp.slot({index = 1})}
            {inputotp.slot({index = 2})}
        }
        {inputotp.separator()}
        {inputotp.group()
            {inputotp.slot({index = 3})}
            {inputotp.slot({index = 4})}
            {inputotp.slot({index = 5})}
        }
    }

inputotp() and group() take children; slot() and separator() do not, so their
braces are the void-element kind.

The wrapper goes on inputotp() alone. group(), slot() and separator() are its
descendants and are found by their data-oh-* roles from inside it, so none
carries an element of its own -- and any of them can still be written outside an
inputotp(), where nothing looks for them.

## Where the value lives

Each slot is its own <input maxlength="1">, and none of them is the field that
posts. That is the hidden input inside the root, and web/src/ui/inputotp.ts
keeps it in step: typing moves focus along, backspace moves it back, and a
paste fills the row from wherever it lands.

Which is why the index matters and is the caller's to get right -- the element
sorts the slots by data-oh-inputotp-index, not by document order, so a
mis-numbered row scrambles the code without looking wrong.

A server-rendered value goes on the root as data-oh-inputotp-value, and the
element spreads it across the slots when it connects. So a page without the
bundle shows an empty row even when the server sent a value, and posts an empty
string.

## Two upstream oddities, one kept and one not

Kept: `form` is written on the root <div>, where the attribute means nothing --
it belongs on a form-associated element, and the hidden input beside it is the
one that would need it. So a slot row inside no <form> posts nothing however
the prop is set. Ported as it stands, because changing which element carries it
is a behaviour change rather than a port.

Not kept: upstream spreads a slot's attributes onto both the wrapper div and
the input inside it, so anything passed lands twice -- an id would appear on
two elements. Here they go to the input alone, which is the control worth
addressing.

Also worth knowing: the root's `id` produces two ids, `<id>-container` on the
root div and `<id>` on the hidden input. That is upstream's, and it is what lets
a label point at something postable -- a hidden input is not labelable, so the
browser forwards nothing and inputotp.ts does the forwarding by hand, sending
the caret to the first slot.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package inputotp

import "core:strings"

import "html:html/a"
import "html:html/h"

Props :: struct {
	/* Produces two ids: <id>-container on the root div, <id> on the hidden
	input. */
	id:        string,
	class:     string,

	// Spread across the slots by inputotp.ts, not rendered into them here.
	value:     string,
	name:      string,

	// Written on the root div, where it does nothing -- see the file comment.
	form:      string,
	has_error: bool,
}

Group_Props :: struct {
	id:    string,
	class: string,
}

Slot_Props :: struct {
	id:          string,
	class:       string,

	// The slot's place in the code. inputotp.ts sorts by this, not by
	// document order.
	index:       int,

	// Empty means "text". Upstream takes a free string rather than an enum.
	type:        string,
	placeholder: string,
	disabled:    bool,
	has_error:   bool,
}

Separator_Props :: struct {
	id:    string,
	class: string,
}

@(private)
ROOT_BASE :: "flex flex-row items-center gap-2 w-fit"
@(private)
GROUP_BASE :: "flex gap-2"
@(private)
SLOT_WRAPPER :: "relative"

/* Grouped the way upstream's own comments group these. The dimensions are the
component: a fixed box per character rather than one field. */
@(private)
SLOT_BASE ::
	"w-10 h-12 text-center rounded-md border border-input bg-transparent text-base " +
	"shadow-xs transition-[color,box-shadow] outline-none md:text-sm"
@(private)
SLOT_DARK :: "dark:bg-input/30"
@(private)
SLOT_SELECTION :: "selection:bg-primary selection:text-primary-foreground"
@(private)
SLOT_PLACEHOLDER :: "placeholder:text-muted-foreground"
@(private)
SLOT_FOCUS :: "focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]"
@(private)
SLOT_DISABLED :: "disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50"
@(private)
SLOT_INVALID ::
	"aria-invalid:ring-destructive/20 aria-invalid:border-destructive " + "dark:aria-invalid:ring-destructive/40"
@(private)
SLOT_ERROR :: "border-destructive ring-destructive/20 dark:ring-destructive/40"

@(private)
SEPARATOR_BASE :: "flex items-center text-muted-foreground text-xl"

@(private)
DEFAULT_TYPE :: "text"

@(private)
CONTAINER_SUFFIX :: "-container"

@(deferred_none = h.close_all)
inputotp :: proc(props := Props{}, attrs: ..a.Attr) {
	container_id := props.id == "" ? "" : strings.concatenate({props.id, CONTAINER_SUFFIX}, context.temp_allocator)

	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged. It is
	// opened into the same scope as the root div, so close_all writes both
	// closing tags at the end of the caller's block, innermost first.
	{h.open_scope()
		{h.elem_open("oh-inputotp", a.class("contents"))
			{h.div_open(
					..a.join(
						[]a.Attr {
							a.attr_if(container_id != "", a.id(container_id)),
							a.attr_if(props.value != "", a.data("oh-inputotp-value", props.value)),
							a.attr_if(props.form != "", a.form(props.form)),
							a.class(ROOT_BASE, props.class),
							a.data("oh-inputotp", true),
						},
						attrs,
					),
				)
				// The field that actually posts. Written before the caller's
				// children so the slots follow it, as upstream has them.
				{h.input(
						a.type("hidden"),
						a.attr_if(props.id != "", a.id(props.id)),
						a.attr_if(props.name != "", a.name(props.name)),
						a.attr_if(props.has_error, a.aria("invalid", "true")),
						a.data("oh-inputotp-value-target", true),
					)
				}
			}
		}
	}
}

/* A run of slots. Two groups with a separator between them is how a 6-digit
code is usually broken up. */
@(deferred_none = h.close_all)
group :: proc(props := Group_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(GROUP_BASE, props.class)}, attrs),
			)
		}
	}
}

/* One character. inputmode="numeric" brings up a digit keypad without
restricting what can be typed -- the type prop decides that. */
slot :: proc(props := Slot_Props{}, attrs: ..a.Attr) {
	{h.div(a.attr_if(props.id != "", a.id(props.id)), a.class(SLOT_WRAPPER))
		{h.input(
				..a.join(
					[]a.Attr {
						a.type(props.type != "" ? props.type : DEFAULT_TYPE),
						a.inputmode("numeric"),
						a.attr_if(props.placeholder != "", a.placeholder(props.placeholder)),
						a.maxlength("1"),
						a.class(
							SLOT_BASE,
							SLOT_DARK,
							SLOT_SELECTION,
							SLOT_PLACEHOLDER,
							SLOT_FOCUS,
							SLOT_DISABLED,
							SLOT_INVALID,
							props.has_error ? SLOT_ERROR : "",
							props.class,
						),
						a.disabled(props.disabled),
						a.attr_if(props.has_error, a.aria("invalid", "true")),
						a.data("oh-inputotp-index", props.index),
						a.data("oh-inputotp-slot", true),
					},
					attrs,
				),
			)
		}
	}
}

/* The dash between two groups. Decorative -- it is not announced, and nothing
reads it. */
separator :: proc(props := Separator_Props{}, attrs: ..a.Attr) {
	{h.div(..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(SEPARATOR_BASE, props.class)}, attrs))
		{ h.span(); h.text("-") }
	}
}
