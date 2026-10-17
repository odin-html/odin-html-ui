/* Tests for form, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package form

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

/* label's, restated: form.label renders label's element -- wrapper included,
since the wrapper is opened in label_open -- and what a caller sees is the whole
attribute. */
@(private = "file")
LBL :: "text-sm font-medium leading-none inline-block"
@(private = "file")
OPEN :: `<oh-label class="contents">`
@(private = "file")
CLOSE :: `</oh-label>`
@(private = "file")
DIS :: ` data-oh-label-disabled-style="opacity-50 cursor-not-allowed"`

@(test)
test_form_field :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{item()
			{ label({for_ = "email"}); h.text("Email") }
			{ description(); h.text("Hint") }
			{ message({variant = .Error}); h.text("Bad") }
		}
	})
	testing.expect_value(
		t,
		out,
		`<div class="space-y-2">` +
		OPEN +
		`<label for="email" class="` +
		LBL +
		`"` +
		DIS +
		`>Email</label>` +
		CLOSE +
		`<p class="text-sm text-muted-foreground">Hint</p>` +
		`<p class="text-[0.8rem] font-medium text-red-500">Bad</p></div>`,
	)
}

/* The two item shapes: stacked, and on one line for a control beside its
caption. */
@(test)
test_form_item_shapes :: proc(t: ^testing.T) {
	stacked := rendered(t, proc() {
			{ item(); h.text("x") }
		})
	testing.expect_value(t, stacked, `<div class="space-y-2">x</div>`)

	row := rendered(t, proc() {
		{ item_flex(); h.text("x") }
	})
	testing.expect_value(t, row, `<div class="items-center flex space-x-2">x</div>`)
}

@(test)
test_form_message_variants :: proc(t: ^testing.T) {
	testing.expect_value(t, message_variant_class(.None), "")
	testing.expect_value(t, message_variant_class(.Error), "text-red-500")
	testing.expect_value(t, message_variant_class(.Info), "text-blue-500")
}

/* The zero variant adds no colour at all, which is upstream's default branch --
so a message with no variant inherits whatever is around it. */
@(test)
test_form_message_default_has_no_colour :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ message(); h.text("x") }
	})
	testing.expect_value(t, out, `<p class="text-[0.8rem] font-medium">x</p>`)
}

/* form.label is label with the error prop dropped: within a form the error is
a message() below, and colouring the caption too would say it twice. */
@(test)
test_form_label_is_label_without_error :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ label({id = "l", for_ = "e", class = "mb-1"}); h.text("Email") }
	})
	testing.expect_value(
		t,
		out,
		OPEN + `<label id="l" for="e" class="` + LBL + ` mb-1"` + DIS + `>Email</label>` + CLOSE,
	)
	testing.expect(t, !strings.contains(out, "text-destructive"))
}

/* The close lands in the caller's block, so what follows a label inside an
item is a sibling of the label rather than part of it. */
@(test)
test_form_label_closes_in_the_callers_block :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{item()
			{ label(); h.text("Email") }
			h.text("after")
		}
	})
	testing.expect(t, strings.contains(out, "Email</label>" + CLOSE + "after</div>"))
}

@(test)
test_form_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{item({id = "i", class = "pt-4"})
			{ description({id = "d", class = "italic"}); h.text("H") }
			{message({id = "m", variant = .Info, class = "mt-1"})
				h.text("M")}
		}
	})
	testing.expect(t, strings.has_prefix(out, `<div id="i" class="space-y-2 pt-4">`))
	testing.expect(t, strings.contains(out, `<p id="d" class="text-sm text-muted-foreground italic">H</p>`))
	testing.expect(t, strings.contains(out, `<p id="m" class="text-[0.8rem] font-medium text-blue-500 mt-1">M</p>`))
}

@(test)
test_form_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{item({}, hx.get("/f"), a.data("testid", "i"))
			{ label({}, a.data("testid", "l")); h.text("E") }
		}
	})
	testing.expect(t, strings.has_prefix(out, `<div class="space-y-2" hx-get="/f" data-testid="i">`))
	testing.expect(t, strings.contains(out, DIS + ` data-testid="l">E</label>` + CLOSE))
}
