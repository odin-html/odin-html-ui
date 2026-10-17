/* Badge, ported from templui's components/badge/badge.templ.

One component and one element, so this is the smallest of the ports: a span, a
variant, and whatever the caller writes inside it.

    {badge.badge({variant = .Secondary})
        h.text("Draft")
    }

It takes children, so it is an _open component and the braces are not optional
-- see odin-html-builder's html/h/component.odin.

Two things carried over from upstream that are worth knowing before using it.

The variant classes each carry a hover rule guarded by `[a&]`, which matches the
element only when the element is itself an anchor. shadcn's badge can become one
through asChild; templui's cannot, and neither can this, so those rules are
inert here -- every badge is a span and nothing hovers. They are kept rather
than trimmed so a diff against upstream still lines up, and because they are the
shape of the answer if a linked badge is ever wanted: an href prop like button's,
which would make them live. Left until something asks for it.

An svg child is sized by the badge rather than by itself, which is the same
direct-child contract alert has: the selector reaches one level down, so an icon
wrapped in anything is not sized. There is no grid here to go wrong, only the
size, so it fails quietly rather than visibly.

As in button and alert there is no TwMerge, so a caller's class is appended
rather than merged -- see the file comment in button/button.odin, including why
its examples are described rather than spelled. */
package badge

import "html:html/a"
import "html:html/h"

/* The zero value is upstream's "default", so Props{} needs no normalizing. */
Variant :: enum {
	Default,
	Secondary,
	Destructive,
	Outline,
}

Props :: struct {
	id:      string,
	class:   string,
	variant: Variant,
}

/* One constant per string literal in badge.templ rather than one blob, so a
diff against upstream still lines up. */
@(private)
BASE_LAYOUT :: "inline-flex items-center justify-center rounded-md border px-2 py-0.5 text-xs font-medium w-fit whitespace-nowrap shrink-0 [&>svg]:size-3 gap-1 [&>svg]:pointer-events-none"
@(private)
BASE_FOCUS :: "focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]"
@(private)
BASE_INVALID :: "aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive"
@(private)
BASE_MOTION :: "transition-[color,box-shadow] overflow-hidden"

/* An enumerated array rather than the method upstream hangs off Props: the
mapping is total either way, but this one the compiler checks for completeness.
rodata rather than a constant because the index is a runtime value. */
@(private, rodata)
VARIANT_CLASSES := [Variant]string {
	.Default     = "border-transparent bg-primary text-primary-foreground [a&]:hover:bg-primary/90",
	.Secondary   = "border-transparent bg-secondary text-secondary-foreground [a&]:hover:bg-secondary/90",
	.Destructive = "border-transparent bg-destructive text-white [a&]:hover:bg-destructive/90 focus-visible:ring-destructive/20 dark:focus-visible:ring-destructive/40 dark:bg-destructive/60",
	.Outline     = "text-foreground [a&]:hover:bg-accent [a&]:hover:text-accent-foreground",
}

/* `attrs` is spread last, so a caller can override anything set here:
write_attrs lets the later duplicate win. That includes class, which replaces
the list above wholesale rather than adding to it -- use Props.class to add. */
@(deferred_none = h.close_all)
badge :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.span_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(
							BASE_LAYOUT,
							BASE_FOCUS,
							BASE_INVALID,
							BASE_MOTION,
							VARIANT_CLASSES[props.variant],
							props.class,
						),
					},
					attrs,
				),
			)
		}
	}
}
