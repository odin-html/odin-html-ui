/* Tests for sidebar, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced.

sheet's, button's and icon's own markup is left to their tests; what is pinned
here is the nesting sidebar() produces, the state attributes everything else
reads, and which element each part chose. */
package sidebar

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

/* The layout carries the custom element, not sidebar() -- see the file comment
there for why the `peer` relationship forbids the obvious placement. Both
closing tags land at the end of the caller's block, innermost first. */
@(test)
test_sidebar_layout :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ layout(); h.text("x") }
	})
	testing.expect_value(
		t,
		out,
		`<oh-sidebar class="contents">` +
		`<div class="flex min-h-svh relative has-[[data-oh-sidebar-variant=inset]]:bg-sidebar" data-oh-sidebar-layout>x</div>` +
		`</oh-sidebar>`,
	)
}

/* The inset stays a sibling of the wrapper: the element wraps the layout, so
nothing inside it moved and peer-data- still reaches across. */
@(test)
test_sidebar_layout_keeps_the_peer_sibling :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{layout()
			{ sidebar({id = "main"}) }
			{ inset(); h.text("page") }
		}
	})
	wrapper := strings.index(out, `<div class="group peer hidden md:block"`)
	page := strings.index(out, "<main class=")
	element_end := strings.index(out, "</oh-sidebar>")
	testing.expect(t, wrapper > 0 && page > wrapper)
	testing.expect(t, element_end > page)
}

/* Five elements deep, and the caller's children land in the innermost -- the
one sidebar.ts moves into the mobile sheet. */
@(test)
test_sidebar_nesting :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ sidebar({id = "main"}); h.text("inside") }
			h.text("after")
		})
	testing.expect(t, strings.contains(out, `<div class="group peer hidden md:block"`))
	testing.expect(t, strings.contains(out, `<aside id="main"`))
	testing.expect(
		t,
		strings.contains(
			out,
			`<div data-oh-sidebar-content="main" class="flex h-full w-full flex-col sidebar-content">inside</div>`,
		),
	)
	testing.expect(t, strings.has_suffix(out, "</div></div></aside></div>after"))
}

/* The state everything else reads through group-data-, all on the wrapper. */
@(test)
test_sidebar_state_attributes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{sidebar(
				{
					id = "main",
					side = .Right,
					variant = .Floating,
					collapsible = .Icon,
					collapsed = true,
					keyboard_shortcut = "s",
				},
			)}
	})
	testing.expect(t, strings.contains(out, `data-oh-sidebar-state="collapsed"`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar-collapsible="icon"`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar-variant="floating"`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar-side="right"`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar-id="main"`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar-keyboard-shortcut="s"`))
	testing.expect(t, strings.contains(out, `style="--sidebar-width:16rem"`))
}

@(test)
test_sidebar_attribute_names :: proc(t: ^testing.T) {
	testing.expect_value(t, side_attr(.Left), "left")
	testing.expect_value(t, side_attr(.Right), "right")
	testing.expect_value(t, variant_attr(.Sidebar), "sidebar")
	testing.expect_value(t, variant_attr(.Floating), "floating")
	testing.expect_value(t, variant_attr(.Inset), "inset")
	testing.expect_value(t, collapsible_attr(.Offcanvas), "offcanvas")
	testing.expect_value(t, collapsible_attr(.Icon), "icon")
	testing.expect_value(t, collapsible_attr(.None), "none")
	testing.expect_value(t, size_attr(.Default), "default")
	testing.expect_value(t, size_attr(.Sm), "sm")
	testing.expect_value(t, size_attr(.Lg), "lg")
}

@(test)
test_sidebar_defaults :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ sidebar({id = "main"}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-sidebar-state="expanded"`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar-collapsible="offcanvas"`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar-variant="sidebar"`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar-side="left"`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar-keyboard-shortcut="b"`))
}

