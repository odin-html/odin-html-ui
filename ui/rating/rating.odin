/* Rating, ported from templui's components/rating/rating.templ -- and onto the
authoring model (the checklist in web/src/ui/README.md): the
markup is wrapped in <oh-rating class="contents">, whose behaviour is one custom
element in web/src/ui/rating.ts. What the element reads from this markup is
declared in web/src/ui/rating.contract.json and asserted against the rendered
output by rating_test.odin.

contents rather than block: the root div below is already the component's box
(flex flex-col items-start gap-1), so a wrapper generating a second box would
put one between the caller's layout and it. The utility is still explicit -- an
unknown element is display:inline otherwise, and only in the pre-upgrade window,
where a rating laid out inline is exactly what it must not be.

Three components: the group, a row, and one symbol in that row.

    {rating.rating({value = 3.5, name = "score", precision = 0.5})
        {rating.group()
            for n in 1 ..= 5 {
                {rating.item({value = n})}
            }
        }
    }

rating() and group() take children; item() does not -- it draws its own two
layers -- so its braces are the void-element kind.

## Two layers per symbol

Each item is the same glyph twice: a dim one underneath, and a filled one in a
box that is `w-0` to start with. A half star is that box widened to 50%, which
is why the fill has to be a clipped copy rather than a second colour --
web/src/ui/rating.ts sets the width, and precision decides what widths are
reachable.

So a rendered page shows every symbol dim: the width is the element's, like
progress's bar. The value is in data-oh-rating-initial-value and in the hidden
input, and rating.ts reads the first to draw and writes the second.

## The hidden input

Written after the caller's children, so it is the last thing inside the group
-- which the ordinary component pairing cannot do, since it closes everything
at once. The deferred half takes what it needs on the return value, the same
way popover's arrow does.

Only written when there is a name to post under. A rating with no name is a
readout, not a field.

## Styles

star and heart are one glyph filled or not. emoji is five different faces, and
the filled one depends on the item's own value -- so a five-emoji row runs
angry, frown, meh, smile, laugh, and the unfilled layer is always a neutral
face. That is upstream's arrangement, and it is why item() takes a value at all
rather than counting its position.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package rating

import "core:fmt"

import "html:html/a"
import "html:html/h"

import "ui:ui/icon"

Style :: enum {
	Star,
	Heart,
	Emoji,
}

Props :: struct {
	id:           string,
	class:        string,
	value:        f64,
	read_only:    bool,

	// Zero or negative means 1 -- see precision_or_default.
	precision:    f64,
	name:         string,
	form:         string,
	only_integer: bool,
}

Group_Props :: struct {
	id:    string,
	class: string,
}

Item_Props :: struct {
	id:    string,
	class: string,

	// This symbol's place in the row, from 1. Also picks the emoji face.
	value: int,
	style: Style,
}

/* What the deferred half needs to write the hidden input. A struct rather than
three returns, so the two halves cannot be wired up in the wrong order. */
@(private)
Hidden :: struct {
	name:  string,
	value: f64,
	form:  string,
}

@(private)
ROOT_BASE :: "flex flex-col items-start gap-1"
@(private)
GROUP_BASE :: "flex flex-row items-center gap-1"

/* One constant per string literal upstream, in upstream's order. */
@(private)
ITEM_POSITION :: "relative"
@(private)
ITEM_TRANSITION :: "transition-opacity"

/* Upstream's comment calls this the default cursor, and it is written even for
a read-only rating -- rating.ts overrides the style on those, so the class is
right only until the element upgrades. Kept as upstream has it. */
@(private)
ITEM_CURSOR :: "cursor-pointer"

@(private)
COLOUR_STAR :: "text-yellow-400"
@(private)
COLOUR_HEART :: "text-destructive"
@(private)
COLOUR_EMOJI :: "text-yellow-500"

@(private)
LAYER_DIM :: "opacity-30"

// w-0 to start with: rating.ts widens it, so an unscripted page shows nothing
// filled.
@(private)
LAYER_FILL :: "absolute inset-0 overflow-hidden w-0"

@(private)
FILL_ICON_CLASS :: "fill-current"

