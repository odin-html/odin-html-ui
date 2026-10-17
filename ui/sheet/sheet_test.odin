/* Tests for sheet, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced.

dialog's classes are restated here too: a sheet is dialog's markup with more
classes appended, and what a caller sees is the whole attribute. */
package sheet

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

@(private = "file")
BASE ::
	"fixed z-50 flex flex-col bg-background shadow-lg " +
	"!transition-[transform,display,overlay] transition-discrete ease-in-out " +
	"duration-300 open:duration-500"

@(private = "file")
OVERRIDES :: "!p-0 !scale-100 !rounded-none !opacity-100"

/* Every part of it is dialog's element -- there is no markup of sheet's own,
which is why there is no sheet.ts either. */
@(test)
test_sheet_is_dialog_markup :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{sheet({id = "s"})
			{ trigger(); h.text("Open") }
			{content()
				{header()
					{ title(); h.text("T") }
					{ description(); h.text("D") }
				}
				{footer()
					{ close(); h.text("Apply") }
				}
			}
		}
	})
	testing.expect(t, strings.has_prefix(out, `<oh-dialog id="s" class="contents"`))
	testing.expect(t, strings.contains(out, "<span data-oh-dialog-trigger"))
	testing.expect(t, strings.contains(out, "<dialog class="))
	testing.expect(t, strings.contains(out, "data-oh-dialog-content"))
	testing.expect(t, strings.contains(out, "<span data-oh-dialog-close"))
	testing.expect(t, strings.has_suffix(out, "</dialog></oh-dialog>"))
}

/* The sheet attributes ride alongside dialog's, on both the root and the
content. */
@(test)
test_sheet_marks_itself :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{sheet({side = .Bottom})
			{ content({side = .Bottom}) }
		}
	})
	testing.expect(t, strings.contains(out, `data-oh-sheet="true" data-oh-sheet-side="bottom"`))
	testing.expect(t, strings.contains(out, `data-oh-sheet-content="true" data-oh-sheet-side="bottom"`))
}

@(test)
test_sheet_side_names :: proc(t: ^testing.T) {
	testing.expect_value(t, side_attr(.Right), "right")
	testing.expect_value(t, side_attr(.Left), "left")
	testing.expect_value(t, side_attr(.Top), "top")
	testing.expect_value(t, side_attr(.Bottom), "bottom")
}

/* Right is the zero value, as upstream falls back to. */
@(test)
test_sheet_default_side_is_right :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{sheet()
			{ content() }
		}
	})
	testing.expect_value(t, strings.count(out, `data-oh-sheet-side="right"`), 2)
	testing.expect(t, strings.contains(out, "!translate-x-full open:!translate-x-0"))
}

/* Each side slides from its own edge -- off-screen at rest and in
@starting-style, home while open -- and each resets dialog's centring on the
other axis first: without the reset a sheet would sit half a viewport off. */
@(test)
test_sheet_side_classes :: proc(t: ^testing.T) {
	testing.expect(t, strings.contains(side_classes(.Right), "!translate-x-full open:!translate-x-0"))
	testing.expect(t, strings.contains(side_classes(.Right), "starting:open:!translate-x-full"))
	testing.expect(t, strings.contains(side_classes(.Left), "!-translate-x-full open:!translate-x-0"))
	testing.expect(t, strings.contains(side_classes(.Top), "!-translate-y-full open:!translate-y-0"))
	testing.expect(t, strings.contains(side_classes(.Bottom), "!translate-y-full open:!translate-y-0"))

	testing.expect(t, strings.contains(side_classes(.Right), "!translate-y-0"))
	testing.expect(t, strings.contains(side_classes(.Left), "!translate-y-0"))
	testing.expect(t, strings.contains(side_classes(.Top), "!translate-x-0"))
	testing.expect(t, strings.contains(side_classes(.Bottom), "!translate-x-0"))
}