/* The mobile shell: a sheet with an empty portal in it, which is where
sidebar.ts moves the content below 768px. */
@(test)
test_sidebar_mobile_sheet :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ sidebar({id = "main"}) }
	})
	testing.expect(t, strings.has_prefix(out, `<oh-dialog id="main-mobile"`))
	testing.expect(
		t,
		strings.contains(
			out,
			`<div class="sidebar-mobile-portal flex h-full flex-col" data-oh-sidebar-mobile-portal="main"></div>`,
		),
	)
	testing.expect(t, strings.contains(out, "md:hidden bg-sidebar text-sidebar-foreground"))
}

/* Both halves of the sheet carry the side, because sheet has no context to
thread it through -- setting only the root's would slide a left-hand sidebar in
from the right. */
@(test)
test_sidebar_mobile_sheet_side_agrees :: proc(t: ^testing.T) {
	left := rendered(t, proc() {
		{ sidebar({id = "m"}) }
	})
	testing.expect_value(t, strings.count(left, `data-oh-sheet-side="left"`), 2)
	testing.expect(t, !strings.contains(left, `data-oh-sheet-side="right"`))

	// The side-specific classes follow from the content's side, so checking
	// the slide direction is checking that the content got told.
	testing.expect(t, strings.contains(left, "!-translate-x-full open:!translate-x-0"))

	right := rendered(t, proc() {
		{ sidebar({id = "m", side = .Right}) }
	})
	testing.expect_value(t, strings.count(right, `data-oh-sheet-side="right"`), 2)
	testing.expect(t, strings.contains(right, "!translate-x-full open:!translate-x-0"))
}

/* Two triggers, one per breakpoint: the mobile one opens the sheet by id, the
desktop one toggles the sidebar by target. */
@(test)
test_sidebar_trigger :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({target = "main"}) }
	})
	testing.expect(t, strings.contains(out, `data-oh-dialog-target="main-mobile"`))
	testing.expect(t, strings.contains(out, `class="contents md:hidden"`))
	testing.expect(t, strings.contains(out, `<div class="hidden md:block">`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar-trigger data-oh-sidebar-target="main"`))
	testing.expect_value(t, strings.count(out, `<span class="sr-only">Toggle Sidebar</span>`), 2)
}

/* trigger takes no children: what follows the call is a sibling. */
@(test)
test_sidebar_trigger_takes_no_children :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ trigger({target = "m"}) }
		h.text("after")
	})
	testing.expect(t, strings.has_suffix(out, "</div>after"))
}

/* Each region says which it is, and the four are otherwise plain wrappers. */
@(test)
test_sidebar_regions :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ header(); h.text("h") }
		{ content(); h.text("c") }
		{ footer(); h.text("f") }
		{group()
			{ group_label(); h.text("g") }
		}
	})
	testing.expect(t, strings.contains(out, `<div class="flex flex-col gap-2 p-2" data-oh-sidebar="header">h</div>`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar="content">c</div>`))
	testing.expect(
		t,
		strings.contains(out, `<div class="mt-auto flex flex-col gap-2 p-2" data-oh-sidebar="footer">f</div>`),
	)
	testing.expect(
		t,
		strings.contains(out, `<div class="relative flex w-full min-w-0 flex-col p-2" data-oh-sidebar="group">`),
	)
	testing.expect(t, strings.contains(out, `data-oh-sidebar="group-label">g</div>`))
}

/* A ul and li, so a menu is a list to a screen reader as well as to the eye. */
@(test)
test_sidebar_menu_is_a_list :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{menu()
			{ menu_item(); h.text("x") }
		}
	})
	testing.expect_value(
		t,
		out,
		`<ul class="flex w-full min-w-0 flex-col gap-1" data-oh-sidebar="menu">` +
		`<li class="group/menu-item relative" data-oh-sidebar="menu-item">x</li></ul>`,
	)
}

