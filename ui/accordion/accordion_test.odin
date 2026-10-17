/* Tests for accordion, in the package rather than in a test package of their own, so a
ported component carries its tests beside it.

Everything here still goes through the public API: what is worth testing is the
composition -- the call-site braces, which tag each component chose, which scope
its closing tag landed in -- none of which a unit test of a private proc reaches.

The class tables are restated rather than referenced, and being in the package
now makes that a choice rather than a necessity. The duplication is the point:
these are golden tests against templui's output, and a table that changed on
both sides at once would prove nothing. */
package accordion

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
ACC_ITEM :: "group border-b last:border-b-0 [&amp;[open]>summary>svg]:rotate-180"

@(private = "file")
ACC_TRIGGER ::
	"flex flex-1 items-start justify-between gap-4 py-4 " +
	"text-left text-sm font-medium " +
	"transition-all hover:underline cursor-pointer " +
	"outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:border-ring rounded-md " +
	"disabled:pointer-events-none disabled:opacity-50 " +
	"list-none [&amp;::-webkit-details-marker]:hidden"

@(private = "file")
ACC_CONTENT :: "pt-0 pb-4 text-sm overflow-hidden"

/* The chevron as trigger() writes it: the icon package's fixed attributes, the
accordion's own class, and the aria-hidden this port adds. */
@(private = "file")
ACC_CHEVRON ::
	`<svg viewBox="0 0 24 24" class="icon size-4 shrink-0 translate-y-0.5 ` +
	`transition-transform duration-200 text-muted-foreground pointer-events-none" ` +
	`aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>`

/* The whole composition, so the nesting is pinned in one place: four components
each handing an element to the next block down. */
@(test)
test_accordion_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{accordion()
			{item()
				{trigger()
					h.text("Is it accessible?")
				}
				{content()
					h.text("Yes.")
				}
			}
		}
	})
	testing.expect_value(
		t,
		out,
		`<div class=""><details name="accordion" class="` +
		ACC_ITEM +
		`"><summary class="` +
		ACC_TRIGGER +
		`">Is it accessible?` +
		ACC_CHEVRON +
		`</summary><div class="` +
		ACC_CONTENT +
		`">Yes.</div></details></div>`,
	)
}

/* The one thing the ordinary component pairing cannot do: content after the
caller's children. The label, then the chevron, then the close -- if the
deferred proc closed before writing the icon, the svg would land outside the
summary and the item's [&[open]>summary>svg] selector would stop matching. */
@(test)
test_accordion_trigger_chevron_follows_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{trigger()
				h.text("Label")
			}
		})
	testing.expect_value(t, out, `<summary class="` + ACC_TRIGGER + `">Label` + ACC_CHEVRON + `</summary>`)
}

/* Same, with the children being an element rather than text: the chevron is a
sibling of the span, still inside the summary. */
@(test)
test_accordion_trigger_chevron_after_element_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{trigger()
			{ h.span(a.class("grow")); h.text("Label") }
		}
	})
	testing.expect(t, strings.contains(out, `><span class="grow">Label</span><svg `))
	testing.expect(t, strings.has_suffix(out, "</svg></summary>"))
}

/* trigger_close closes back to its own mark, so the item's </details> still
lands at the end of the item's block rather than being dragged early. */
@(test)
test_accordion_trigger_nested_closes_only_itself :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{item()
			{trigger()
				h.text("Q")
			}
			h.text("after")
		}
	})
	testing.expect(t, strings.contains(out, "</svg></summary>after</details>"))
}

/* name is what makes a group exclusive, and upstream hardcodes it -- so two
accordions on one page share a group unless the port's extra field is used. */
@(test)
test_accordion_item_group_name :: proc(t: ^testing.T) {
	def := rendered(t, proc() {
		{ item() }
	})
	testing.expect(t, strings.contains(def, `<details name="accordion" `))

	scoped := rendered(t, proc() {
		{ item({name = "faq"}) }
	})
	testing.expect(t, strings.contains(scoped, `<details name="faq" `))
}

@(test)
test_accordion_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{accordion({id = "faq", class = "w-full"})
			{item({id = "faq-1", class = "border-0"})
				{trigger({id = "faq-1-t", class = "text-base"})
					h.text("Q")
				}
				{content({id = "faq-1-c", class = "prose"})
					h.text("A")
				}
			}
		}
	})
	testing.expect(t, strings.has_prefix(out, `<div id="faq" class="w-full">`))
	testing.expect(t, strings.contains(out, `<details id="faq-1" name="accordion" class="` + ACC_ITEM + ` border-0">`))
	testing.expect(t, strings.contains(out, `<summary id="faq-1-t" class="` + ACC_TRIGGER + ` text-base">`))
	testing.expect(t, strings.contains(out, `<div id="faq-1-c" class="` + ACC_CONTENT + ` prose">A</div>`))
}

@(test)
test_accordion_two_items_are_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{accordion()
			{item()
				{ trigger(); h.text("One") }
				{ content(); h.text("1") }
			}
			{item()
				{ trigger(); h.text("Two") }
				{ content(); h.text("2") }
			}
		}
	})
	testing.expect_value(t, strings.count(out, "<details "), 2)
	testing.expect_value(t, strings.count(out, "</details>"), 2)
	testing.expect(t, strings.contains(out, "1</div></details><details "))
	testing.expect(t, strings.has_suffix(out, "2</div></details></div>"))
}

/* An accordion carrying htmx, to check the spread reaches a component whose own
attribute list is otherwise just id and class. */
@(test)
test_accordion_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{accordion({}, hx.get("/faq"), a.data("testid", "faq"))
			h.text("x")
		}
	})
	testing.expect_value(t, out, `<div class="" hx-get="/faq" data-testid="faq">x</div>`)
}