@(private)
DEFAULT_PRECISION :: 1.0

@(private)
precision_or_default :: proc(p: f64) -> f64 {
	return p <= 0 ? DEFAULT_PRECISION : p
}

@(private)
bool_attr :: proc(b: bool) -> string {
	return b ? "true" : "false"
}

@(private)
colour_class :: proc(s: Style) -> string {
	switch s {
	case .Heart:
		return COLOUR_HEART
	case .Emoji:
		return COLOUR_EMOJI
	case .Star:
		return COLOUR_STAR
	}
	return COLOUR_STAR
}

/* Which glyph, and whether it is drawn filled. The emoji face follows the
item's own value; star and heart are one glyph with fill-current added. */
@(private)
rating_icon :: proc(s: Style, filled: bool, value: int) {
	if s == .Emoji {
		if !filled {
			{ icon.icon(.Meh) }
			return
		}
		switch {
		case value <= 1:
			{ icon.icon(.Angry) }
		case value <= 2:
			{ icon.icon(.Frown) }
		case value <= 3:
			{ icon.icon(.Meh) }
		case value <= 4:
			{ icon.icon(.Smile) }
		case:
			{ icon.icon(.Laugh) }
		}
		return
	}

	name: icon.Name = s == .Heart ? .Heart : .Star
	{ icon.icon(name, {class = filled ? FILL_ICON_CLASS : ""}) }
}

/* Returns what the hidden input needs, for the deferred half -- see the file
comment, and popover.content for why a flag rides the return value rather than
package state. */
@(deferred_out = rating_close)
rating :: proc(props := Props{}, attrs: ..a.Attr) -> Hidden {
	/* The wrapper is the element boundary and nothing else: an explicit display
	utility (an unknown element is display:inline before upgrade), with everything
	the caller configures on the markup inside, unchanged. It is opened into the
	same scope as the root, so close_all writes both closing tags at the end of
	the caller's block, innermost first -- after the hidden input below. */
	{h.open_scope()
		{h.elem_open("oh-rating", a.class("contents"))
			{h.div_open(
					..a.join(
						[]a.Attr {
							a.attr_if(props.id != "", a.id(props.id)),
							a.data("oh-rating", "root"),
							a.data("oh-rating-initial-value", fmt.tprintf("%.2f", props.value)),
							a.data("oh-rating-precision", fmt.tprintf("%.2f", precision_or_default(props.precision))),
							a.data("oh-rating-readonly", bool_attr(props.read_only)),
							a.attr_if(props.name != "", a.data("oh-rating-name", props.name)),
							a.data("oh-rating-only-integer", bool_attr(props.only_integer)),
							a.class(ROOT_BASE, props.class),
						},
						attrs,
					),
				)
			}
		}
	}
	return {name = props.name, value = props.value, form = props.form}
}

/* Runs at the end of the caller's block: the symbols are written and the group
is still open, which is where the field belongs -- last, inside. */
@(private)
rating_close :: proc(hidden: Hidden) {
	if hidden.name != "" {
		{h.input(
				a.type("hidden"),
				a.name(hidden.name),
				a.value(fmt.tprintf("%.2f", hidden.value)),
				a.attr_if(hidden.form != "", a.form(hidden.form)),
				a.data("oh-rating", "input"),
			)
		}
	}
	h.close_all()
}

@(deferred_none = h.close_all)
group :: proc(props := Group_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(GROUP_BASE, props.class)}, attrs),
			)
		}
	}
}

item :: proc(props := Item_Props{}, attrs: ..a.Attr) {
	{h.div(
			..a.join(
				[]a.Attr {
					a.attr_if(props.id != "", a.id(props.id)),
					a.data("oh-rating", "item"),
					a.data("oh-rating-value", props.value),
					a.class(ITEM_POSITION, colour_class(props.style), ITEM_TRANSITION, ITEM_CURSOR, props.class),
				},
				attrs,
			),
		)
		{h.div(a.class(LAYER_DIM))
			rating_icon(props.style, false, props.value)
		}

		{h.div(a.class(LAYER_FILL), a.data("oh-rating", "fill"))
			rating_icon(props.style, true, props.value)
		}
	}
}