/* The base and the side and the overrides, in that order, appended after
dialog's own list -- so the `!` utilities are what make the sheet win. */
@(test)
test_sheet_content_class_order :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({side = .Top, class = "max-h-1/2"}) }
	})
	// side_classes returns at runtime, so the expectation is built rather than
	// folded -- Odin's `+` on strings is constant-only.
	want := strings.concatenate({BASE, " ", side_classes(.Top), " ", OVERRIDES, ` max-h-1/2"`}, context.temp_allocator)
	testing.expect(t, strings.contains(out, want))

	// dialog's own classes are still there, ahead of them.
	testing.expect(t, strings.contains(out, "p-6"))
	testing.expect(t, strings.contains(out, "rounded-lg"))
}

/* The overrides are `!` because dialog's own utilities remain in the list
beside them -- including dialog's open: and starting: state rules, which the
unconditional `!` outranks. */
@(test)
test_sheet_overrides_are_important :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content() }
	})
	for s in ([]string{"!p-0", "!scale-100", "!rounded-none", "!opacity-100"}) {
		testing.expect(t, strings.contains(out, s), s)
	}
}

/* The caveat this port carries: header, title and footer have no `!`, so both
sets of utilities reach the element and the stylesheet decides. This pins the
markup rather than the outcome. */
@(test)
test_sheet_header_keeps_both_class_sets :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ header(); h.text("x") }
	})
	testing.expect(t, strings.contains(out, "flex flex-col gap-2 text-center sm:text-left gap-1.5 p-4 text-left"))
}

@(test)
test_sheet_title_and_footer :: proc(t: ^testing.T) {
	title_out := rendered(t, proc() {
		{ title(); h.text("T") }
	})
	testing.expect(
		t,
		strings.contains(title_out, `<h2 class="text-lg leading-none font-semibold text-base leading-normal">T</h2>`),
	)

	footer_out := rendered(t, proc() {
			{ footer(); h.text("F") }
		})
	testing.expect(t, strings.contains(footer_out, "sm:justify-end mt-auto flex flex-col gap-2 p-4"))
}

/* description adds nothing of its own -- the only one of the eight that is
dialog's unchanged. */
@(test)
test_sheet_description_is_dialogs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ description(); h.text("D") }
	})
	testing.expect_value(t, out, `<p class="text-muted-foreground text-sm">D</p>`)
}

/* The close button is dialog's, written after the caller's children. */
@(test)
test_sheet_close_button :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content(); h.text("Body") }
	})
	testing.expect(t, strings.contains(out, `>Body<button `))
	testing.expect(t, strings.contains(out, `data-oh-dialog-close aria-label="Close"`))

	hidden := rendered(t, proc() {
		{ content({hide_close_button = true}); h.text("Body") }
	})
	testing.expect(t, !strings.contains(hidden, "<button"))
	testing.expect(t, strings.has_suffix(hidden, ">Body</dialog>"))
}

/* open is dialog's one-shot initial-open now; the root carries no state. */
@(test)
test_sheet_initial_open :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{sheet()
			{ content({open = true}) }
		}
	})
	testing.expect(t, strings.contains(out, `data-oh-dialog-initial-open="true"`))

	shut := rendered(t, proc() {
		{sheet()
			{ content() }
		}
	})
	testing.expect(t, !strings.contains(shut, "initial-open"))
}

@(test)
test_sheet_disable_flags_reach_dialog :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ sheet({disable_click_away = true, disable_esc = true}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-dialog-disable-click-away="true"`))
	testing.expect(t, strings.contains(out, `data-oh-dialog-disable-esc="true"`))
}

@(test)
test_sheet_external_trigger_and_close :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({for_ = "s"}) }
		{ close({for_ = "s"}) }
	})
	testing.expect_value(t, strings.count(out, `data-oh-dialog-target="s"`), 2)
}

@(test)
test_sheet_ids_and_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{sheet({id = "s", class = "block"}, a.data("testid", "s"))
			{ trigger({id = "s-t"}, hx.get("/s")) }
		}
	})
	testing.expect(
		t,
		strings.contains(
			out,
			`class="contents block" data-oh-sheet="true" data-oh-sheet-side="right" data-testid="s">`,
		),
	)
	testing.expect(t, strings.contains(out, `<span id="s-t" data-oh-dialog-trigger`))
	testing.expect(t, strings.contains(out, `hx-get="/s">`))
}
