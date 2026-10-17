/* Tests for tabs, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package tabs

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
LIST :: "bg-muted text-muted-foreground inline-flex h-9 w-fit items-center justify-center " + "rounded-lg p-[3px]"

/* Upstream's single literal, escaped as it goes on the wire and in upstream's
own order -- the interleaving is the thing this pins. The state attribute is the
port's, not upstream's: data-tui-tabs-state became data-oh-tabs-state with the
element, and these variants are what draws the active tab. */
@(private = "file")
TRIGGER ::
	"data-[oh-tabs-state=active]:bg-background " +
	"dark:data-[oh-tabs-state=active]:text-foreground " +
	"focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:outline-ring " +
	"dark:data-[oh-tabs-state=active]:border-input " +
	"dark:data-[oh-tabs-state=active]:bg-input/30 " +
	"text-foreground dark:text-muted-foreground inline-flex h-[calc(100%-1px)] flex-1 " +
	"items-center justify-center gap-1.5 rounded-md border border-transparent px-2 py-1 " +
	"text-sm font-medium whitespace-nowrap transition-[color,box-shadow] " +
	"focus-visible:ring-[3px] focus-visible:outline-1 " +
	"disabled:pointer-events-none disabled:opacity-50 " +
	"data-[oh-tabs-state=active]:shadow-sm " +
	"[&amp;_svg]:pointer-events-none [&amp;_svg]:shrink-0 " +
	"[&amp;_svg:not([class*=&#39;size-&#39;])]:size-4"

@(private = "file")
WRAP :: `<oh-tabs class="contents">`

@(test)
test_tabs_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{tabs({id = "s"})
			{list({tabs_id = "s"})
				{trigger({tabs_id = "s", value = "g", is_active = true})
					h.text("G")}
			}
			{content({tabs_id = "s", value = "g", is_active = true})
				h.text("Body")}
		}
	})
	testing.expect_value(
		t,
		out,
		WRAP +
		`<div id="s" class="flex flex-col gap-2" data-oh-tabs="root" data-oh-tabs-id="s">` +
		`<div class="` +
		LIST +
		`" data-oh-tabs="list" data-oh-tabs-id="s">` +
		`<button type="button" class="` +
		TRIGGER +
		`" data-oh-tabs="trigger" data-oh-tabs-id="s" data-oh-tabs-value="g" ` +
		`data-oh-tabs-state="active">G</button></div>` +
		`<div class="flex-1 outline-none" data-oh-tabs="content" data-oh-tabs-id="s" ` +
		`data-oh-tabs-value="g" data-oh-tabs-state="active">Body</div></div></oh-tabs>`,
	)
}

/* The group's name is the root's id, and every part of the group repeats it.
Nothing reads it any more -- <oh-tabs> is what pairs a trigger with its panel --
so a mismatch is now harmless rather than the caller's to avoid. */
@(test)
test_tabs_id_is_carried_by_every_part :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{tabs({id = "s"})
				{list({tabs_id = "s"})
					{ trigger({tabs_id = "s", value = "a"}) }
				}
				{ content({tabs_id = "s", value = "a"}) }
			}
		})
	testing.expect_value(t, strings.count(out, `data-oh-tabs-id="s"`), 4)
}

/* No id, no name: the attribute is still written, empty, and the group still
works -- the wrapper is the boundary, where tabs.js skipped an id-less group. */
@(test)
test_tabs_without_id_renders_an_empty_group :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ tabs() }
	})
	testing.expect(t, strings.contains(out, `data-oh-tabs-id=""`))
	testing.expect(t, !strings.contains(out, " id="))
}

/* An inactive panel is hidden by a class, which is why every panel shows
before the stylesheet arrives. */
@(test)
test_tabs_inactive_content_is_hidden_by_class :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({tabs_id = "s", value = "b"}); h.text("x") }
	})
	testing.expect(t, strings.contains(out, `class="flex-1 outline-none hidden"`))
	testing.expect(t, strings.contains(out, `data-oh-tabs-state="inactive"`))
}

@(test)
test_tabs_state_attr :: proc(t: ^testing.T) {
	testing.expect_value(t, state_attr(true), "active")
	testing.expect_value(t, state_attr(false), "inactive")
}

