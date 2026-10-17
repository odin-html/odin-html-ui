/* Tests for collapsible, in the package and beside the component -- see the
file comment in accordion/accordion_test.odin for why the class tables below
are restated rather than referenced. */
package collapsible

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

/* The escaped form, which is what goes on the wire: `&` in the arbitrary
variant becomes `&amp;`. */
@(private = "file")
CONTENT ::
	"grid grid-rows-[0fr] transition-[grid-template-rows] duration-200 ease-out " +
	"[&amp;.oh-collapsible-open]:grid-rows-[1fr]"

@(private = "file")
WRAP :: `<oh-collapsible class="contents">`

@(test)
test_collapsible_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{collapsible()
			{ trigger(); h.text("Details") }
			{ content(); h.text("Body") }
		}
	})
	testing.expect_value(
		t,
		out,
		WRAP +
		`<div class="" data-oh-collapsible="root" data-oh-collapsible-state="closed">` +
		`<div class="" data-oh-collapsible="trigger">Details</div>` +
		`<div class="` +
		CONTENT +
		`" data-oh-collapsible="content"><div class="overflow-hidden">Body</div></div></div></oh-collapsible>`,
	)
}

/* open is the initial state and nothing else -- collapsible.ts takes it from
here on, and the class it toggles is the one the grid selector matches. */
@(test)
test_collapsible_open_state :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{collapsible({open = true})
				{ content(); h.text("B") }
			}
		})
	testing.expect(t, strings.contains(out, `data-oh-collapsible-state="open"`))
}

/* content() opens two elements and hands the inner one to the caller: the
children land inside overflow-hidden, which is what the grid row measures. */
@(test)
test_collapsible_content_wraps_children_twice :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{content()
			{ h.p(); h.text("hi") }
		}
	})
	testing.expect_value(
		t,
		out,
		`<div class="` +
		CONTENT +
		`" data-oh-collapsible="content"><div class="overflow-hidden"><p>hi</p></div></div>`,
	)
}

/* Both of content()'s tags close at the end of the caller's block, innermost
first, so what follows is a sibling of the outer div rather than of the inner
one -- and the root and its wrapper close after that, in the same order. */
@(test)
test_collapsible_content_closes_both :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{collapsible()
				{ content(); h.text("B") }
				h.text("after")
			}
		})
	testing.expect(t, strings.contains(out, "B</div></div>after</div></oh-collapsible>"))
}

/* Nesting: the inner collapsible is inside the outer's content, and the
element's findDirectContent is what keeps the outer content from being toggled
by the inner trigger. The wrapper is the other half of that -- a trigger belongs
to the nearest <oh-collapsible> above it. Nothing here enforces either; this only
pins the shape they rely on. */
@(test)
test_collapsible_nested :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{collapsible({id = "outer"})
			{content()
				{collapsible({id = "inner"})
					{ content(); h.text("deep") }
				}
			}
		}
	})
	testing.expect_value(t, strings.count(out, `data-oh-collapsible="root"`), 2)
	testing.expect_value(t, strings.count(out, WRAP), 2)
	testing.expect(t, strings.contains(out, WRAP + `<div id="inner" class="" data-oh-collapsible="root"`))
	// Eight closes: the inner content's two, the inner root, the inner wrapper,
	// then the outer content's two, the outer root and the outer wrapper.
	testing.expect(
		t,
		strings.has_suffix(out, "deep</div></div></div></oh-collapsible></div></div></div></oh-collapsible>"),
	)
}

@(test)
test_collapsible_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{collapsible({id = "c", class = "w-full"})
			{ trigger({id = "c-t", class = "flex"}); h.text("T") }
			{ content({id = "c-c", class = "pt-2"}); h.text("B") }
		}
	})
	testing.expect(t, strings.has_prefix(out, WRAP + `<div id="c" class="w-full" data-oh-collapsible="root"`))
	testing.expect(t, strings.contains(out, `<div id="c-t" class="flex" data-oh-collapsible="trigger">T</div>`))
	testing.expect(
		t,
		strings.contains(out, `<div id="c-c" class="` + CONTENT + ` pt-2" data-oh-collapsible="content">`),
	)
}

/* No id unless asked for, where upstream invents one. The element never reads
it, so the only cost of leaving it out is that a caller wanting to point at the
root writes the id itself. */
@(test)
test_collapsible_no_generated_id :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ collapsible() }
		})
	testing.expect(t, !strings.contains(out, "id="))
}

@(test)
test_collapsible_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{collapsible({}, hx.get("/d"), a.data("testid", "c"))
			{ trigger({}, a.role("button")); h.text("T") }
		}
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			WRAP +
			`<div class="" data-oh-collapsible="root" data-oh-collapsible-state="closed" hx-get="/d" data-testid="c">`,
		),
	)
	testing.expect(t, strings.contains(out, `data-oh-collapsible="trigger" role="button">T</div>`))
}

/* The structural contract (README.md, "The contract test"): collapsible.ts declares
in collapsible.contract.json everything it reads from this component's markup,
and this test asserts the rendered markup carries all of it. The manifest is
consumed by both sides -- the class imports it for the three roles, the state
attribute, the two state values it compares and writes, and the class the grid
selector below matches; this test reads it from disk -- so neither side can
drift from the declaration without the shared file appearing in the diff.

aria-expanded is not in it: the element writes that attribute on the trigger and
never reads it, and nothing here renders it, so there is nothing for the two
sides to agree on.

The class is declared like a value rather than a selector because that is what
it is on both sides: collapsible.ts toggles it by name and CONTENT_BASE matches
it inside an arbitrary variant, where it appears escaped.

The display assertion is the one thing beyond attributes: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in
the pre-upgrade window, where nothing else catches it. */

@(private = "file")
Contract :: struct {
	element:    string,
	display:    string,
	selectors:  map[string]string,
	attributes: map[string]string,
	states:     map[string]string,
	classes:    map[string]string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/collapsible.contract.json"

/* The attribute a selector names, value and all: `[data-oh-collapsible="root"]`
names data-oh-collapsible="root". Every selector this component declares is of
that one kind -- the contract keeps CSS selector syntax because the TS side
feeds it to querySelector and to Element.closest verbatim. */
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
test_collapsible_contract :: proc(t: ^testing.T) {
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

	// All three roles at once, rendered open: the shape the element acts on, and
	// the one carrying the state value it reads as "already open".
	out := rendered(t, proc() {
		{collapsible({open = true})
			{ trigger(); h.text("Details") }
			{ content(); h.text("Body") }
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

	// Every role the element selects by appears in the rendered markup.
	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}

	// The state attribute, with the value the element reads as open.
	for _, attr in contract.attributes {
		with_value := fmt.tprintf(`%s="%s"`, attr, contract.states["open"])
		testing.expectf(t, strings.contains(out, with_value), "markup lacks %s", with_value)
	}

	// The class the grid selector matches, which is the element's to add and
	// this component's to style -- escaped here, so the name alone is what both
	// sides share.
	testing.expectf(
		t,
		strings.contains(out, contract.classes["open"]),
		"markup lacks the %q class in its content selector",
		contract.classes["open"],
	)

	// ...and the other state value, which is what a default collapsible renders
	// and what the element writes back on close.
	closed := rendered(t, proc() {
		{ collapsible() }
	})
	with_closed := fmt.tprintf(`%s="%s"`, contract.attributes["state"], contract.states["closed"])
	testing.expectf(t, strings.contains(closed, with_closed), "markup lacks %s", with_closed)
}
