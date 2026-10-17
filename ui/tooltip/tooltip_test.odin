/* Tests for tooltip, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced.

popover's own class list is restated here too, because what a caller sees is
the whole attribute and the order of the two halves is the thing this component
decides. */
package tooltip

import "core:strings"
import "core:testing"

import "html:html/a"
import "html:html/h"
import "html:html/hx"

import "ui:ui/popover"

@(private = "file")
rendered :: proc(t: ^testing.T, body: proc()) -> string {
	out, err := h.render_to_string(body, context.temp_allocator)
	testing.expect_value(t, err, nil)
	return out
}

/* Escaped, which is what goes on the wire: the arbitrary variants carry an
`&`. Top placement, tooltip's default. */
@(private = "file")
POPOVER_CLASS ::
	"bg-popover rounded-lg border text-popover-foreground text-sm shadow-lg " +
	"pointer-events-auto fixed inset-auto m-0 " +
	"[position-try-fallbacks:flip-block,flip-inline] " +
	"[position-area:top] " +
	"max-w-[min(24rem,calc(100vw-2rem))] overflow-visible outline-none " +
	"opacity-0 [&amp;:popover-open]:opacity-100 [&amp;:popover-open]:starting:opacity-0 " +
	"transition-[opacity,display,overlay] transition-discrete duration-150 ease-out " +
	"motion-reduce:transition-none"

@(private = "file")
TOOLTIP_CLASS ::
	"px-4 py-1 bg-foreground text-background " +
	"[&amp;_[data-oh-popover-arrow]]:!bg-foreground " +
	"[&amp;_[data-oh-popover-arrow]]:!border-0"

/* A tooltip is a popover throughout: root, trigger and content are popover's
elements with some props decided -- and the trigger is an interest invoker
naming the content by id. */
@(test)
test_tooltip_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{tooltip()
			{ trigger({for_ = "tip"}); h.text("?") }
			{ content({id = "tip"}); h.text("Tip") }
		}
	})
	testing.expect(t, strings.has_prefix(out, `<oh-popover class="contents">`))
	testing.expect(
		t,
		strings.contains(
			out,
			`<span class="contents" ` +
			`data-oh-popover-trigger data-oh-popover-type="manual" interestfor="tip" ` +
			`style="interest-delay-start:0ms;interest-delay-end:0ms">?</span>`,
		),
	)
	testing.expect(t, strings.contains(out, `<div id="tip" popover="hint"`))
	testing.expect(t, strings.contains(out, `<div class="w-full overflow-hidden">Tip</div>`))
	testing.expect(t, strings.has_suffix(out, "</div></oh-popover>"))
}

