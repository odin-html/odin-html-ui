/* Tests for dialog, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package dialog

import "core:encoding/json"
import "core:fmt"
import "core:os"
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
CONTENT ::
	"fixed left-[50%] top-[50%] z-50 m-0 w-full max-w-[calc(100%-2rem)] " +
	"-translate-x-1/2 -translate-y-1/2 flex-col gap-4 overflow-hidden border " +
	"bg-background p-6 text-foreground shadow-lg outline-none sm:max-w-lg " +
	"hidden open:flex " +
	"rounded-lg " +
	"backdrop:transition-all backdrop:duration-200 backdrop:bg-black/0 " +
	"open:backdrop:bg-black/50 starting:open:backdrop:bg-black/0 " +
	"transition-all transition-discrete duration-200 " +
	"scale-95 open:scale-100 starting:open:scale-95 " +
	"opacity-0 open:opacity-100 starting:open:opacity-0"

/* Escaped, which is what goes on the wire: the arbitrary variants carry an
`&`. */
@(private = "file")
CLOSE_BUTTON ::
	"absolute top-4 right-4 " +
	"rounded-xs opacity-70 " +
	"transition-opacity hover:opacity-100 " +
	"focus:outline-none focus:ring-2 " +
	"focus:ring-ring focus:ring-offset-2 " +
	"ring-offset-background " +
	"disabled:pointer-events-none " +
	"[&amp;_svg]:pointer-events-none " +
	"[&amp;_svg]:shrink-0 " +
	"[&amp;_svg:not([class*=&#39;size-&#39;])]:size-4"

@(private = "file")
X_ICON :: `<svg viewBox="0 0 24 24" class="icon"><path d="M18 6 6 18" /> <path d="m6 6 12 12" /></svg>`

@(test)
test_dialog_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{dialog({id = "d"})
			{ trigger(); h.text("Open") }
			{content()
				{header()
					{ title(); h.text("T") }
					{ description(); h.text("D") }
				}
			}
		}
	})
	testing.expect(t, strings.has_prefix(out, `<oh-dialog id="d" class="contents">`))
	testing.expect(t, strings.contains(out, `<span data-oh-dialog-trigger class="contents">Open</span>`))
	testing.expect(
		t,
		strings.contains(
			out,
			`<dialog class="` + CONTENT + `" data-oh-dialog-content data-oh-dialog-show-modal="true">`,
		),
	)
	testing.expect(
		t,
		strings.contains(
			out,
			`<div class="flex flex-col gap-2 text-center sm:text-left"><h2 class="text-lg leading-none font-semibold">T</h2><p class="text-muted-foreground text-sm">D</p></div>`,
		),
	)
	testing.expect(t, strings.has_suffix(out, "</dialog></oh-dialog>"))
}

/* The group and the trigger are `contents`: no box, so wrapping a button
leaves it laid out as it was. */
@(test)
test_dialog_root_and_trigger_are_contents :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{dialog()
			{ trigger() }
		}
	})
	testing.expect_value(t, strings.count(out, `class="contents"`), 2)
}

/* The close button follows the caller's children and stays inside the dialog
-- the seam the deferred half exists for. */
@(test)
test_dialog_close_button_follows_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content(); h.text("Body") }
	})
	testing.expect(
		t,
		strings.contains(
			out,
			`>Body<button class="` + CLOSE_BUTTON + `" data-oh-dialog-close aria-label="Close" type="button">`,
		),
	)
	testing.expect(t, strings.contains(out, X_ICON + `<span class="sr-only">Close</span></button></dialog>`))
}

@(test)
test_dialog_hide_close_button :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({hide_close_button = true}); h.text("Body") }
	})
	testing.expect(t, !strings.contains(out, "<button"))
	testing.expect(t, strings.has_suffix(out, ">Body</dialog>"))
}