/* An href makes an anchor, no href a button -- the same split dropdown's item
makes. */
@(test)
test_sidebar_menu_button_element_follows_href :: proc(t: ^testing.T) {
	link := rendered(t, proc() {
			{ menu_button({href = "/s"}); h.text("Shelves") }
		})
	testing.expect(t, strings.has_prefix(link, `<a href="/s" class=`))
	testing.expect(
		t,
		strings.contains(link, `data-oh-sidebar="menu-button" data-oh-sidebar-size="default">Shelves</a>`),
	)

	button_out := rendered(t, proc() {
			{ menu_button(); h.text("Shelves") }
		})
	testing.expect(t, strings.has_prefix(button_out, `<button type="button" class=`))
	testing.expect(t, strings.has_suffix(button_out, "Shelves</button>"))
}

/* The size and the active state are attributes, read by data-[...] rules --
so a menu changes by attribute rather than by class. */
@(test)
test_sidebar_menu_button_size_and_active :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ menu_button({size = .Lg, is_active = true}); h.text("x") }
	})
	testing.expect(t, strings.contains(out, `data-oh-sidebar-size="lg"`))
	testing.expect(t, strings.contains(out, `data-oh-sidebar-active="true"`))

	// Absent rather than "false" when inactive, as upstream writes it.
	off := rendered(t, proc() {
		{ menu_button(); h.text("x") }
	})
	testing.expect(t, !strings.contains(off, "data-oh-sidebar-active"))
}

/* No tooltip prop -- see the file comment. The composition is the caller's. */
@(test)
test_sidebar_menu_button_has_no_tooltip :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ menu_button({href = "/s"}); h.text("Shelves") }
	})
	testing.expect(t, !strings.contains(out, "data-tui-popover"))
}

@(test)
test_sidebar_menu_badge :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ menu_badge(); h.text("4") }
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<span class="ml-auto flex h-5 min-w-5 items-center justify-center rounded-md px-1 text-xs font-medium bg-sidebar-accent text-sidebar-accent-foreground `,
		),
	)
	testing.expect(t, strings.has_suffix(out, `data-oh-sidebar="menu-badge">4</span>`))
}

@(test)
test_sidebar_menu_sub :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{menu_sub()
			{menu_sub_item()
				{menu_sub_button({href = "/a", is_active = true})
					h.text("A")}
			}
		}
	})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<ul class="mx-3.5 flex min-w-0 translate-x-px flex-col gap-1 border-l border-sidebar-border px-2.5 py-0.5 `,
		),
	)
	testing.expect(
		t,
		strings.contains(out, `<li class="group/menu-sub-item relative" data-oh-sidebar="menu-sub-item">`),
	)
	testing.expect(
		t,
		strings.contains(out, `<a href="/a" class="flex items-center gap-2 rounded-md px-2 py-1.5 text-sm `),
	)
	testing.expect(t, strings.contains(out, `data-oh-sidebar="menu-sub-button" data-oh-sidebar-active="true">A</a>`))
}

/* The sub button's two arms differ by w-full, which a button needs and an
anchor gets from being a flex child. */
@(test)
test_sidebar_menu_sub_button_widths :: proc(t: ^testing.T) {
	link := rendered(t, proc() {
		{ menu_sub_button({href = "/a"}); h.text("A") }
	})
	testing.expect(t, !strings.contains(link, "w-full"))

	button_out := rendered(t, proc() {
		{ menu_sub_button(); h.text("A") }
	})
	testing.expect(t, strings.contains(button_out, "flex w-full items-center"))
}

/* An hr, so it is a separator to a screen reader as well as a line -- and it
takes no children. */
@(test)
test_sidebar_separator :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ separator() }
		h.text("after")
	})
	testing.expect_value(
		t,
		out,
		`<hr class="mx-2 my-2 border-t border-sidebar-border" data-oh-sidebar="separator">after`,
	)
}

/* The page beside the sidebar: a <main>, and peer-data- rather than
group-data- because it is a sibling of the sidebar rather than inside it. */
@(test)
test_sidebar_inset :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ inset(); h.text("page") }
		})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<main class="relative flex w-full flex-1 flex-col bg-background md:peer-data-[oh-sidebar-variant=inset]:m-2`,
		),
	)
	testing.expect(t, strings.has_suffix(out, `data-oh-sidebar="inset">page</main>`))
}