/* The trigger type is manual: the invoker drives the content, and a click on
it must not toggle anything. */
@(test)
test_tooltip_trigger_is_manual_invoker :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({for_ = "tip"}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-popover-type="manual"`))
	testing.expect(t, strings.contains(out, `interestfor="tip"`))
	testing.expect(t, !strings.contains(out, `"click"`))
}

/* interestfor is an idref, so a tooltip without its pair of ids is loud. */
@(test)
test_tooltip_requires_ids :: proc(t: ^testing.T) {
	no_for := rendered(t, proc() {
		{ trigger(); h.text("?") }
	})
	testing.expect(t, strings.contains(no_for, "missing required 'for_' attribute"))
	testing.expect(t, !strings.contains(no_for, "interestfor"))

	no_id := rendered(t, proc() {
		{ content(); h.text("Tip") }
	})
	testing.expect(t, strings.contains(no_id, "missing required 'ID' attribute"))
}

/* popover's classes first, then the tooltip's, then the caller's -- the order
is the whole of the precedence, there being no TwMerge. */
@(test)
test_tooltip_content_class_order :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({id = "tip", class = "max-w-xs"}) }
	})
	testing.expect(t, strings.contains(out, `class="` + POPOVER_CLASS + " " + TOOLTIP_CLASS + ` max-w-xs"`))
}

/* Hover content is popover="hint": where the browser has it, a tooltip does
not dismiss an open auto popover; where it does not, the invalid value falls
back to manual state and the shim drives it either way. */
@(test)
test_tooltip_content_is_hint :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({id = "tip"}) }
	})
	testing.expect(t, strings.contains(out, `popover="hint"`))
}

/* The two `!` rules reach into popover's arrow. Without them a dark tooltip
would carry a light triangle, the arrow being drawn with the popover's own
background. */
@(test)
test_tooltip_content_recolours_the_arrow :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({id = "tip", show_arrow = true}) }
	})
	testing.expect(t, strings.contains(out, "[&amp;_[data-oh-popover-arrow]]:!bg-foreground"))
	testing.expect(t, strings.contains(out, "[&amp;_[data-oh-popover-arrow]]:!border-0"))
	testing.expect(t, strings.contains(out, "data-oh-popover-arrow class="))
}

/* Top by default, where popover's own default is bottom: a tooltip goes above
the thing it describes. The placement is a position-area utility and the
offset margin sits on the anchor-facing side. */
@(test)
test_tooltip_position :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({id = "tip"}) }
	})
	testing.expect(t, strings.contains(out, "[position-area:top]"))
	testing.expect(t, strings.contains(out, `style="margin-bottom:4px"`))

	right := rendered(t, proc() {
		{ content({id = "tip", position = .Right}) }
	})
	testing.expect(t, strings.contains(right, "[position-area:right]"))
	testing.expect(t, strings.contains(right, `style="margin-left:4px"`))

	bottom := rendered(t, proc() {
		{ content({id = "tip", position = .Bottom}) }
	})
	testing.expect(t, strings.contains(bottom, "[position-area:bottom]"))

	left := rendered(t, proc() {
		{ content({id = "tip", position = .Left}) }
	})
	testing.expect(t, strings.contains(left, "[position-area:left]"))
}

/* Four sides, no -start/-end: a tooltip is centred on its trigger. */
@(test)
test_tooltip_placement_mapping :: proc(t: ^testing.T) {
	testing.expect_value(t, placement(.Top), popover.Placement.Top)
	testing.expect_value(t, placement(.Right), popover.Placement.Right)
	testing.expect_value(t, placement(.Bottom), popover.Placement.Bottom)
	testing.expect_value(t, placement(.Left), popover.Placement.Left)
}

/* No delay by default -- the tooltip appears as the pointer arrives. That is
the difference from hovercard, which waits. The delays are the invoker's
interest-delay style now. */
@(test)
test_tooltip_delays :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({for_ = "tip"}) }
	})
	testing.expect(t, strings.contains(out, `style="interest-delay-start:0ms;interest-delay-end:0ms"`))

	slow := rendered(t, proc() {
		{ trigger({for_ = "tip", delay = 200, end_delay = 400}) }
	})
	testing.expect(t, strings.contains(slow, `style="interest-delay-start:200ms;interest-delay-end:400ms"`))
}

/* Each component closes back to its own mark, so a tooltip nested in one
sibling does not drag the next one's closing tag with it. */
@(test)
test_tooltip_closes_only_itself :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{tooltip()
			{ trigger({for_ = "tip"}); h.text("?") }
			h.text("between")
			{ content({id = "tip"}); h.text("Tip") }
		}
		h.text("after")
	})
	testing.expect(t, strings.contains(out, "</span>between<div"))
	testing.expect(t, strings.has_suffix(out, "</div></oh-popover>after"))
}

@(test)
test_tooltip_ids_and_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{tooltip({id = "tt", class = "block"}, a.data("testid", "tt"))
			{ trigger({id = "tt-t", for_ = "tt-c"}, hx.get("/t")) }
			{ content({id = "tt-c"}) }
		}
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-popover id="tt" class="contents block" data-testid="tt">`,
		),
	)
	testing.expect(t, strings.contains(out, `<span id="tt-t" class="contents`))
	testing.expect(t, strings.contains(out, `hx-get="/t">`))
	testing.expect(t, strings.contains(out, `<div id="tt-c" popover="hint"`))
}
