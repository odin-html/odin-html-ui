/* Button, ported from templui's components/button/button.templ.

Three notes on the port rather than on the component.

The element is handed to the caller's block. A button's content is its label,
which is what templ's `{ children... }` was carrying, so this is an _open
component and the braces at the call site are not optional -- see
odin-html-builder's html/h/component.odin:

    {button.button({variant = .Outline, size = .Sm}, hx.get("/save"))
        h.text("Save")
    }

templui pipes every class list through utils.TwMerge, which resolves
conflicting Tailwind utilities so that a caller's Class beats the variant and
size defaults. There is no equivalent here yet: the parts below are
concatenated in order, so a caller asking for its own height gets both that
utility and the size default on the element, and the stylesheet's source order
decides which applies. Additions that do not collide -- a margin, a fixed
width, the common case -- behave the same either way.

Those examples are described rather than spelled on purpose. Tailwind builds
the stylesheet by scanning these files as text and has no idea what an Odin
comment is, so a utility named in prose here is indistinguishable from one a
component actually uses, and ships as real CSS.

`href` is written verbatim. templ wraps it in templ.SafeURL, which rejects a
javascript: scheme; package a has no equivalent, and escape_attr does not help
because the payload never leaves the attribute value. Until there is one, an
href built from user input is an XSS here. */
package button

import "html:html/a"
import "html:html/h"

/* The zero value of each of these is the variant templui spells as the empty
string, so Props{} is already the default and the normalizing prologue
button.templ opens with (`if p.Type == ""`) has nothing left to do. */
Variant :: enum {
	Default,
	Destructive,
	Outline,
	Secondary,
	Ghost,
	Link,
}

Size :: enum {
	Default,
	Sm,
	Lg,
	Icon,
}

Type :: enum {
	Button,
	Reset,
	Submit,
}

/* Where the content sits along the button's main axis. Center is
upstream's and the zero value, so Props{} is unchanged.

It is a prop rather than something a caller appends to Props.class because
appending cannot win here: with no TwMerge the two utilities both land on
the element, and Tailwind emits .justify-center *after* .justify-between,
so the caller's is dead CSS whatever order it was written in. That is the
general shape of the no-TwMerge hazard the file comment describes, in the
one place a caller is likely to meet it -- a wide button with a label at
one end and a count at the other. Anything that collides with a base utility needs a prop; the
comment's "additions that do not collide" stay additions. */
Justify :: enum {
	Center,
	Start,
	End,
	Between,
}

Props :: struct {
	id:         string,
	class:      string,
	variant:    Variant,
	size:       Size,
	justify:    Justify,
	full_width: bool,
	href:       string,
	target:     string,
	disabled:   bool,
	type:       Type,
	form:       string,
}

/* Kept as one constant per string literal in button.templ rather than joined
into a single blob, so a diff against upstream still lines up. The one
departure is justify-center, which has moved out of this literal into the
enumerated array below -- a default nobody can override is worse than a
literal that no longer matches upstream character for character. */
@(private)
BASE_LAYOUT :: "inline-flex items-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-all"
@(private)
BASE_ICON :: "disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 shrink-0 [&_svg]:shrink-0"
@(private)
BASE_FOCUS :: "outline-none focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]"
@(private)
BASE_INVALID :: "aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive"
@(private)
BASE_CURSOR :: "cursor-pointer"

/* Enumerated arrays rather than the switches upstream uses: the mapping is
total either way, but this one the compiler checks for completeness. rodata
rather than a constant because the index is a runtime value -- Odin will not
index a compile-time array with one. */
@(private, rodata)
VARIANT_CLASSES := [Variant]string {
	.Default     = "bg-primary text-primary-foreground shadow-xs hover:bg-primary/90",
	.Destructive = "bg-destructive text-white shadow-xs hover:bg-destructive/90 focus-visible:ring-destructive/20 dark:focus-visible:ring-destructive/40 dark:bg-destructive/60",
	.Outline     = "border bg-background shadow-xs hover:bg-accent hover:text-accent-foreground dark:bg-input/30 dark:border-input dark:hover:bg-input/50",
	.Secondary   = "bg-secondary text-secondary-foreground shadow-xs hover:bg-secondary/80",
	.Ghost       = "hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50",
	.Link        = "text-primary underline-offset-4 hover:underline",
}

@(private, rodata)
JUSTIFY_CLASSES := [Justify]string {
	.Center  = "justify-center",
	.Start   = "justify-start",
	.End     = "justify-end",
	.Between = "justify-between",
}

@(private, rodata)
SIZE_CLASSES := [Size]string {
	.Default = "h-9 px-4 py-2 has-[>svg]:px-3",
	.Sm      = "h-8 rounded-md gap-1.5 px-3 has-[>svg]:px-2.5",
	.Lg      = "h-10 rounded-md px-6 has-[>svg]:px-4",
	.Icon    = "size-9",
}

@(private, rodata)
TYPE_NAMES := [Type]string {
	.Button = "button",
	.Reset  = "reset",
	.Submit = "submit",
}

/* a.class drops empty parts, so the modifier and the caller's class need no
branch -- which is the whole of upstream's modifierClasses and its
strings.Join. */
@(private)
classes :: proc(p: Props) -> a.Attr {
	return a.class(
		BASE_LAYOUT,
		JUSTIFY_CLASSES[p.justify],
		BASE_ICON,
		BASE_FOCUS,
		BASE_INVALID,
		BASE_CURSOR,
		VARIANT_CLASSES[p.variant],
		SIZE_CLASSES[p.size],
		p.full_width ? "w-full" : "",
		p.class,
	)
}

/* An href renders an <a>, anything else a <button>. Disabled overrides the
href: an anchor has no disabled attribute, so honouring the flag means not
being a link at all, and upstream resolves it the same way.

Note that the two arms open different tags in different scopes and this still
holds together -- inexpressible for a plain element, fine here, because _open
records the tag for the caller's close_all instead of deferring a close of its
own.

`attrs` is spread last, so a caller can override any attribute set here:
write_attrs lets the later duplicate win. That includes class, which replaces
the list above wholesale rather than adding to it -- use Props.class to add. */
@(deferred_none = h.close_all)
button :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		open(props, ..attrs)
	}
}

/* The element button() opens, without the scope or the deferred close.

For a component that wants to *be* a button while owning the surrounding
open_scope itself -- pagination's link, which is a button inside an li, and
cannot call button() because that would defer its close to the end of link's own
body rather than the end of link's caller's block, closing the tag before the
page number is written.

So this is the component-level counterpart of h's _open, and carries the same
rule: only a component may call it, from inside its own open_scope, with a
deferred close_all to match. A template calling it directly leaves a tag open
and fails the render. Everything else should call button(). */
open :: proc(props := Props{}, attrs: ..a.Attr) {
	if props.href != "" && !props.disabled {
		{h.a_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.href(props.href),
						a.attr_if(props.target != "", a.target(props.target)),
						classes(props),
					},
					attrs,
				),
			)
		}
	} else {
		{h.button_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						classes(props),
						a.type(TYPE_NAMES[props.type]),
						a.attr_if(props.form != "", a.form(props.form)),
						a.disabled(props.disabled),
					},
					attrs,
				),
			)
		}
	}
}
