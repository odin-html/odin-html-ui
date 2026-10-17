/* Tests for avatar, in the package and beside the component -- see the file
comment in accordion/accordion_test.odin for why the class tables below are
restated rather than referenced. */
package avatar

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
AV :: "relative flex h-10 w-10 shrink-0 overflow-hidden rounded-full"
@(private = "file")
IMG :: "aspect-square h-full w-full"
@(private = "file")
FB :: "flex h-full w-full items-center justify-center rounded-full bg-muted"

/* Image then fallback, both written: avatar.ts hides the loser once the image
resolves, so the markup carries both and the element picks. */
@(test)
test_avatar_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{avatar()
			{ image({src = "/ada.png", alt = "Ada"}) }
			{ fallback(); h.text("AL") }
		}
	})
	testing.expect_value(
		t,
		out,
		`<oh-avatar class="contents"><div data-oh-avatar class="` +
		AV +
		`"><img data-oh-avatar-image src="/ada.png" alt="Ada" class="` +
		IMG +
		`"><span data-oh-avatar-fallback class="` +
		FB +
		`">AL</span></div></oh-avatar>`,
	)
}

/* A user with no photo: the fallback alone is a complete avatar, and nothing
in the component requires the image to be there. */
@(test)
test_avatar_fallback_only :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{avatar()
				{ fallback(); h.text("GO") }
			}
		})
	testing.expect_value(
		t,
		out,
		`<oh-avatar class="contents"><div data-oh-avatar class="` +
		AV +
		`"><span data-oh-avatar-fallback class="` +
		FB +
		`">GO</span></div></oh-avatar>`,
	)
}

/* The image is a void element: no closing tag, and its braces mark its extent
rather than deferring anything. What follows it is a sibling. */
@(test)
test_avatar_image_is_void :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ image({src = "/a.png", alt = "A"}) }
			h.text("after")
		})
	testing.expect_value(t, out, `<img data-oh-avatar-image src="/a.png" alt="A" class="` + IMG + `">after`)
}

/* alt is written even when empty -- alt="" marks the image decorative, where
no alt at all leaves a screen reader to read the file name out. */
@(test)
test_avatar_image_alt_always_written :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ image({src = "/a.png"}) }
	})
	testing.expect(t, strings.contains(out, ` alt=""`))
}

/* src, unlike alt, is omitted when empty: an img with src="" re-requests the
current page in some engines. */
@(test)
test_avatar_image_src_omitted_when_empty :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ image({alt = "A"}) }
	})
	testing.expect(t, !strings.contains(out, "src="))
}

@(test)
test_avatar_ids_and_classes :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{avatar({id = "a", class = "size-16"})
			{ image({id = "a-img", src = "/a.png", alt = "A", class = "grayscale"}) }
			{ fallback({id = "a-fb", class = "text-xs"}); h.text("A") }
		}
	})
	testing.expect(
		t,
		strings.has_prefix(out, `<oh-avatar class="contents"><div data-oh-avatar id="a" class="` + AV + ` size-16">`),
	)
	testing.expect(
		t,
		strings.contains(
			out,
			`<img data-oh-avatar-image id="a-img" src="/a.png" alt="A" class="` + IMG + ` grayscale">`,
		),
	)
	testing.expect(
		t,
		strings.contains(out, `<span data-oh-avatar-fallback id="a-fb" class="` + FB + ` text-xs">A</span>`),
	)
}

@(test)
test_avatar_extra_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{avatar({}, hx.get("/u/1"), a.data("testid", "av"))
				{ fallback(); h.text("A") }
			}
		})
	testing.expect(
		t,
		strings.has_prefix(
			out,
			`<oh-avatar class="contents"><div data-oh-avatar class="` + AV + `" hx-get="/u/1" data-testid="av">`,
		),
	)
}

/* Two avatars are siblings, and both tags the component opens close at the end
of its own block rather than swallowing what comes after -- the wrapper and the
frame, innermost first. */
@(test)
test_avatar_two_are_siblings :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{avatar()
				{ fallback(); h.text("A") }
			}
			{avatar()
				{ fallback(); h.text("B") }
			}
		})
	testing.expect_value(t, strings.count(out, `<oh-avatar class="contents"><div data-oh-avatar `), 2)
	testing.expect(
		t,
		strings.contains(out, `</span></div></oh-avatar><oh-avatar class="contents"><div data-oh-avatar `),
	)
}

/* The structural contract (README.md, "The contract test"): avatar.ts declares in
avatar.contract.json everything it reads from this component's markup, and this
test asserts the rendered markup carries all of it. The manifest is consumed by
both sides -- the class imports it for the image's and the fallback's selectors;
this test reads it from disk -- so neither side can drift from the declaration
without the shared file appearing in the diff.

Both roles are declared because the element needs both: the image is what it
listens for and the fallback is what it hides or shows, and an avatar missing
either is one the element can only half-decide.

The display assertion is the one thing beyond attributes: a wrapper without an
explicit display utility defaults to display:inline and breaks layout only in
the pre-upgrade window, where nothing else catches it. */

@(private = "file")
Contract :: struct {
	element:   string,
	display:   string,
	selectors: map[string]string,
}

@(private = "file")
CONTRACT_PATH :: #directory + "/../../web/src/ui/avatar.contract.json"

/* The attribute a selector names: "[data-oh-avatar-image]" names
data-oh-avatar-image. Every selector this component declares is of that one kind
-- the contract keeps CSS selector syntax because the TS side feeds it to
querySelector and to Element.matches verbatim. */
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
test_avatar_contract :: proc(t: ^testing.T) {
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

	// The full avatar -- image and fallback both written -- is the shape the
	// element acts on, and the only one carrying every declared role.
	out := rendered(t, proc() {
		{avatar()
			{ image({src = "/ada.png", alt = "Ada"}) }
			{ fallback(); h.text("AL") }
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

	// Every attribute the element selects by appears in the rendered markup.
	for _, selector in contract.selectors {
		attr := selector_attr(selector)
		testing.expectf(t, strings.contains(out, attr), "markup lacks %s", attr)
	}
}
