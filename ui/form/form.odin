/* Form, ported from templui's components/form/form.templ.

Five wrappers for laying a field out. No <form> element and no form behaviour:
this is the row around a control, its caption, its hint and its error.

    {form.item()
        {form.label({for_ = "email"}); h.text("Email")}
        {input.input({id = "email", name = "email", has_error = true})}
        {form.description(); h.text("We only use this to reach you.")}
        {form.message({variant = .Error}); h.text("That address is not valid.")}
    }

All five take children, so all five need braces at the call site.

item stacks its children with space-y-2 and is the ordinary case. item_flex
puts them in a row instead, for a checkbox or a switch beside its caption --
where the control and the words belong on one line.

form.label is label with one prop removed, so a form's caption cannot be given
its own error colour: within a form the error is a message() below, and
colouring both would say it twice.

Upstream's LabelProps carries a DisabledClass that it never passes on -- it is
read nowhere in templui. Dropped rather than carried across as a field that
does nothing; label's own data-oh-label-disabled-style is the working version
of that idea.

message with the zero variant has no colour of its own, which is upstream's
default branch. Give it .Error or .Info, or a class.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package form

import "html:html/a"
import "html:html/h"

import lbl "ui:ui/label"

/* The zero value is upstream's default branch: no colour, so the message
inherits whatever is around it. */
Message_Variant :: enum {
	None,
	Error,
	Info,
}

Item_Props :: struct {
	id:    string,
	class: string,
}

Label_Props :: struct {
	id:    string,
	class: string,
	for_:  string,
}

Description_Props :: struct {
	id:    string,
	class: string,
}

Message_Props :: struct {
	id:      string,
	class:   string,
	variant: Message_Variant,
}

/* One constant per string literal upstream, so a diff against it still lines
up. */
@(private)
ITEM_BASE :: "space-y-2"
@(private)
ITEM_FLEX_BASE :: "items-center flex space-x-2"
@(private)
DESCRIPTION_BASE :: "text-sm text-muted-foreground"
@(private)
MESSAGE_BASE :: "text-[0.8rem] font-medium"

@(private)
MESSAGE_ERROR :: "text-red-500"
@(private)
MESSAGE_INFO :: "text-blue-500"

@(private)
message_variant_class :: proc(v: Message_Variant) -> string {
	switch v {
	case .Error:
		return MESSAGE_ERROR
	case .Info:
		return MESSAGE_INFO
	case .None:
		return ""
	}
	return ""
}

@(deferred_none = h.close_all)
item :: proc(props := Item_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(ITEM_BASE, props.class)}, attrs),
			)
		}
	}
}

/* The one-line arrangement: a checkbox and its caption, rather than a caption
above a field. */
@(deferred_none = h.close_all)
item_flex :: proc(props := Item_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(ITEM_FLEX_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}

/* label's element, opened here so the close lands in this caller's block --
see the _open half in label. The package is imported as lbl so that this proc
can be form.label(): an import binds its own name in file scope, and the two
would collide. */
@(deferred_none = h.close_all)
label :: proc(props := Label_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		lbl.label_open({id = props.id, class = props.class, for_ = props.for_}, ..attrs)
	}
}

/* A p, so it cannot hold another p -- the parser would close this one at the
opening tag of the next. */
@(deferred_none = h.close_all)
description :: proc(props := Description_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.p_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(DESCRIPTION_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
message :: proc(props := Message_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.p_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(MESSAGE_BASE, message_variant_class(props.variant), props.class),
					},
					attrs,
				),
			)
		}
	}
}
