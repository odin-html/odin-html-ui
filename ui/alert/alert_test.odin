/* Tests for alert, in the package rather than in a test package of their own, so a
ported component carries its tests beside it.

Everything here still goes through the public API: what is worth testing is the
composition -- the call-site braces, which tag each component chose, which scope
its closing tag landed in -- none of which a unit test of a private proc reaches.

The class tables are restated rather than referenced, and being in the package
now makes that a choice rather than a necessity. The duplication is the point:
these are golden tests against templui's output, and a table that changed on
both sides at once would prove nothing. */
package alert

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
AL_BASE ::
	"relative w-full rounded-lg border px-4 py-3 text-sm " +
	"grid has-[>svg]:grid-cols-[1rem_1fr] grid-cols-[0_1fr] has-[>svg]:gap-x-3 gap-y-0.5 items-start " +
	"[&amp;>svg]:size-4 [&amp;>svg]:translate-y-0.5 [&amp;>svg]:text-current"

@(private = "file")
AL_DEFAULT :: "bg-card text-card-foreground"

@(private = "file")
AL_DESTRUCTIVE ::
	"text-destructive bg-card [&amp;>svg]:text-current " + "*:data-[slot=alert-description]:text-destructive/90"

@(private = "file")
AL_TITLE :: "col-start-2 line-clamp-1 min-h-4 font-medium tracking-tight"

@(private = "file")
AL_DESC :: "text-muted-foreground col-start-2 grid justify-items-start gap-1 text-sm [&amp;_p]:leading-relaxed"

/* The whole composition in one expectation, so the nesting and the attribute
order are pinned together -- three components, each handing an element to the
next block down. */
@(test)
test_alert_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{alert()
			{title()
				h.text("Heads up")
			}
			{description()
				{ h.p(); h.text("Something happened.") }
			}
		}
	})
	testing.expect_value(
		t,
		out,
		`<div data-slot="alert" class="` +
		AL_BASE +
		" " +
		AL_DEFAULT +
		`" role="alert">` +
		`<h5 data-slot="alert-title" class="` +
		AL_TITLE +
		`">Heads up</h5>` +
		`<div data-slot="alert-description" class="` +
		AL_DESC +
		`"><p>Something happened.</p></div>` +
		`</div>`,
	)
}

/* Props{} is the default variant, so this must be byte-identical to the call
above -- upstream's normalizing prologue has no counterpart here, and this is
what says it is not needed. */
@(test)
test_alert_zero_props_is_default :: proc(t: ^testing.T) {
	explicit := rendered(t, proc() {
			{alert({variant = .Default})
				h.text("x")
			}
		})
	implicit := rendered(t, proc() {
		{alert()
			h.text("x")
		}
	})
	testing.expect_value(t, explicit, implicit)
}

@(test)
test_alert_destructive_variant :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{alert({variant = .Destructive})
			h.text("x")
		}
	})
	testing.expect_value(
		t,
		out,
		`<div data-slot="alert" class="` + AL_BASE + " " + AL_DESTRUCTIVE + `" role="alert">x</div>`,
	)
}

/* The destructive variant recolours the description by reaching through
data-slot, so the attribute is part of what that variant renders rather than a
label. Removing it from description() would leave both class lists intact and
change the output, which is the kind of coupling only a composed test sees. */
@(test)
test_alert_destructive_selects_description_by_slot :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{alert({variant = .Destructive})
				{ description(); h.text("Declined.") }
			}
		})
	testing.expect(t, strings.contains(out, "*:data-[slot=alert-description]:text-destructive/90"))
	testing.expect(t, strings.contains(out, `<div data-slot="alert-description" `))
}

/* The icon is a child, and a direct one: every selector that positions it
matches a direct child only, so wrapping it renders the alert in its no-icon
shape with an icon inside. Neither the compiler nor the class list can see
that, so the contract is pinned here. */
@(test)
test_alert_icon_is_a_direct_child :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{alert({variant = .Destructive})
			{ icon.icon(.Triangle_Alert) }
			{ title(); h.text("Payment failed") }
		}
	})
	testing.expect(t, strings.contains(out, `role="alert"><svg `))
	testing.expect(t, strings.contains(out, `</svg><h5 `))
}

/* The caller's class lands last on all three, appended rather than merged --
see the file comment in button/button.odin. */
@(test)
test_alert_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{alert({id = "pay", class = "mt-4"})
			{title({id = "pay-t", class = "text-base"})
				h.text("T")
			}
			{description({id = "pay-d", class = "prose"})
				h.text("D")
			}
		}
	})
	testing.expect(t, strings.has_prefix(out, `<div id="pay" data-slot="alert" class="`))
	testing.expect(t, strings.contains(out, AL_DEFAULT + ` mt-4" role="alert">`))
	testing.expect(
		t,
		strings.contains(out, `<h5 id="pay-t" data-slot="alert-title" class="` + AL_TITLE + ` text-base">T</h5>`),
	)
	testing.expect(
		t,
		strings.contains(out, `<div id="pay-d" data-slot="alert-description" class="` + AL_DESC + ` prose">D</div>`),
	)
}

/* attrs is spread last and the later duplicate wins, so role is a default
rather than a fixture -- which matters because the one set here interrupts a
screen reader, and an alert that is simply present at page load should not. */
@(test)
test_alert_role_is_overridable :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{alert({}, a.role("status"), hx.get("/alerts"))
				h.text("x")
			}
		})
	testing.expect(t, strings.has_suffix(out, `" role="status" hx-get="/alerts">x</div>`))
	testing.expect(t, !strings.contains(out, `role="alert"`))
}

/* Two in a row: each closed back to its own mark, so the second is a sibling
rather than a child. */
@(test)
test_alert_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{alert()
			{ title(); h.text("One") }
		}
		{alert({variant = .Destructive})
			{ title(); h.text("Two") }
		}
	})
	testing.expect_value(t, strings.count(out, `data-slot="alert"`), 2)
	testing.expect(t, strings.contains(out, `One</h5></div><div data-slot="alert" `))
	testing.expect(t, strings.has_suffix(out, "Two</h5></div>"))
}
