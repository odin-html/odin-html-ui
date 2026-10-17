/* Tests for hovercard, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package hovercard

import "core:strings"
import "core:testing"

import "html:html/a"
import "html:html/h"
import "html:html/hx"

@(private = "file")
rendered :: proc(t: ^testing.T, body: proc()) -> string {
	out, err := h.render_to_string(body, context.temp_allocator)
	testing.expect_value(t, err, nil)
	return out
}

/* Escaped, which is what goes on the wire: the arbitrary variants carry an
`&`. Bottom placement, popover's zero value. */
@(private = "file")
POPOVER_CLASS ::
	"bg-popover rounded-lg border text-popover-foreground text-sm shadow-lg " +
	"pointer-events-auto fixed inset-auto m-0 " +
	"[position-try-fallbacks:flip-block,flip-inline] " +
	"[position-area:bottom] " +
	"max-w-[min(24rem,calc(100vw-2rem))] overflow-visible outline-none " +
	"opacity-0 [&amp;:popover-open]:opacity-100 [&amp;:popover-open]:starting:opacity-0 " +
	"transition-[opacity,display,overlay] transition-discrete duration-150 ease-out " +
	"motion-reduce:transition-none"

@(test)
test_hovercard_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{root()
			{ trigger({for_ = "hc"}); h.text("@ada") }
			{ content({id = "hc"}); h.text("Card") }
		}
	})
	testing.expect(t, strings.has_prefix(out, `<oh-popover class="contents">`))
	testing.expect(
		t,
		strings.contains(
			out,
			`data-oh-popover-trigger data-oh-popover-type="manual" interestfor="hc" ` +
			`style="interest-delay-start:150ms;interest-delay-end:300ms">@ada</span>`,
		),
	)
	testing.expect(t, strings.contains(out, `<div id="hc" popover="hint"`))
	testing.expect(t, strings.contains(out, `<div class="w-full overflow-hidden">Card</div>`))
	testing.expect(t, strings.has_suffix(out, "</div></oh-popover>"))
}

/* The three defaults are what makes this a hover card rather than a bare
popover: room for content, and delays long enough that brushing past does not
open it -- the delays riding the invoker as interest-delay style. */
@(test)
test_hovercard_defaults :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({id = "hc"}) }
	})
	testing.expect(t, strings.contains(out, `class="` + POPOVER_CLASS + ` w-64 p-4"`))

	trig := rendered(t, proc() {
		{ trigger({for_ = "hc"}) }
	})
	testing.expect(t, strings.contains(trig, `style="interest-delay-start:150ms;interest-delay-end:300ms"`))
}

/* Zero means unset for both delays, so an instant hover card is not
expressible -- which is upstream's hole too, and the delays are the point of
the component. */
@(test)
test_hovercard_delays_override :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({for_ = "hc", open_delay = 50, close_delay = 100}) }
	})
	testing.expect(t, strings.contains(out, `style="interest-delay-start:50ms;interest-delay-end:100ms"`))
}

/* The trigger is a manual-typed interest invoker, like tooltip's: a
click-opened card is a popover. */
@(test)
test_hovercard_trigger_is_invoker :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({for_ = "hc"}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-popover-type="manual"`))
	testing.expect(t, strings.contains(out, `interestfor="hc"`))
}

/* interestfor is an idref, so a hover card without its pair of ids is loud. */
@(test)
test_hovercard_requires_ids :: proc(t: ^testing.T) {
	no_for := rendered(t, proc() {
		{ trigger(); h.text("@ada") }
	})
	testing.expect(t, strings.contains(no_for, "missing required 'for_' attribute"))
	testing.expect(t, !strings.contains(no_for, "interestfor"))

	no_id := rendered(t, proc() {
		{ content(); h.text("Card") }
	})
	testing.expect(t, strings.contains(no_id, "missing required 'ID' attribute"))
}

/* Placement is popover's own enum, aliased -- so all twelve reach through,
unlike tooltip's four. */
@(test)
test_hovercard_placement_is_popovers :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({id = "hc", placement = .Right_Start}) }
	})
	testing.expect(t, strings.contains(out, "[position-area:right_span-bottom]"))
	testing.expect(t, strings.contains(out, `style="margin-left:4px"`))
}

@(test)
test_hovercard_offset_and_arrow :: proc(t: ^testing.T) {
	plain := rendered(t, proc() {
		{ content({id = "hc"}) }
	})
	testing.expect(t, strings.contains(plain, `style="margin-top:4px"`))
	testing.expect(t, !strings.contains(plain, "data-oh-popover-arrow"))

	arrow := rendered(t, proc() {
		{ content({id = "hc", show_arrow = true}) }
	})
	testing.expect(t, strings.contains(arrow, `style="margin-top:8px"`))
	testing.expect(t, strings.contains(arrow, "data-oh-popover-arrow class="))

	fixed := rendered(t, proc() {
		{ content({id = "hc", offset = 20}) }
	})
	testing.expect(t, strings.contains(fixed, `style="margin-top:20px"`))
}

/* The arrow follows the caller's children and stays inside the content box --
the same seam popover's own test pins, reached through this wrapper. */
@(test)
test_hovercard_arrow_follows_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({id = "hc", show_arrow = true}); h.text("Card") }
	})
	testing.expect(t, strings.contains(out, `Card</div><div data-oh-popover-arrow`))
	testing.expect(t, strings.has_suffix(out, "</div></div>"))
}

@(test)
test_hovercard_ids_and_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{root({id = "hc", class = "block"}, a.data("testid", "hc"))
			{ trigger({id = "hc-t", for_ = "hc-c"}, hx.get("/u")) }
			{ content({id = "hc-c", class = "w-80"}) }
		}
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-popover id="hc" class="contents block" data-testid="hc">`,
		),
	)
	testing.expect(t, strings.contains(out, `<span id="hc-t" class="contents`))
	testing.expect(t, strings.contains(out, `hx-get="/u">`))
	testing.expect(t, strings.contains(out, `w-64 p-4 w-80"`))
}
