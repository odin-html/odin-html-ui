/* Aspect ratio, ported from templui's components/aspectratio/aspectratio.templ.

Two nested divs: an outer one that holds the ratio and an inner one pinned to
its edges, and it is the inner one the caller's children land in.

    {aspectratio.aspect_ratio({ratio = .Video})
        {h.img(a.src("/still.png"), a.class("size-full object-cover"))}
    }

That is the whole mechanism. The outer div reserves the space -- aspect-video
and the rest give it a height derived from its width, before the content has
loaded -- and the inner one takes it over absolutely, so an image or an iframe
inside stretches to the box rather than deciding it. Content that sizes itself
will still overflow; a child usually wants the full size and a crop, as above.

An _open component, since the children are the point, so the braces at the call
site are not optional -- see odin-html-builder's html/h/component.odin. It opens two elements
and hands over the inner: close_all closes both, innermost first.

Ratio is an enum where upstream has a string, and .Auto is the zero value
because upstream's zero value -- the empty string -- falls through its switch to
the same class the explicit "auto" produces. Props{} therefore renders what
upstream's Props{} renders.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. Note that a class naming another ratio does not
replace this one, it joins it, and which wins is stylesheet order. */
package aspectratio

import "html:html/a"
import "html:html/h"

Ratio :: enum {
	Auto,
	Square,
	Video,
	Portrait,
	Wide,
}

Props :: struct {
	id:    string,
	class: string,
	ratio: Ratio,
}

@(private)
BASE :: "relative w-full"

/* The inner div. Not a prop and not reachable from outside: the component is
this pair, and a caller who could restyle the inner one could unpin it from the
outer and lose the ratio. */
@(private)
INNER :: "absolute inset-0"

/* An enumerated array rather than the switch upstream uses: the mapping is
total either way, but this one the compiler checks for completeness. rodata
rather than a constant because the index is a runtime value. */
@(private, rodata)
RATIO_CLASSES := [Ratio]string {
	.Auto     = "aspect-auto",
	.Square   = "aspect-square",
	.Video    = "aspect-video",
	.Portrait = "aspect-[3/4]",
	.Wide     = "aspect-[2/1]",
}

/* `attrs` is spread last, so a caller can override anything set on the outer
div. Nothing reaches the inner one, which is deliberate. */
@(deferred_none = h.close_all)
aspect_ratio :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(BASE, RATIO_CLASSES[props.ratio], props.class),
					},
					attrs,
				),
			)
			{h.div_open(a.class(INNER))
			}
		}
	}
}
