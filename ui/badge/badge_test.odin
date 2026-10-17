/* Tests for badge, in the package rather than in a test package of their own, so a
ported component carries its tests beside it.

Everything here still goes through the public API: what is worth testing is the
call-site braces, which tag came out and which scope its closing tag landed in,
none of which a unit test of a private proc reaches.

The class tables are restated rather than referenced, and being in the package
now makes that a choice rather than a necessity. The duplication is the point:
these are golden tests against templui's output, and a table that changed on
both sides at once would prove nothing. */
package badge

import "core:strings"
import "core:testing"

import "html:html/a"
import "html:html/h"
import "html:html/hx"

import "ui:ui/icon"

@(private = "file")
rendered :: proc(t: ^testing.T, body: proc()) -> string {
	out, err := h.render_to_string(body, context.temp_allocator)
	testing.expect_value(t, err, nil)
	return out
}

@(private = "file")
BG_BASE ::
	"inline-flex items-center justify-center rounded-md border px-2 py-0.5 text-xs font-medium " +
	"w-fit whitespace-nowrap shrink-0 [&amp;>svg]:size-3 gap-1 [&amp;>svg]:pointer-events-none " +
	"focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px] " +
	"aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive " +
	"transition-[color,box-shadow] overflow-hidden"

@(private = "file")
BG_DEFAULT :: "border-transparent bg-primary text-primary-foreground [a&amp;]:hover:bg-primary/90"
@(private = "file")
BG_SECONDARY :: "border-transparent bg-secondary text-secondary-foreground [a&amp;]:hover:bg-secondary/90"
@(private = "file")
BG_OUTLINE :: "text-foreground [a&amp;]:hover:bg-accent [a&amp;]:hover:text-accent-foreground"

@(test)
test_badge_default :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{badge()
			h.text("Draft")
		}
	})
	testing.expect_value(t, out, `<span class="` + BG_BASE + " " + BG_DEFAULT + `">Draft</span>`)
}

/* Props{} is the default variant, so this must be byte-identical to the call
above -- upstream's normalizing prologue has no counterpart here. */
@(test)
test_badge_zero_props_is_default :: proc(t: ^testing.T) {
	explicit := rendered(t, proc() {
		{badge({variant = .Default})
			h.text("x")
		}
	})
	implicit := rendered(t, proc() {
		{badge()
			h.text("x")
		}
	})
	testing.expect_value(t, explicit, implicit)
}

@(test)
test_badge_variants :: proc(t: ^testing.T) {
	secondary := rendered(t, proc() {
		{ badge({variant = .Secondary}); h.text("x") }
	})
	testing.expect_value(t, secondary, `<span class="` + BG_BASE + " " + BG_SECONDARY + `">x</span>`)

	outline := rendered(t, proc() {
		{ badge({variant = .Outline}); h.text("x") }
	})
	testing.expect_value(t, outline, `<span class="` + BG_BASE + " " + BG_OUTLINE + `">x</span>`)

	destructive := rendered(t, proc() {
		{ badge({variant = .Destructive}); h.text("x") }
	})
	testing.expect(t, strings.contains(destructive, "bg-destructive text-white"))
	testing.expect(t, strings.contains(destructive, "dark:focus-visible:ring-destructive/40"))
}

/* Every variant carries hover rules guarded by [a&], which matches only when
the element is itself an anchor. Nothing here ever renders one, so they are
inert -- pinned because the classes being present reads as if they work, and
this is what says they do not. If a badge ever grows an href, this is the test
that should change. */
@(test)
test_badge_is_always_a_span :: proc(t: ^testing.T) {
	/* One literal per variant rather than a loop: proc literals do not
	capture, so a loop over Variant would render the default four times and
	claim to have checked all four. */
	out := rendered(t, proc() {
		{ badge({variant = .Default}); h.text("a") }
		{ badge({variant = .Secondary}); h.text("b") }
		{ badge({variant = .Destructive}); h.text("c") }
		{ badge({variant = .Outline}); h.text("d") }
	})
	testing.expect_value(t, strings.count(out, "<span "), 4)
	testing.expect(t, !strings.contains(out, "<a "))
	testing.expect_value(t, strings.count(out, "[a&amp;]:hover:"), 5) // outline carries two
}

@(test)
test_badge_id_and_class_appended :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{badge({id = "state", class = "ml-2"})
			h.text("New")
		}
	})
	testing.expect(t, strings.has_prefix(out, `<span id="state" class="`))
	testing.expect(t, strings.has_suffix(out, BG_DEFAULT + ` ml-2">New</span>`))
}

/* An svg child is sized by the badge rather than by itself, so the icon carries
no size class -- the same reason the galleries' plus() does not. Direct child
only. */
@(test)
test_badge_with_an_icon :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{badge({variant = .Secondary})
			{ icon.icon(.Circle_Alert) }
			h.text("Failing")
		}
	})
	testing.expect(t, strings.contains(out, `"><svg viewBox="0 0 24 24" class="icon">`))
	testing.expect(t, strings.has_suffix(out, "</svg>Failing</span>"))
}

@(test)
test_badge_extra_attrs_and_override :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{badge({}, hx.get("/state"), a.aria("label", "state"))
			h.text("New")
		}
	})
	testing.expect(t, strings.has_suffix(out, `" hx-get="/state" aria-label="state">New</span>`))

	replaced := rendered(t, proc() {
		{badge({class = "ml-2"}, a.class("only-this"))
			h.text("New")
		}
	})
	testing.expect_value(t, replaced, `<span class="only-this">New</span>`)
}

@(test)
test_badge_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ badge(); h.text("One") }
		{ badge({variant = .Outline}); h.text("Two") }
	})
	testing.expect_value(t, strings.count(out, "<span "), 2)
	testing.expect_value(t, strings.count(out, "</span>"), 2)
	testing.expect(t, strings.contains(out, "One</span><span "))
	testing.expect(t, strings.has_suffix(out, "Two</span>"))
}
