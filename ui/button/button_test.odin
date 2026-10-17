/* Tests for button, in the package rather than in a test package of their own, so a
ported component carries its tests beside it.

Everything here still goes through the public API: a component is worth testing
for its call-site braces, which tag it chose and which scope the closing tag
landed in, none of which is visible from a unit test of a private proc.

The class tables below are restated rather than referenced, and being in the
package now makes that a choice rather than a necessity. The duplication is the
point: these are golden tests against templui's output, and a table that changed
on both sides at once would prove nothing. */
package button

import "core:strings"
import "core:testing"

import "html:html/a"
import "html:html/h"
import "html:html/hx"

/* The rendered form of the five base strings, not the source form: escape_attr
turns & into &amp; and ' into &#39;, so Tailwind's arbitrary variants arrive
escaped. They still work -- the value the DOM and therefore the CSS engine sees
is the unescaped one -- but an expectation has to spell out what went on the
wire. */
@(private = "file")
BASE ::
	"inline-flex items-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-all " +
	"justify-center " +
	"disabled:pointer-events-none disabled:opacity-50 [&amp;_svg]:pointer-events-none " +
	"[&amp;_svg:not([class*=&#39;size-&#39;])]:size-4 shrink-0 [&amp;_svg]:shrink-0 " +
	"outline-none focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] " +
	"aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive " +
	"cursor-pointer"

@(private = "file")
V_DEFAULT :: "bg-primary text-primary-foreground shadow-xs hover:bg-primary/90"
@(private = "file")
V_OUTLINE ::
	"border bg-background shadow-xs hover:bg-accent hover:text-accent-foreground " +
	"dark:bg-input/30 dark:border-input dark:hover:bg-input/50"
@(private = "file")
V_LINK :: "text-primary underline-offset-4 hover:underline"

@(private = "file")
S_DEFAULT :: "h-9 px-4 py-2 has-[>svg]:px-3"
@(private = "file")
S_SM :: "h-8 rounded-md gap-1.5 px-3 has-[>svg]:px-2.5"
@(private = "file")
S_ICON :: "size-9"

@(private = "file")
rendered :: proc(t: ^testing.T, body: proc()) -> string {
	out, err := h.render_to_string(body, context.temp_allocator)
	testing.expect_value(t, err, nil)
	return out
}

/* Proc literals do not capture, so every body below states its own Props. That
is also why there is one test per shape rather than a table. */

@(test)
test_button_default :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{button()
			h.text("Save")
		}
	})
	testing.expect_value(
		t,
		out,
		`<button class="` + BASE + " " + V_DEFAULT + " " + S_DEFAULT + `" type="button">Save</button>`,
	)
}

/* Props{} is the default variant, size and type, so this must be byte-identical
to the call above -- the normalizing prologue button.templ opens with has no
counterpart here, and this is what says it is not needed. */
@(test)
test_button_zero_props_is_default :: proc(t: ^testing.T) {
	explicit := rendered(t, proc() {
			{button({variant = .Default, size = .Default, type = .Button})
				h.text("Save")
			}
		})
	implicit := rendered(t, proc() {
		{button()
			h.text("Save")
		}
	})
	testing.expect_value(t, explicit, implicit)
}

@(test)
test_button_variant_and_size :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{button({variant = .Outline, size = .Sm})
			h.text("Save")
		}
	})
	testing.expect_value(
		t,
		out,
		`<button class="` + BASE + " " + V_OUTLINE + " " + S_SM + `" type="button">Save</button>`,
	)
}

/* Upstream's modifierClasses, which was a []string joined with a space. Here
it is a.class dropping the empty part, so the unset case leaves no double
space behind. */
@(test)
test_button_full_width :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{button({size = .Icon, full_width = true})
				h.text("+")
			}
		})
	testing.expect_value(
		t,
		out,
		`<button class="` + BASE + " " + V_DEFAULT + " " + S_ICON + ` w-full" type="button">+</button>`,
	)
}

