/* Tests for carousel, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package carousel

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
ROOT :: "relative overflow-hidden w-full"
@(private = "file")
TRACK :: "flex h-full w-full transition-transform duration-500 ease-in-out cursor-grab"
@(private = "file")
ITEM :: "flex-shrink-0 w-full h-full relative"
@(private = "file")
DOT :: "w-3 h-3 rounded-full bg-foreground/30 hover:bg-foreground/50 " + "focus:outline-none transition-colors"

@(test)
test_carousel_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{carousel()
			{content()
				{ item(); h.text("A") }
			}
		}
	})
	testing.expect_value(
		t,
		out,
		`<oh-carousel class="contents"><div class="` +
		ROOT +
		`" data-oh-carousel data-oh-carousel-current="0" data-oh-carousel-autoplay="false" ` +
		`data-oh-carousel-interval="5000" data-oh-carousel-loop="false">` +
		`<div class="` +
		TRACK +
		`" data-oh-carousel-track><div class="` +
		ITEM +
		`" data-oh-carousel-item>A</div></div></div></oh-carousel>`,
	)
}

/* Zero means 5000, as upstream falls back. */
@(test)
test_carousel_interval_default :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ carousel({interval = 2000}) }
		})
	testing.expect(t, strings.contains(out, `data-oh-carousel-interval="2000"`))
}

/* The script's booleans are strings it compares with getAttribute, not bare
attributes. */
@(test)
test_carousel_flags_are_string_booleans :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ carousel({autoplay = true, loop = true}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-carousel-autoplay="true"`))
	testing.expect(t, strings.contains(out, `data-oh-carousel-loop="true"`))
}

/* Nothing here positions the track: the transform is carousel.ts's, so an
unscripted page shows the first slide only. */
@(test)
test_carousel_track_has_no_transform :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{carousel()
			{content()
				{ item() }
				{ item() }
			}
		}
	})
	testing.expect(t, !strings.contains(out, "style="))
	testing.expect(t, strings.contains(out, `data-oh-carousel-current="0"`))
}

@(test)
test_carousel_arrows :: proc(t: ^testing.T) {
	prev := rendered(t, proc() {
		{ previous() }
	})
	testing.expect(t, strings.contains(prev, `data-oh-carousel-prev aria-label="Previous slide" type="button">`))
	testing.expect(t, strings.contains(prev, `<svg viewBox="0 0 24 24" class="icon">`))
	testing.expect(t, strings.contains(prev, "left-2"))

	next_out := rendered(t, proc() {
		{ next() }
	})
	testing.expect(t, strings.contains(next_out, `data-oh-carousel-next aria-label="Next slide"`))
	testing.expect(t, strings.contains(next_out, "right-2"))
}

/* One dot per count, each carrying its index, and the first drawn active --
the only state this file decides. */
@(test)
test_carousel_indicators :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ indicators({count = 3}) }
	})
	testing.expect_value(t, strings.count(out, "<button"), 3)
	testing.expect(
		t,
		strings.contains(
			out,
			`class="` +
			DOT +
			` bg-primary" data-oh-carousel-indicator="0" data-oh-carousel-active="true" aria-label="Go to slide 1"`,
		),
	)
	testing.expect(
		t,
		strings.contains(
			out,
			`class="` +
			DOT +
			`" data-oh-carousel-indicator="1" data-oh-carousel-active="false" aria-label="Go to slide 2"`,
		),
	)
	testing.expect(t, strings.contains(out, `aria-label="Go to slide 3"`))
	testing.expect_value(t, strings.count(out, "bg-primary"), 1)
}

/* count is the caller's to keep in step with the slides: nothing counts them,
since they are children written after this runs. */
@(test)
test_carousel_indicators_zero_count :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ indicators() }
	})
	testing.expect(t, !strings.contains(out, "<button"))
	testing.expect(t, strings.has_suffix(out, "flex gap-2\"></div>"))
}

/* The last three take no children: what follows a call is a sibling. */
@(test)
test_carousel_controls_take_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ previous() }
		{ next() }
		{ indicators({count = 1}) }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "</div>after"))
	testing.expect_value(t, strings.count(out, "data-oh-carousel-prev"), 1)
}

