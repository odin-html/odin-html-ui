/* Carousel, ported from templui's components/carousel/carousel.templ -- and onto
the authoring model (the checklist in web/src/ui/README.md): the
markup is wrapped in <oh-carousel class="contents">, whose behaviour is one custom
element in web/src/ui/carousel.ts. What the element reads from this markup is
declared in web/src/ui/carousel.contract.json and asserted against the rendered
output by carousel_test.odin.

contents rather than block, like avatar and unlike progress: the frame below is
already the component's box -- `relative overflow-hidden w-full`, and whatever
height the caller gives it -- so a wrapper generating a second box would change
the layout of every carousel that was laid out before the port. The utility is
still explicit -- an unknown element is display:inline otherwise, and only in the
pre-upgrade window.

Six components: the frame, the track, a slide, two arrows and a row of dots.

    {carousel.carousel({autoplay = true, loop = true})
        {carousel.content()
            {carousel.item()
                {h.img(a.src("/1.jpg"), a.alt(""))}
            }
            {carousel.item()
                {h.img(a.src("/2.jpg"), a.alt(""))}
            }
        }
        {carousel.previous()}
        {carousel.next()}
        {carousel.indicators({count = 2})}
    }

The first three take children. previous(), next() and indicators() do not --
their braces are the void-element kind.

## What the server draws

The track is a flex row as wide as its slides, and moving it is a transform
carousel.ts sets. Nothing here positions it, so an unscripted page shows the
first slide and no way to reach the others -- the arrows and dots are inert
without the bundle.

The frame is `overflow-hidden`, which is what hides slides two onward; the
slides are `w-full flex-shrink-0`, so each is exactly the frame's width however
many there are.

carousel.ts also watches the frame with an IntersectionObserver, so autoplay
only runs while the carousel is on screen. That observer stays -- it is not the
content-arrival kind htmx replaces.

## indicators

count is how many dots to draw, and it is the caller's job to make it match the
number of slides: nothing here counts them, since the slides are the caller's
children and are written after this component runs. Too few dots leaves slides
unreachable by clicking; too many leaves dots that go nowhere.

The first dot is drawn active. carousel.ts keeps them in step from there, so
the initial state is the only one this file decides.

Upstream generates no id for a carousel and neither does this -- carousel.ts
finds a carousel's parts by their data-oh-* roles, inside its own element.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package carousel

import "core:fmt"

import "html:html/a"
import "html:html/h"

import "ui:ui/icon"

Props :: struct {
	id:       string,
	class:    string,
	autoplay: bool,

	// Milliseconds between slides. Zero means 5000.
	interval: int,

	// Wraps around at either end rather than stopping.
	loop:     bool,
}

Content_Props :: struct {
	id:    string,
	class: string,
}

Item_Props :: struct {
	id:    string,
	class: string,
}

Previous_Props :: struct {
	id:    string,
	class: string,
}

Next_Props :: struct {
	id:    string,
	class: string,
}

Indicators_Props :: struct {
	id:    string,
	class: string,

	// How many dots. The caller keeps this in step with the slides.
	count: int,
}

@(private)
DEFAULT_INTERVAL :: 5000

/* One constant per string literal upstream, so a diff against it still lines
up. */
@(private)
ROOT_BASE :: "relative overflow-hidden w-full"

/* cursor-grab because carousel.ts implements dragging; the transform it sets
is what the transition animates. */
@(private)
TRACK_BASE :: "flex h-full w-full transition-transform duration-500 ease-in-out cursor-grab"

@(private)
ITEM_BASE :: "flex-shrink-0 w-full h-full relative"

@(private)
PREVIOUS_BASE ::
	"absolute left-2 top-1/2 transform -translate-y-1/2 p-2 rounded-full " +
	"bg-black/20 text-white hover:bg-black/40 focus:outline-none"
@(private)
NEXT_BASE ::
	"absolute right-2 top-1/2 transform -translate-y-1/2 p-2 rounded-full " +
	"bg-black/20 text-white hover:bg-black/40 focus:outline-none"

@(private)
INDICATORS_BASE :: "absolute bottom-4 left-1/2 transform -translate-x-1/2 flex gap-2"
@(private)
DOT_BASE :: "w-3 h-3 rounded-full bg-foreground/30 hover:bg-foreground/50 " + "focus:outline-none transition-colors"
@(private)
DOT_ACTIVE :: "bg-primary"

@(private)
bool_attr :: proc(b: bool) -> string {
	return b ? "true" : "false"
}

@(deferred_none = h.close_all)
carousel :: proc(props := Props{}, attrs: ..a.Attr) {
	interval := props.interval == 0 ? DEFAULT_INTERVAL : props.interval

	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged. It is
	// opened into the same scope as the frame, so close_all writes both closing
	// tags at the end of the caller's block, innermost first.
	{h.open_scope()
		{h.elem_open("oh-carousel", a.class("contents"))
			{h.div_open(
					..a.join(
						[]a.Attr {
							a.attr_if(props.id != "", a.id(props.id)),
							a.class(ROOT_BASE, props.class),
							a.data("oh-carousel", true),
							a.data("oh-carousel-current", "0"),
							a.data("oh-carousel-autoplay", bool_attr(props.autoplay)),
							a.data("oh-carousel-interval", interval),
							a.data("oh-carousel-loop", bool_attr(props.loop)),
						},
						attrs,
					),
				)
			}
		}
	}
}

/* The strip the slides sit in. carousel.ts moves this, not the frame. */
@(deferred_none = h.close_all)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(TRACK_BASE, props.class),
						a.data("oh-carousel-track", true),
					},
					attrs,
				),
			)}
	}
}

@(deferred_none = h.close_all)
item :: proc(props := Item_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(ITEM_BASE, props.class),
						a.data("oh-carousel-item", true),
					},
					attrs,
				),
			)}
	}
}

previous :: proc(props := Previous_Props{}, attrs: ..a.Attr) {
	{h.button(
			..a.join(
				[]a.Attr {
					a.attr_if(props.id != "", a.id(props.id)),
					a.class(PREVIOUS_BASE, props.class),
					a.data("oh-carousel-prev", true),
					a.aria("label", "Previous slide"),
					a.type("button"),
				},
				attrs,
			),
		)
		{ icon.icon(.Chevron_Left) }
	}
}

next :: proc(props := Next_Props{}, attrs: ..a.Attr) {
	{h.button(
			..a.join(
				[]a.Attr {
					a.attr_if(props.id != "", a.id(props.id)),
					a.class(NEXT_BASE, props.class),
					a.data("oh-carousel-next", true),
					a.aria("label", "Next slide"),
					a.type("button"),
				},
				attrs,
			),
		)
		{ icon.icon(.Chevron_Right) }
	}
}

/* The dots. Each carries its index, which is what carousel.ts jumps to, and
the first is drawn active -- the only state decided here. */
indicators :: proc(props := Indicators_Props{}, attrs: ..a.Attr) {
	{h.div(..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(INDICATORS_BASE, props.class)}, attrs))
		for i in 0 ..< props.count {
			{h.button(
					a.class(DOT_BASE, i == 0 ? DOT_ACTIVE : ""),
					a.data("oh-carousel-indicator", i),
					a.data("oh-carousel-active", bool_attr(i == 0)),
					a.aria("label", fmt.tprintf("Go to slide %d", i + 1)),
					a.type("button"),
				)}
		}
	}
}