/* One-shot: the element consumes it at connect, so a re-connect never
re-opens a dialog the user closed -- and the ordinary case writes nothing,
since the CSS reads the native `open` attribute now. */
@(test)
test_dialog_initial_open :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({open = true}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-dialog-initial-open="true"`))

	shut := rendered(t, proc() {
		{ content() }
	})
	testing.expect(t, !strings.contains(shut, "initial-open"))
	testing.expect(t, !strings.contains(shut, "data-oh-dialog-open"))
}

@(test)
test_dialog_show_modal_is_inverted :: proc(t: ^testing.T) {
	modal := rendered(t, proc() {
		{ content() }
	})
	testing.expect(t, strings.contains(modal, `data-oh-dialog-show-modal="true"`))

	plain := rendered(t, proc() {
		{ content({disable_modal = true}) }
	})
	testing.expect(t, strings.contains(plain, `data-oh-dialog-show-modal="false"`))
}

/* Written only when asked for -- absent is the ordinary case for both. */
@(test)
test_dialog_disable_flags :: proc(t: ^testing.T) {
	off := rendered(t, proc() {
		{ dialog() }
	})
	testing.expect(t, !strings.contains(off, "disable-click-away"))
	testing.expect(t, !strings.contains(off, "disable-esc"))

	on := rendered(t, proc() {
		{ dialog({disable_click_away = true, disable_esc = true}) }
	})
	testing.expect(t, strings.contains(on, `data-oh-dialog-disable-click-away="true"`))
	testing.expect(t, strings.contains(on, `data-oh-dialog-disable-esc="true"`))
}

/* for_ is for a trigger or close outside the dialog it acts on; inside, the
element walks up and neither needs it. */
@(test)
test_dialog_external_trigger_and_close :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({for_ = "d"}) }
		{ close({for_ = "d"}) }
	})
	testing.expect_value(t, strings.count(out, `data-oh-dialog-target="d"`), 2)

	inside := rendered(t, proc() {
		{ trigger() }
		{ close() }
	})
	testing.expect(t, !strings.contains(inside, "data-oh-dialog-target"))
}

@(test)
test_dialog_close_is_contents_and_clickable :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ close(); h.text("Cancel") }
	})
	testing.expect_value(t, out, `<span data-oh-dialog-close class="contents cursor-pointer">Cancel</span>`)
}

@(test)
test_dialog_footer_reverses_below_sm :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ footer(); h.text("x") }
	})
	testing.expect_value(t, out, `<div class="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">x</div>`)
}

/* Nesting: an inner dialog's close button and closing tag land in its own
block, leaving the outer one's alone. */
@(test)
test_dialog_nested_closes_only_itself :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{content()
			{ content({hide_close_button = true}); h.text("inner") }
			h.text("after")
		}
	})
	testing.expect(t, strings.contains(out, "inner</dialog>after<button"))
	testing.expect(t, strings.has_suffix(out, "</button></dialog>"))
}

@(test)
test_dialog_ids_classes_and_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{dialog({id = "d", class = "block"}, a.data("testid", "d"))
			{ trigger({id = "d-t"}, hx.get("/d")) }
			{ content({class = "sm:max-w-2xl"}) }
		}
	})
	testing.expect(t, strings.has_prefix(out, `<oh-dialog id="d" class="contents block" data-testid="d">`))
	testing.expect(t, strings.contains(out, `<span id="d-t" data-oh-dialog-trigger`))
	testing.expect(t, strings.contains(out, `hx-get="/d">`))
	testing.expect(t, strings.contains(out, CONTENT + ` sm:max-w-2xl"`))
}

/* The structural contract (README.md, "The contract test"): dialog.ts declares in
dialog.contract.json everything it reads from this component's markup, and
this test asserts the rendered markup carries all of it. */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/dialog.contract.json"

@(private = "file")
selector_attr :: proc(selector: string) -> string {
	return strings.trim(selector, "[]")
}

@(private = "file")
wrapper_class_has :: proc(open_tag, token: string) -> bool {
	marker := ` class="`
	start := strings.index(open_tag, marker)
	if start < 0 {
		return false
	}
	rest := open_tag[start + len(marker):]
	end := strings.index_byte(rest, '"')
	if end < 0 {
		return false
	}
	tokens := strings.split(rest[:end], " ", context.temp_allocator)
	for tok in tokens {
		if tok == token {
			return true
		}
	}
	return false
}

@(test)
test_dialog_contract :: proc(t: ^testing.T) {
	data, read_err := os.read_entire_file(CONTRACT_PATH, context.temp_allocator)
	testing.expectf(t, read_err == nil, "contract manifest unreadable: %s (%v)", CONTRACT_PATH, read_err)
	if read_err != nil {
		return
	}

	contract: Contract
	err := json.unmarshal(data, &contract, allocator = context.temp_allocator)
	testing.expectf(t, err == nil, "contract manifest unparsable: %v", err)
	if err != nil {
		return
	}

	// Every knob the element reads, in one render.
	out := rendered(t, proc() {
		{dialog({id = "d", disable_click_away = true, disable_esc = true})
			{ trigger({for_ = "d"}); h.text("Open") }
			{ content({open = true}); h.text("Body") }
		}
	})

	tag_end := strings.index_byte(out, '>')
	testing.expect(t, tag_end > 0)
	open_tag := out[:tag_end]
	testing.expectf(
		t,
		strings.has_prefix(open_tag, fmt.tprintf("<%s", contract.element)),
		"wrapper is not <%s>: %s",
		contract.element,
		open_tag,
	)
	testing.expectf(
		t,
		wrapper_class_has(open_tag, contract.display),
		"wrapper class carries no %q display utility: %s",
		contract.display,
		open_tag,
	)

	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
	for _, name in contract.attributes {
		testing.expectf(t, strings.contains(out, name), "markup lacks %s", name)
	}
}