/* A trigger with no value renders the error span *and* the button, as upstream
does -- inert rather than absent. */
@(test)
test_tabs_trigger_without_value :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({tabs_id = "s"}); h.text("G") }
	})
	// Text content, not an attribute: h.text escapes &, < and > and leaves the
	// apostrophes alone.
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<span class="text-xs text-destructive">Error: Tab Trigger missing required 'Value' attribute.</span>`,
		),
	)
	testing.expect(t, strings.contains(out, `data-oh-tabs-value=""`))
	testing.expect(t, strings.has_suffix(out, "G</button>"))
}

/* The deviation: upstream drops a valueless panel and its children both. A
component here cannot decline its children, so the wrapper is still written and
they stay inside it. */
@(test)
test_tabs_content_without_value_still_wraps_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ content({tabs_id = "s"}); h.text("orphan") }
	})
	testing.expect(t, strings.has_prefix(out, `<span class="text-xs text-destructive">Error: Tab Content missing`))
	testing.expect(t, strings.has_suffix(out, `data-oh-tabs-state="inactive">orphan</div>`))
}

/* Two panels are siblings, and each closes at the end of its own block -- and
the group's close is followed by the wrapper's, innermost first. */
@(test)
test_tabs_two_panels_are_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{tabs({id = "s"})
			{content({tabs_id = "s", value = "a", is_active = true})
				h.text("A")}
			{ content({tabs_id = "s", value = "b"}); h.text("B") }
		}
	})
	testing.expect_value(t, strings.count(out, `data-oh-tabs="content"`), 2)
	testing.expect(t, strings.contains(out, "A</div><div class="))
	testing.expect(t, strings.has_suffix(out, "B</div></div></oh-tabs>"))
}

/* A group nested in another group's panel: the element switches only the parts
whose nearest <oh-tabs> is its own, which is what document delegation got from a
shared id. Nothing here enforces that; this pins the shape it relies on. */
@(test)
test_tabs_nested :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{tabs({id = "outer"})
			{content({tabs_id = "outer", value = "a", is_active = true})
				{tabs({id = "inner"})
					{ trigger({tabs_id = "inner", value = "x"}); h.text("X") }
				}
			}
		}
	})
	testing.expect_value(t, strings.count(out, WRAP), 2)
	testing.expect(t, strings.contains(out, WRAP + `<div id="inner" class="flex flex-col gap-2" data-oh-tabs="root"`))
	// Four closes: the inner root, the inner wrapper, the outer panel, then the
	// outer root and its wrapper.
	testing.expect(t, strings.has_suffix(out, "X</button></div></oh-tabs></div></div></oh-tabs>"))
}

@(test)
test_tabs_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{tabs({id = "s", class = "gap-4"})
			{list({id = "s-l", tabs_id = "s", class = "w-full"})
				{ trigger({id = "s-t", tabs_id = "s", value = "a", class = "grow"}) }
			}
			{ content({id = "s-c", tabs_id = "s", value = "a", class = "pt-2"}) }
		}
	})
	testing.expect(t, strings.has_prefix(out, WRAP + `<div id="s" class="flex flex-col gap-2 gap-4"`))
	testing.expect(t, strings.contains(out, `<div id="s-l" class="` + LIST + ` w-full"`))
	testing.expect(t, strings.contains(out, `<button id="s-t" type="button" class="` + TRIGGER + ` grow"`))
	testing.expect(t, strings.contains(out, `<div id="s-c" class="flex-1 outline-none hidden pt-2"`))
}

@(test)
test_tabs_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{tabs({id = "s"}, a.data("testid", "s"))
			{ trigger({tabs_id = "s", value = "a"}, hx.get("/a")) }
		}
	})
	testing.expect(t, strings.contains(out, `data-oh-tabs-id="s" data-testid="s">`))
	testing.expect(t, strings.contains(out, `data-oh-tabs-state="inactive" hx-get="/a">`))
}

/* The structural contract (README.md, "The contract test"): tabs.ts declares in
tabs.contract.json everything it reads from this component's markup, and this
test asserts the rendered markup carries all of it. The manifest is consumed by
both sides -- the class imports it for the two roles it acts on, the value the
two are matched by, the state attribute it writes, the two state values, and the
class that hides a panel; this test reads it from disk -- so neither side can
drift from the declaration without the shared file appearing in the diff.

data-oh-tabs-id is not in it, and neither are the root and list roles: the
element pairs a trigger with its panel by the wrapper it sits in, so the id is
the group's name and nothing more, and the two outer roles are markup nothing
reads. There is no agreement left to test for any of the three.

The state attribute is declared like an attribute *and* matched by the class
table above -- TRIGGER_BASE's data-[oh-tabs-state=active] variants are the active
look, so the name and the value are one mechanism shared with tabs.ts. The
hidden class is the same kind of agreement seen from the other side: this
component renders it on an inactive panel and the element toggles it.

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
CONTRACT_PATH :: #directory + "/../../web/src/ui/tabs.contract.json"

/* The attribute a selector names, value and all: `[data-oh-tabs="trigger"]`
names data-oh-tabs="trigger". Every selector this component declares is of that
one kind -- the contract keeps CSS selector syntax because the TS side feeds it
to querySelectorAll and to Element.closest verbatim. */
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
test_tabs_contract :: proc(t: ^testing.T) {
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

	// A whole group, one tab active and one not: every role the element acts on,
	// both state values, and the class an inactive panel carries.
	out := rendered(t, proc() {
		{tabs({id = "s"})
			{list({tabs_id = "s"})
				{ trigger({tabs_id = "s", value = "g", is_active = true}); h.text("G") }
				{ trigger({tabs_id = "s", value = "k"}); h.text("K") }
			}
			{ content({tabs_id = "s", value = "g", is_active = true}); h.text("General") }
			{ content({tabs_id = "s", value = "k"}); h.text("Keys") }
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

	// The value is what a trigger and its panel are matched by, so it appears on
	// both of them with the same string.
	matched := fmt.tprintf(`%s="g"`, contract.attributes["value"])
	testing.expectf(t, strings.count(out, matched) == 2, "markup lacks a trigger and a panel carrying %s", matched)

	// The state attribute, with both values: the one the element reads as the
	// group's initial choice and writes on the tab that wins, and the one it
	// writes on every other part.
	for _, state in contract.states {
		with_value := fmt.tprintf(`%s="%s"`, contract.attributes["state"], state)
		testing.expectf(t, strings.contains(out, with_value), "markup lacks %s", with_value)
	}

	// The class that hides a panel, which is the element's to toggle and this
	// component's to render on whatever starts inactive.
	hidden := fmt.tprintf(`class="%s %s"`, CONTENT_BASE, contract.classes["hidden"])
	testing.expectf(t, strings.contains(out, hidden), "markup lacks %s", hidden)
}