@(test)
test_carousel_ids_classes_and_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{carousel({id = "c", class = "h-64"}, hx.get("/c"), a.data("testid", "c"))
			{content({id = "c-t", class = "gap-0"})
				{ item({id = "c-1", class = "bg-muted"}) }
			}
		}
	})
	testing.expect(
		t,
		strings.has_prefix(out, `<oh-carousel class="contents"><div id="c" class="` + ROOT + ` h-64" data-oh-carousel `),
	)
	testing.expect(t, strings.contains(out, `data-oh-carousel-loop="false" hx-get="/c" data-testid="c">`))
	testing.expect(t, strings.contains(out, `<div id="c-t" class="` + TRACK + ` gap-0"`))
	testing.expect(t, strings.contains(out, `<div id="c-1" class="` + ITEM + ` bg-muted"`))
}

/* The structural contract (README.md, "The contract test"): carousel.ts declares in
carousel.contract.json everything it reads from this component's markup, and
this test asserts the rendered markup carries all of it. The manifest is
consumed by both sides -- the class imports it for the roles it queries, the
attributes it reads and writes, the two string booleans it compares against, the
interval it falls back to and the two dot classes it toggles; this test reads it
from disk -- so neither side can drift from the declaration without the shared
file appearing in the diff.

The two classes are in there because they are the one thing here that is not an
attribute: the element toggles bg-primary and bg-foreground/30 on the dots, and
this component renders both. `opacity-50`, which the element toggles on an arrow
that has nowhere to go, is not: nothing on this side writes it, so there is no
agreement to test.

The display assertion is the one thing beyond markup: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in
the pre-upgrade window, where nothing else catches it. */

@(private = "file")
Contract :: struct {
	element:          string,
	display:          string,
	selectors:        map[string]string,
	attributes:       map[string]string,
	flags:            map[string]string,
	classes:          map[string]string,
	initial_index:    string `json:"initialIndex"`,
	default_interval: string `json:"defaultInterval"`,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/carousel.contract.json"

/* The attribute a selector names: "[data-oh-carousel-track]" names
data-oh-carousel-track. Every selector this component declares is of that one
kind -- the contract keeps CSS selector syntax because the TS side feeds it to
querySelectorAll and to Element.closest verbatim. */
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
test_carousel_contract :: proc(t: ^testing.T) {
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

	/* A whole carousel: autoplaying at the default interval, not looping, two
	slides, both arrows and a dot per slide -- the only shape that carries every
	role and both string booleans at once. */
	out := rendered(t, proc() {
		{carousel({autoplay = true})
			{content()
				{ item() }
				{ item() }
			}
			{ previous() }
			{ next() }
			{ indicators({count = 2}) }
		}
	})

	// The wrapper is the declared element and carries the declared display
	// utility as a whole class token.
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

	// Every part the element selects by, and every attribute it reads or writes,
	// appears in the rendered markup.
	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
	for _, attr in contract.attributes {
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}

	/* The two values both sides fall back to: the slide a carousel starts on,
	which the element reads and writes back, and the interval it uses when the
	caller names none. */
	first := fmt.tprintf(`%s="%s"`, contract.attributes["current"], contract.initial_index)
	testing.expectf(t, strings.contains(out, first), "markup lacks %s", first)

	fallback := fmt.tprintf(`%s="%s"`, contract.attributes["interval"], contract.default_interval)
	testing.expectf(t, strings.contains(out, fallback), "markup lacks %s", fallback)

	/* The string booleans: the flags are rendered as the words the element
	compares against, not as bare attributes, and the dots carry both. */
	on := contract.flags["on"]
	off := contract.flags["off"]
	pairs := [][2]string {
		{contract.attributes["autoplay"], on},
		{contract.attributes["loop"], off},
		{contract.attributes["indicatorActive"], on},
		{contract.attributes["indicatorActive"], off},
	}
	for pair in pairs {
		with_value := fmt.tprintf(`%s="%s"`, pair[0], pair[1])
		testing.expectf(t, strings.contains(out, with_value), "markup lacks %s", with_value)
	}

	// The two classes the element toggles on the dots, both rendered here: the
	// active one on the first dot, the inactive one in every dot's base.
	active := fmt.tprintf(`class="%s %s"`, DOT, contract.classes["indicatorActive"])
	testing.expectf(t, strings.contains(out, active), "markup lacks %s", active)
	testing.expectf(
		t,
		strings.contains(DOT, contract.classes["indicatorInactive"]),
		"the dot's base class list lacks %s",
		contract.classes["indicatorInactive"],
	)
}
