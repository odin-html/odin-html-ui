/* Avatar, ported from templui's components/avatar/avatar.templ -- and onto the
authoring model (the checklist in web/src/ui/README.md): the
markup is wrapped in <oh-avatar class="contents">, whose behaviour is one custom
element in web/src/ui/avatar.ts. What the element reads from this markup is
declared in web/src/ui/avatar.contract.json and asserted against the rendered
output by avatar_test.odin.

contents rather than block, like input and unlike progress: the frame below is
already the component's box -- `relative flex h-10 w-10`, and the caller's flex
or grid item -- so a wrapper generating a second box would change the layout of
every avatar that was laid out before the port. The utility is still explicit --
an unknown element is display:inline otherwise, and only in the pre-upgrade
window.

Three components: the frame, an image, and a fallback shown when the image is
not there.

    {avatar.avatar()
        {avatar.image({src = u.photo, alt = u.name})}
        {avatar.fallback(); h.text(initials(u.name))}
    }

Both are written, always, and both are visible until the element decides
otherwise. web/src/ui/avatar.ts listens for the image's load and error events
and hides one or the other -- so with JavaScript off, or before the image
resolves, an avatar shows the fallback behind a transparent gap rather than
nothing at all. The frame is `relative` and the image fills it, so they stack
rather than sit side by side.

That ordering matters at the call site: the image comes first, the fallback
second, because the fallback is what a broken image falls back *to* and the
element hides whichever lost. Writing only a fallback is fine and is how a
user with no photo is drawn.

The wrapper goes on the frame alone. image() and fallback() are the frame's
children and are found by their data-oh-* roles from inside it, so neither
carries an element of its own -- and either can still be written outside an
avatar(), where nothing looks for them.

avatar() and fallback() take children; image() is void and takes none -- so its
braces are the {h.img()} kind, marking the element's extent and closing
nothing.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package avatar

import "html:html/a"
import "html:html/h"

Props :: struct {
	id:    string,
	class: string,
}

Image_Props :: struct {
	id:    string,
	class: string,
	alt:   string,
	src:   string,
}

Fallback_Props :: struct {
	id:    string,
	class: string,
}

/* One constant per string literal upstream, so a diff against it still lines
up. */
@(private)
AVATAR_BASE :: "relative flex h-10 w-10 shrink-0 overflow-hidden rounded-full"
@(private)
IMAGE_BASE :: "aspect-square h-full w-full"
@(private)
FALLBACK_BASE :: "flex h-full w-full items-center justify-center rounded-full bg-muted"

/* h-10 w-10 is a default rather than a rule: a caller's class lands after it,
and `size-16` in a class overrides both. */
@(deferred_none = h.close_all)
avatar :: proc(props := Props{}, attrs: ..a.Attr) {
	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged. It is
	// opened into the same scope as the frame, so close_all writes both closing
	// tags at the end of the caller's block, innermost first.
	{h.open_scope()
		{h.elem_open("oh-avatar", a.class("contents"))
			{h.div_open(
					..a.join(
						[]a.Attr {
							a.data("oh-avatar", true),
							a.attr_if(props.id != "", a.id(props.id)),
							a.class(AVATAR_BASE, props.class),
						},
						attrs,
					),
				)
			}
		}
	}
}

/* alt is written even when empty, as upstream writes it. An <img> with no alt
at all is announced by its filename; alt="" says "decorative, skip me", which
is the right reading for an avatar sitting next to the name it belongs to. */
image :: proc(props := Image_Props{}, attrs: ..a.Attr) {
	{h.img(
			..a.join(
				[]a.Attr {
					a.data("oh-avatar-image", true),
					a.attr_if(props.id != "", a.id(props.id)),
					a.attr_if(props.src != "", a.src(props.src)),
					a.alt(props.alt),
					a.class(IMAGE_BASE, props.class),
				},
				attrs,
			),
		)
	}
}

@(deferred_none = h.close_all)
fallback :: proc(props := Fallback_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.span_open(
				..a.join(
					[]a.Attr {
						a.data("oh-avatar-fallback", true),
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(FALLBACK_BASE, props.class),
					},
					attrs,
				),
			)
		}
	}
}
