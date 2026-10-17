/* Slider, ported from templui's components/slider/slider.templ -- and onto the
authoring model (the checklist in web/src/ui/README.md): the
markup is wrapped in <oh-slider class="contents">, whose behaviour is one custom
element in web/src/ui/slider.ts. What the element reads from this markup is
declared in web/src/ui/slider.contract.json and asserted against the rendered
output by slider_test.odin.

contents rather than block: the root div below is already the component's box
(relative flex items-center w-full), so a wrapper generating a second box would
put one between the caller's layout and it. The utility is still explicit -- an
unknown element is display:inline otherwise, and only in the pre-upgrade window,
where a slider laid out inline is exactly what it must not be.

Three components: a single-value slider, a two-thumb range, and a readout that
tracks either.

    {slider.slider({id = "vol", name = "volume", value = 40})}
    {slider.value({for_ = "vol"})}

    {slider.range({id = "price", name_min = "from", name_max = "to",
                   min_value = 20, max_value = 80})}

None of the three takes children, so their braces are the void-element kind.

## What the server draws, and what the element takes over

Unlike progress, the initial position *is* rendered: the fill's inset and each
thumb's `left` are inline styles computed here, so a slider looks right before
any script runs. web/src/ui/slider.ts then re-computes the same numbers on drag,
on a track click and on an arrow key. The data-tui-slider-init marker is gone
with the document sweep that needed it: a custom element upgrades once by
construction.

The value is posted by a hidden input, which is what makes this a form control
rather than a picture. A range has two of them, named separately.

## value(), and the deviation

The readout is an empty span that slider.ts fills in -- the one thing the server
cannot render, since the number would then live in two places and disagree the
moment the thumb moves. A page without the bundle shows a slider and no number,
upstream included.

It finds its slider by data-oh-slider-value-for, which is the slider's id; a
range wants that id with "-min" or "-max" appended. So a slider being read out
needs an id, and unlike upstream this port will not invent one. A value() with
no for_ renders an error span, as upstream does, and then the empty span
anyway.

The readout is deliberately somewhere else on the page, so it is not inside the
<oh-slider> that writes it: that lookup is the one an element boundary cannot
narrow, as in copybutton and label.

## Division

The position is (value - min) / (max - min), which upstream divides without
looking. A slider whose min equals its max renders NaN% there and lays out
wrong. Here that case gives 0, which at least draws an empty track -- the one
deviation in this file, and only reachable through a slider that cannot be
moved anyway.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package slider

import "core:fmt"

import "html:html/a"
import "html:html/h"

Props :: struct {
	id:       string,
	class:    string,
	name:     string,
	min:      int,

	// Zero means 100, as upstream falls back.
	max:      int,

	// Zero means 1.
	step:     int,
	value:    int,
	disabled: bool,
}

Range_Props :: struct {
	id:        string,
	class:     string,
	name_min:  string,
	name_max:  string,
	min:       int,
	max:       int,
	step:      int,
	min_value: int,

	// Zero means max, so a range with neither set spans the whole track.
	max_value: int,
	disabled:  bool,
}

Value_Props :: struct {
	id:    string,
	class: string,

	/* The slider's id -- with "-min" or "-max" appended for a range. Required:
	it is the only thing tying the readout to the slider. */
	for_:  string,
}

@(private)
ROOT_BASE :: "relative flex items-center w-full select-none"

@(private)
TRACK_BASE :: "relative w-full h-2 rounded-full bg-secondary"

@(private)
FILL_BASE :: "absolute inset-y-0 rounded-full bg-primary pointer-events-none"

/* One constant per string literal upstream, so a diff against it still lines
up. The last two are the two arms of upstream's IfElse. */
@(private)
THUMB_BASE :: "absolute top-1/2 size-4 -translate-x-1/2 -translate-y-1/2 rounded-full bg-primary " + "touch-none"
@(private)
THUMB_FOCUS ::
	"ring-offset-background focus-visible:outline-none focus-visible:ring-2 " +
	"focus-visible:ring-ring focus-visible:ring-offset-2"
@(private)
THUMB_HOVER :: "hover:bg-primary/90"
@(private)
THUMB_DISABLED :: "opacity-50 cursor-not-allowed"
@(private)
THUMB_ENABLED :: "cursor-grab active:cursor-grabbing"

@(private)
VALUE_BASE :: "text-sm text-muted-foreground"

@(private)
ERROR_CLASS :: "text-xs text-destructive"

@(private)
DEFAULT_MAX :: 100
@(private)
DEFAULT_STEP :: 1

@(private)
max_or_default :: proc(max: int) -> int {
	return max == 0 ? DEFAULT_MAX : max
}

@(private)
step_or_default :: proc(step: int) -> int {
	return step == 0 ? DEFAULT_STEP : step
}

