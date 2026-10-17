/* Tests for card, in the package and beside the component -- see
button/button_test.odin for why the class strings are restated rather than
referenced. */
package card

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
CD_CARD :: "w-full rounded-lg border bg-card text-card-foreground shadow-xs"
@(private = "file")
CD_HEADER :: "flex flex-col space-y-1.5 p-6 pb-0"
@(private = "file")
CD_TITLE :: "text-lg font-semibold leading-none tracking-tight"
@(private = "file")
CD_DESC :: "text-sm text-muted-foreground"
@(private = "file")
CD_CONTENT :: "p-6"
@(private = "file")
CD_FOOTER :: "flex items-center p-6 pt-0"

/* The whole card in one expectation, so the nesting and the tags are pinned
together -- six components, each handing an element to the next block down. */
@(test)
test_card_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{card()
			{header()
				{ title(); h.text("Bearing 6203") }
				{ description(); h.text("Last serviced in March") }
			}
			{content()
				h.text("Running warm.")
			}
			{footer()
				h.text("Open")
			}
		}
	})
	testing.expect_value(
		t,
		out,
		`<div class="` +
		CD_CARD +
		`">` +
		`<div class="` +
		CD_HEADER +
		`">` +
		`<h3 class="` +
		CD_TITLE +
		`">Bearing 6203</h3>` +
		`<p class="` +
		CD_DESC +
		`">Last serviced in March</p>` +
		`</div>` +
		`<div class="` +
		CD_CONTENT +
		`">Running warm.</div>` +
		`<div class="` +
		CD_FOOTER +
		`">Open</div>` +
		`</div>`,
	)
}

/* The padding is split across three components rather than owned by the card:
the header does not pad its bottom and the footer does not pad its top, so they
meet the body's padding rather than doubling it. Pinned because it is the one
thing that makes the parts look like one card. */
@(test)
test_card_padding_is_split_across_the_parts :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ header(); h.text("h") }
			{ content(); h.text("c") }
			{ footer(); h.text("f") }
		})
	testing.expect(t, strings.contains(out, "p-6 pb-0"))
	testing.expect(t, strings.contains(out, `class="p-6"`))
	testing.expect(t, strings.contains(out, "p-6 pt-0"))
}

/* Each part stands alone: nothing requires a card around it, and the card does
not check what it holds. Upstream behaves the same way. */
@(test)
test_card_parts_render_alone :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ title(); h.text("Loose") }
	})
	testing.expect_value(t, out, `<h3 class="` + CD_TITLE + `">Loose</h3>`)
}

@(test)
test_card_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{card({id = "c", class = "max-w-sm"})
			{header({id = "c-h", class = "pb-2"})
				{ title({id = "c-t", class = "text-xl"}); h.text("T") }
				{ description({id = "c-d", class = "italic"}); h.text("D") }
			}
			{ content({id = "c-c", class = "pt-2"}); h.text("C") }
			{ footer({id = "c-f", class = "justify-end"}); h.text("F") }
		}
	})
	testing.expect(t, strings.has_prefix(out, `<div id="c" class="` + CD_CARD + ` max-w-sm">`))
	testing.expect(t, strings.contains(out, `<div id="c-h" class="` + CD_HEADER + ` pb-2">`))
	testing.expect(t, strings.contains(out, `<h3 id="c-t" class="` + CD_TITLE + ` text-xl">T</h3>`))
	testing.expect(t, strings.contains(out, `<p id="c-d" class="` + CD_DESC + ` italic">D</p>`))
	testing.expect(t, strings.contains(out, `<div id="c-c" class="` + CD_CONTENT + ` pt-2">C</div>`))
	testing.expect(t, strings.contains(out, `<div id="c-f" class="` + CD_FOOTER + ` justify-end">F</div>`))
}

@(test)
test_card_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{card({}, hx.get("/card"), a.data("testid", "card"))
			h.text("x")
		}
	})
	testing.expect_value(t, out, `<div class="` + CD_CARD + `" hx-get="/card" data-testid="card">x</div>`)
}

/* Two cards in a row: each closed back to its own mark, so the second is a
sibling rather than the first one's content. */
@(test)
test_card_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{card()
			{ content(); h.text("One") }
		}
		{card()
			{ content(); h.text("Two") }
		}
	})
	testing.expect_value(t, strings.count(out, CD_CARD), 2)
	testing.expect(t, strings.contains(out, "One</div></div><div "))
	testing.expect(t, strings.has_suffix(out, "Two</div></div>"))
}
