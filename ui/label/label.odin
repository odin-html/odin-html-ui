/* Label, ported from templui's components/label/label.templ -- and onto the
authoring model (the checklist in web/src/ui/README.md): the
markup is wrapped in <oh-label class="contents">, whose behaviour is one custom
element in web/src/ui/label.ts. What the element reads from this markup is
declared in web/src/ui/label.contract.json and asserted against the rendered
output by label_test.odin.

contents rather than block: the <label> below is already the component's box --
`inline-block`, sitting in whatever the caller laid out -- so a wrapper
generating a second box would change the layout of every label that was laid out
before the port. The utility is still explicit -- an unknown element is
display:inline otherwise, and only in the pre-upgrade window.

One component, a <label> that takes children:

    {label.label({for_ = "email"}); h.text("Email")}

The data attribute is not decoration. web/src/ui/label.ts finds the control the
`for` names, watches its `disabled`, and adds the classes in
data-oh-label-disabled-style to the label whenever that control is disabled.
Two things follow: a label written without `for` never dims, whatever sits
beside it, and the dimmed look is chosen here rather than in the script, which
only applies whatever the attribute says.

`error` sets the colour and nothing else -- it does not render the message.
Upstream takes a string only to test it for emptiness, and where the message
goes is the form's business. Kept as a string rather than narrowed to a bool so
a caller can pass the error it already has in hand.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package label

import "html:html/a"
import "html:html/h"

Props :: struct {
	id:    string,
	class: string,
	for_:  string,
	error: string,
}

/* One constant per string literal upstream, so a diff against it still lines
up. */
@(private)
BASE :: "text-sm font-medium leading-none inline-block"
@(private)
ERROR :: "text-destructive"

/* What label.ts writes onto the label while the labelled control is disabled.
A value rather than a rule inside the script, so the markup decides how a
disabled field reads. */
@(private)
DISABLED_STYLE :: "opacity-50 cursor-not-allowed"

/* The _open half, for components built on this one -- form.label is a label
with one prop dropped, and it cannot call label() to get it: that defers its
close, and a close deferred inside a wrapper's body runs at the end of *that
body*, before the wrapper's caller has written the caption.

The wrapper is opened here rather than in label() so that form.label gets it
too: both callers open a scope and hand this proc the region to record in, and
close_all writes </label></oh-label> at the end of the caller's block, innermost
first. Whoever renders a label renders its element.

A component's tool, not a template's: both opens fail the render when there is
no mark to record against. See odin-html-builder's html/h/component.odin. */
label_open :: proc(props := Props{}, attrs: ..a.Attr) {
	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged.
	{h.elem_open("oh-label", a.class("contents"))
		{h.label_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.attr_if(props.for_ != "", a.for_(props.for_)),
						a.class(BASE, props.error != "" ? ERROR : "", props.class),
						a.data("oh-label-disabled-style", DISABLED_STYLE),
					},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
label :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		label_open(props, ..attrs)
	}
}
