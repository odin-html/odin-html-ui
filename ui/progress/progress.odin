/* Progress, ported from templui's components/progress/progress.templ -- and
the first component on the authoring model (the checklist in
web/src/ui/README.md): the markup is wrapped in <oh-progress class="block">,
whose behaviour is one custom element in web/src/ui/progress.ts. What the
element reads from this markup is declared in web/src/ui/progress.contract.json
and asserted against the rendered output by progress_test.odin.

A bar, optionally with a label and a percentage above it:

    {progress.progress({value = 40, label = "Uploading", show_value = true})}

It takes no children, so its braces are the void-element kind.

The div with role="progressbar" is the accessible element: role and the three
aria-value* attributes stay on it, and the visible bar inside it is a plain
div whose width progress.ts sets. Which means the *rendered* bar has no width
at all -- the indicator is 0% wide until the element upgrades. That is
upstream's arrangement, and the reason for it is that aria-valuenow is then
the single source of truth: changing that one attribute, from htmx or
anything else, moves the bar, because the element observes it.

So a page with the bundle loaded shows progress; a page without it shows an
empty track. Worth knowing before using this for something that must be
visible without JavaScript -- a server-rendered width would be a deviation this
port does not make, because it would leave two places holding the value.

max defaults to 100 when zero or negative, which is what makes {value = 40}
mean 40%. The percentage shown by show_value is clamped to 0..max; the
aria-valuenow attribute is not, and reports whatever it was given, as upstream
does.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package progress

import "core:fmt"

import "html:html/a"
import "html:html/h"

Size :: enum {
	Default,
	Sm,
	Lg,
}

Variant :: enum {
	Default,
	Success,
	Danger,
	Warning,
}

Props :: struct {
	id:         string,
	class:      string,

	// Zero or negative means 100 -- see max_value.
	max:        int,
	value:      int,
	label:      string,
	show_value: bool,
	size:       Size,
	variant:    Variant,

	// Goes on the bar rather than the track, so a caller can restyle the fill
	// without reaching through the wrapper.
	bar_class:  string,
}

@(private)
ROOT :: "w-full"

@(private)
HEADER :: "flex justify-between items-center mb-1"
@(private)
HEADER_TEXT :: "text-sm font-medium"

@(private)
TRACK :: "w-full overflow-hidden rounded-full bg-secondary"

@(private)
BAR :: "h-full rounded-full transition-all"

@(private)
max_value :: proc(max: int) -> int {
	return max <= 0 ? 100 : max
}

/* Clamped, unlike aria-valuenow: a bar reading "120%" beside a track that
stops at full is worse than the two disagreeing. */
@(private)
percentage :: proc(value, max: int) -> int {
	v := value
	if v < 0 {
		v = 0
	}
	if v > max {
		v = max
	}
	return (v * 100) / max
}

@(private)
size_class :: proc(s: Size) -> string {
	switch s {
	case .Sm:
		return "h-1"
	case .Lg:
		return "h-4"
	case .Default:
		return "h-2.5"
	}
	return "h-2.5"
}

@(private)
variant_class :: proc(v: Variant) -> string {
	switch v {
	case .Success:
		return "bg-green-500"
	case .Danger:
		return "bg-destructive"
	case .Warning:
		return "bg-yellow-500"
	case .Default:
		return "bg-primary"
	}
	return "bg-primary"
}

progress :: proc(props := Props{}, attrs: ..a.Attr) {
	max := max_value(props.max)

	// The wrapper is the element boundary and nothing else: an explicit
	// display utility (an unknown element is display:inline before upgrade),
	// with everything the caller configures on the markup inside, unchanged.
	{h.elem("oh-progress", a.class("block"))
		{h.div(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(ROOT, props.class),
						a.aria("valuemin", "0"),
						a.aria("valuemax", max),
						a.aria("valuenow", props.value),
						a.role("progressbar"),
					},
					attrs,
				),
			)
			if props.label != "" || props.show_value {
				{h.div(a.class(HEADER))
					if props.label != "" {
						{ h.span(a.class(HEADER_TEXT)); h.text(props.label) }
					}

					// The blank line above is load bearing: an element block
					// directly under the close of an if trips -strict-style,
					// which reads it as an else.
					if props.show_value {
						{h.span(a.class(HEADER_TEXT))
							h.text(fmt.tprintf("%d%%", percentage(props.value, max)))
						}
					}
				}
			}

			{h.div(a.class(TRACK))
				// Width lives in the element, not here -- see the file comment.
				{h.div(
						a.data("oh-indicator", true),
						a.class(BAR, size_class(props.size), variant_class(props.variant), props.bar_class),
					)
				}
			}
		}
	}
}