@(test)
test_sidebar_ids_classes_and_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{sidebar({id = "m", class = "shadow"}, a.data("testid", "s"))
			{ header({id = "h", class = "pb-0"}, hx.get("/h")) }
		}
	})
	testing.expect(t, strings.contains(out, `<div class="group peer hidden md:block shadow"`))
	testing.expect(t, strings.contains(out, `style="--sidebar-width:16rem" data-testid="s">`))
	testing.expect(
		t,
		strings.contains(
			out,
			`<div id="h" class="flex flex-col gap-2 p-2 pb-0" data-oh-sidebar="header" hx-get="/h">`,
		),
	)
}

/* The structural contract (README.md, "The contract test"): sidebar.ts declares in
sidebar.contract.json everything it reads from this component's markup, and this
test asserts the rendered markup carries all of it. The manifest is consumed by
both sides -- the class imports it for its selectors, the attributes it reads
and writes, and the two state values it compares; this test reads it from disk
-- so neither side can drift from the declaration without the shared file
appearing in the diff.

The display assertion is the one thing beyond attributes: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in
the pre-upgrade window, where nothing else catches it. */

@(private = "file")
Contract :: struct {
	element:         string,
	display:         string,
	selectors:       map[string]string,
	attributes:      map[string]string,
	states:          map[string]string,
	collapsible_off: string `json:"collapsibleOff"`,
	mobile_query:    string `json:"mobileQuery"`,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/sidebar.contract.json"

/* The attribute a selector names. Two kinds are declared here: a bare attribute
(`[data-oh-sidebar-wrapper]`), and one compound selector -- an
attribute-with-value plus a child combinator, `[data-sidebar="sidebar"] > div`,
which is how the content finds its way back out of the mobile portal. The
combinator is dropped and the attribute asserted; the nesting it depends on is
pinned by test_sidebar_nesting rather than by a substring. */
@(private = "file")
selector_attr :: proc(selector: string) -> string {
	head := selector
	cut := strings.index(head, "] ")
	if cut >= 0 {
		head = head[:cut + 1]
	}
	return strings.trim(head, "[]")
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
test_sidebar_contract :: proc(t: ^testing.T) {
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

	/* A whole layout: the element's boundary, one sidebar with its mobile
	portal and its content, a trigger inside it, and the page beside it. Between
	them they carry every name the manifest declares. */
	out := rendered(t, proc() {
		{layout()
			{sidebar({id = "main"})
				{header()
					{ trigger({target = "main"}) }
				}
			}
			{ inset(); h.text("page") }
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

	// Every part the element selects by, and every attribute it reads or
	// writes, appears in the rendered markup.
	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
	for _, attr in contract.attributes {
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}

	// The expanded state is what a sidebar renders in by default; the element
	// compares against this exact string before writing the other one.
	expanded := fmt.tprintf(`%s="%s"`, contract.attributes["state"], contract.states["expanded"])
	testing.expectf(t, strings.contains(out, expanded), "markup lacks %s", expanded)

	/* The manifest's media query is the other half of the `md:` breakpoint this
	markup is written against -- the wrapper is `hidden md:block` and the mobile
	sheet `md:hidden` -- so 767px and Tailwind's md have to name the same edge.
	The query is not a string the markup contains; what is asserted is the pair
	it has to agree with. */
	testing.expect(t, contract.mobile_query != "")
	testing.expect(t, strings.contains(out, "group peer hidden md:block"))
	testing.expect(t, strings.contains(out, "md:hidden bg-sidebar"))

	// The collapsed state and the value that switches the element off, both
	// rendered by the Odin side and both compared by the class.
	off := rendered(t, proc() {
		{layout()
			{ sidebar({id = "main", collapsed = true, collapsible = .None}) }
		}
	})
	collapsed := fmt.tprintf(`%s="%s"`, contract.attributes["state"], contract.states["collapsed"])
	testing.expectf(t, strings.contains(off, collapsed), "markup lacks %s", collapsed)

	none := fmt.tprintf(`%s="%s"`, contract.attributes["collapsible"], contract.collapsible_off)
	testing.expectf(t, strings.contains(off, none), "markup lacks %s", none)
}