/* The caller's class lands last in the list. Which of two conflicting
utilities applies is then stylesheet source order, because there is no TwMerge
here -- see the file comment in button.odin. Both are present, and that is the
behaviour being pinned, not endorsed. */
@(test)
test_button_class_is_appended_not_merged :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{button({class = "h-12 mt-4"})
				h.text("Save")
			}
		})
	testing.expect(t, strings.has_suffix(out, ` h-9 px-4 py-2 has-[>svg]:px-3 h-12 mt-4" type="button">Save</button>`))
}

@(test)
test_button_id_type_and_form :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{button({id = "save", type = .Submit, form = "editor"})
			h.text("Save")
		}
	})
	testing.expect(t, strings.has_prefix(out, `<button id="save" class="`))
	testing.expect(t, strings.has_suffix(out, `" type="submit" form="editor">Save</button>`))
}

/* Bare boolean: absent rather than disabled="false". */
@(test)
test_button_disabled :: proc(t: ^testing.T) {
	off := rendered(t, proc() {
		{button()
			h.text("Save")
		}
	})
	testing.expect(t, !strings.contains(off, "disabled>"))

	on := rendered(t, proc() {
		{button({disabled = true})
			h.text("Save")
		}
	})
	testing.expect(t, strings.has_suffix(on, `" type="button" disabled>Save</button>`))
}

@(test)
test_button_href_renders_anchor :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{button({href = "/docs", variant = .Link})
			h.text("Docs")
		}
	})
	testing.expect_value(t, out, `<a href="/docs" class="` + BASE + " " + V_LINK + " " + S_DEFAULT + `">Docs</a>`)
}

@(test)
test_button_anchor_id_and_target :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{button({id = "docs", href = "/docs", target = "_blank"})
			h.text("Docs")
		}
	})
	testing.expect(t, strings.has_prefix(out, `<a id="docs" href="/docs" target="_blank" class="`))
	testing.expect(t, strings.has_suffix(out, `">Docs</a>`))
}

/* An anchor has no disabled attribute, so disabled wins over href and the
element stops being a link -- upstream resolves it the same way. Note the href
is dropped entirely rather than carried onto the button. */
@(test)
test_button_disabled_href_renders_button :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{button({href = "/docs", disabled = true})
			h.text("Docs")
		}
	})
	testing.expect(t, strings.has_prefix(out, "<button "))
	testing.expect(t, !strings.contains(out, "href"))
	testing.expect(t, strings.has_suffix(out, `" type="button" disabled>Docs</button>`))
}

@(test)
test_button_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{button({size = .Sm}, hx.post("/save"), a.aria("label", "Save"))
			h.text("Save")
		}
	})
	testing.expect(t, strings.has_suffix(out, `" type="button" hx-post="/save" aria-label="Save">Save</button>`))
}

/* attrs is spread last and write_attrs lets the later duplicate win, so a
caller can override anything the component set -- including the type, which
upstream's Attributes spread could not reach past. */
@(test)
test_button_extra_attrs_override :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{button({type = .Button}, a.type("submit"))
			h.text("Save")
		}
	})
	testing.expect(t, strings.has_suffix(out, `" type="submit">Save</button>`))
	testing.expect(t, !strings.contains(out, `type="button"`))
}

/* The label is the caller's block, which is the whole reason this is an _open
component: the closing tag has to land after content the component never sees.
Two calls in a row check that each closed back to its own mark. */
@(test)
test_button_children_and_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{button({size = .Icon})
			{ h.span(a.aria("hidden", "true")); h.text("+") }
		}
		{button({variant = .Ghost})
			h.text("Cancel")
		}
	})
	testing.expect(t, strings.contains(out, `<span aria-hidden="true">+</span></button><button `))
	testing.expect(t, strings.has_suffix(out, "Cancel</button>"))
}