/* Where a value sits on the track, 0..100. Upstream divides without checking;
an empty range gives 0 here rather than NaN -- see the file comment. */
@(private)
percent :: proc(value, min, max: int) -> f64 {
	if max == min {
		return 0
	}
	return f64(value - min) / f64(max - min) * 100
}

@(private)
thumb_class :: proc(disabled: bool) -> a.Attr {
	return a.class(THUMB_BASE, THUMB_FOCUS, THUMB_HOVER, disabled ? THUMB_DISABLED : THUMB_ENABLED)
}

/* Taken out of the tab order when disabled, rather than left focusable with
nothing to do. */
@(private)
tabindex_attr :: proc(disabled: bool) -> string {
	return disabled ? "-1" : "0"
}

@(private)
thumb :: proc(value, min, max: int, disabled: bool, label: string) {
	{h.div(
			..a.join(
				[]a.Attr {
					a.data("oh-slider", "thumb"),
					a.role("slider"),
					a.tabindex(tabindex_attr(disabled)),
				},
				[]a.Attr{a.attr_if(label != "", a.aria("label", label))},
				[]a.Attr {
					a.aria("valuemin", min),
					a.aria("valuemax", max),
					a.aria("valuenow", value),
					a.attr_if(disabled, a.aria("disabled", "true")),
					a.style(fmt.tprintf("left:%.2f%%", percent(value, min, max))),
					thumb_class(disabled),
				},
			),
		)
	}
}

@(private)
hidden_input :: proc(name: string, value: int) {
	{h.input(
			a.data("oh-slider", "input"),
			a.type("hidden"),
			a.attr_if(name != "", a.name(name)),
			a.value(value),
		)
	}
}

slider :: proc(props := Props{}, attrs: ..a.Attr) {
	max := max_or_default(props.max)
	step := step_or_default(props.step)

	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged.
	{h.elem("oh-slider", a.class("contents"))
		{h.div(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.data("oh-slider", "root"),
						a.data("oh-slider-min", props.min),
						a.data("oh-slider-max", max),
						a.data("oh-slider-step", step),
						a.class(ROOT_BASE, props.class),
					},
					attrs,
				),
			)
			{h.div(a.data("oh-slider", "track"), a.class(TRACK_BASE))
				{h.div(
						a.data("oh-slider", "fill"),
						a.class(FILL_BASE),
						a.style(
							fmt.tprintf("left:0%%;right:%.2f%%", 100 - percent(props.value, props.min, max)),
						),
					)
				}

				thumb(props.value, props.min, max, props.disabled, "")
			}

			hidden_input(props.name, props.value)
		}
	}
}

/* Two thumbs and two hidden inputs. The fill is inset from both ends rather
than from the left only, which is the whole difference in the markup. */
range :: proc(props := Range_Props{}, attrs: ..a.Attr) {
	max := max_or_default(props.max)
	step := step_or_default(props.step)
	max_value := props.max_value == 0 ? max : props.max_value

	// The wrapper is the element boundary and nothing else -- see slider().
	{h.elem("oh-slider", a.class("contents"))
		{h.div(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.data("oh-slider", "root"),
						a.data("oh-slider-min", props.min),
						a.data("oh-slider-max", max),
						a.data("oh-slider-step", step),
						a.class(ROOT_BASE, props.class),
					},
					attrs,
				),
			)
			{h.div(a.data("oh-slider", "track"), a.class(TRACK_BASE))
				{h.div(
						a.data("oh-slider", "fill"),
						a.class(FILL_BASE),
						a.style(
							fmt.tprintf(
								"left:%.2f%%;right:%.2f%%",
								percent(props.min_value, props.min, max),
								100 - percent(max_value, props.min, max),
							),
						),
					)
				}

				thumb(props.min_value, props.min, max, props.disabled, "Minimum")
				thumb(max_value, props.min, max, props.disabled, "Maximum")
			}

			hidden_input(props.name_min, props.min_value)
			hidden_input(props.name_max, max_value)
		}
	}
}

/* An empty span for slider.ts to write into. Rendering the number here as well
would put the value in two places and leave them to disagree the moment the
thumb moves. No <oh-slider> around it: the readout is not part of any one
slider's markup, which is the whole point of naming one by id. */
value :: proc(props := Value_Props{}, attrs: ..a.Attr) {
	if props.for_ == "" {
		{h.span(a.class(ERROR_CLASS))
			h.text("Error: Value missing 'For' attribute.")
		}
	}

	// The blank line above is load bearing: an element block directly under
	// the close of an if trips -strict-style, which reads it as an else.
	{h.span(
			..a.join(
				[]a.Attr {
					a.attr_if(props.id != "", a.id(props.id)),
					a.data("oh-slider-value", true),
					a.data("oh-slider-value-for", props.for_),
					a.class(VALUE_BASE, props.class),
				},
				attrs,
			),
		)
	}
}
