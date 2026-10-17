/* Select box, ported from templui's components/selectbox/selectbox.templ.

A dropdown built out of divs rather than a <select>, so it can hold a search
box, groups, pills and a tick beside the chosen row:

    {selectbox.selectbox()
        {selectbox.trigger({name = "shelf"})
            {selectbox.value({placeholder = "Pick a shelf"})}
        }
        {selectbox.content()
            {selectbox.group()
                {selectbox.label(); h.text("Warehouse A")}
                {selectbox.item({value = "a1"}); h.text("Shelf A1")}
                {selectbox.item({value = "a2", selected = true}); h.text("Shelf A2")}
            }
        }
    }

All seven take children and all seven need braces at the call site.

## What posts, and what the element does

A hidden input inside the trigger carries the value; the <oh-selectbox> element
(web/src/ui/selectbox.ts) writes into it as rows are clicked, and mirrors the
chosen row's text into value(). So a rendered page posts whatever was marked
`selected` here, and everything after that is the element's.

Opening, light dismiss and Escape are the popover's, which is to say the
browser's -- with one scoped exception: with a search
box, the first Escape belongs to the field (clearing what was typed) and only
the second closes. The element cancels the native close by preventDefault on
that one keydown, which was measured to be cancelable. The old
disable_esc plumbing through popover is gone; the content is a plain
popover="auto" and matches the trigger's width by anchor-size(), which retired
the measured-width sync the script used to do.

The tick beside a row is a group-data-[...] rule reading the row's own
data-oh-selectbox-selected, so marking a row is one attribute rather than a
class swap.

## Two components write after their children

item() puts the caller's text in a truncating span and then the tick after it,
and trigger() writes the hidden input before the children and the clear and
chevron buttons after them. Neither is expressible with the ordinary pairing,
which closes everything at once -- so both defer a proc of their own, the same
shape popover's arrow uses.

## Multiple

multiple and show_pills are the script's to act on: nothing here renders a pill
or more than one tick. show_pills implies multiple, as upstream has it, so the
two cannot disagree.

## content

The rows are the caller's children and are rendered in full; the search filters
them in the browser.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package selectbox

import "core:strings"

import "html:html/a"
import "html:html/h"

import "ui:ui/button"
import "ui:ui/icon"
import "ui:ui/input"
import "ui:ui/popover"

Props :: struct {
	id:       string,
	class:    string,

	// Unused by the markup -- the trigger's own flag is what the script
	// reads. Kept because upstream has it.
	multiple: bool,
}

Trigger_Props :: struct {
	id:                  string,
	class:               string,
	name:                string,
	form:                string,
	disabled:            bool,
	has_error:           bool,
	multiple:            bool,

	// Implies multiple.
	show_pills:          bool,

	// Caption for a collapsed multiple selection, e.g. "%d selected".
	selected_count_text: string,
}

Value_Props :: struct {
	id:          string,
	class:       string,
	placeholder: string,

	// Unused by the markup, as upstream's is.
	multiple:    bool,
}

Content_Props :: struct {
	id:                 string,
	class:              string,

	// Drops the search box, and with it the Escape-clears-first behaviour.
	no_search:          bool,
	search_placeholder: string,
}

Group_Props :: struct {
	id:    string,
	class: string,
}

Label_Props :: struct {
	id:    string,
	class: string,
}

Item_Props :: struct {
	id:       string,
	class:    string,
	value:    string,
	selected: bool,
	disabled: bool,
}

/* The old select-container/select-trigger/select-item class hooks are gone:
the element queries data-oh-selectbox-* roles, per the split vocabulary, and
the classes below are utilities only. */
@(private)
ROOT_BASE :: "w-full relative"

@(private)
GROUP_BASE :: "p-1"
@(private)
LABEL_BASE :: "px-2 py-1.5 text-sm font-medium"

/* One constant per string literal upstream, in upstream's order. */
@(private)
ITEM_BASE ::
	"group relative flex w-full cursor-default select-none items-center " +
	"rounded-sm py-1.5 px-2 text-sm font-light outline-none"
@(private)
ITEM_HOVER :: "hover:bg-accent hover:text-accent-foreground"
@(private)
ITEM_FOCUS :: "focus-visible:bg-accent focus-visible:text-accent-foreground"
@(private)
ITEM_SELECTED ::
	"data-[oh-selectbox-selected=true]:bg-accent " + "data-[oh-selectbox-selected=true]:text-accent-foreground"
@(private)
ITEM_DISABLED :: "pointer-events-none opacity-50"

@(private)
ITEM_TEXT :: "truncate"
@(private)
ITEM_CHECK :: "absolute right-2 flex h-3.5 w-3.5 items-center justify-center opacity-0"
@(private)
ITEM_CHECK_SHOWN :: "group-data-[oh-selectbox-selected=true]:opacity-100"
@(private)
ITEM_CHECK_ICON :: "size-4"

/* The same list datepicker's and timepicker's triggers carry -- a button
dressed as an input. */
@(private)
TRIGGER_BASE :: "w-full h-9 px-3 py-1 text-base md:text-sm"
@(private)
TRIGGER_LAYOUT :: "flex items-center justify-between"
@(private)
TRIGGER_BOX ::
	"rounded-md border border-input bg-transparent shadow-xs " + "transition-[color,box-shadow] outline-none"
@(private)
TRIGGER_DARK :: "dark:bg-input/30"
@(private)
TRIGGER_SELECTION :: "selection:bg-primary selection:text-primary-foreground"
@(private)
TRIGGER_FOCUS :: "focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]"
@(private)
TRIGGER_INVALID ::
	"aria-invalid:ring-destructive/20 aria-invalid:border-destructive " + "dark:aria-invalid:ring-destructive/40"
@(private)
TRIGGER_ERROR :: "border-destructive ring-destructive/20 dark:ring-destructive/40"

@(private)
CLEAR_CLASS :: "ml-1 hidden cursor-pointer text-muted-foreground hover:text-foreground"
@(private)
CLEAR_ICON :: "size-3.5"
@(private)
CHEVRON_WRAPPER :: "pointer-events-none ml-1"
@(private)
CHEVRON_ICON :: "size-4 text-muted-foreground"

@(private)
VALUE_BASE :: "block truncate text-muted-foreground"

/* anchor-size() matches the list to the trigger's width -- the anchor is the
trigger button, per popover's anchoring -- which is what the old script
measured and copied on every open. */
@(private)
CONTENT_BASE ::
	"p-1 z-50 overflow-hidden rounded-md border bg-popover " +
	"text-popover-foreground shadow-md " +
	"w-[anchor-size(width)] min-w-[anchor-size(width)]"
@(private)
CONTENT_OFFSET :: 4

@(private)
SEARCH_STICKY :: "sticky top-0 bg-popover p-1"
@(private)
SEARCH_RELATIVE :: "relative"
@(private)
SEARCH_ICON_WRAPPER :: "absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground z-10 pointer-events-none"
@(private)
SEARCH_ICON :: "size-4"
@(private)
SEARCH_INPUT_CLASS :: "pl-8"
@(private)
DEFAULT_SEARCH_PLACEHOLDER :: "Search..."

/* The rows scroll inside the popover rather than the popover growing. Written
raw because the tick-and-close ordering below needs it closed by hand -- see
content_close. */
@(private)
ROWS_CLASS :: "max-h-[300px] overflow-y-auto"
@(private)
ROWS_OPEN :: `<div class="` + ROWS_CLASS + `">`
@(private)
ROWS_CLOSE :: "</div>"

@(private)
bool_attr :: proc(b: bool) -> string {
	return b ? "true" : "false"
}

/* button's and popover's Props.class are strings rather than attribute lists,
so the parts are joined by hand. Into the temp allocator, which is the render
arena. */
@(private)
joined :: proc(parts: ..string) -> string {
	kept := make([dynamic]string, 0, len(parts) * 2, context.temp_allocator)
	for p in parts {
		if p == "" {
			continue
		}
		if len(kept) > 0 {
			append(&kept, " ")
		}
		append(&kept, p)
	}
	return strings.concatenate(kept[:], context.temp_allocator)
}

/* Three elements: the <oh-selectbox> boundary, the container div (the
component's own box, so the wrapper is `contents`), and popover's root inside
it. All close at the end of the caller's block. */
@(deferred_none = h.close_all)
selectbox :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.elem_open("oh-selectbox", a.class("contents"))
			{h.div_open(
					..a.join(
						[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(ROOT_BASE, props.class)},
						attrs,
					),
				)
				popover.root_open()
			}
		}
	}
}

@(deferred_none = h.close_all)
group :: proc(props := Group_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(GROUP_BASE, props.class),
						a.role("group"),
					},
					attrs,
				),
			)
		}
	}
}

/* A caption for a group, and a span rather than a <label> -- it labels nothing
focusable. */
@(deferred_none = h.close_all)
label :: proc(props := Label_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.span_open(
				..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(LABEL_BASE, props.class)}, attrs),
			)
		}
	}
}

/* One row. The caller's text goes in a truncating span and the tick follows it
-- see item_close, which is the whole reason this one defers a proc of its
own. */
@(deferred_none = item_close)
item :: proc(props := Item_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(
							ITEM_BASE,
							ITEM_HOVER,
							ITEM_FOCUS,
							ITEM_SELECTED,
							props.disabled ? ITEM_DISABLED : "",
							props.class,
						),
						a.role("option"),
						a.data("oh-selectbox-item", true),
						a.data("oh-selectbox-value", props.value),
						a.data("oh-selectbox-selected", bool_attr(props.selected)),
						a.data("oh-selectbox-disabled", bool_attr(props.disabled)),
						a.tabindex("0"),
					},
					attrs,
				),
			)
			h.raw(ITEM_TEXT_OPEN)
		}
	}
}

@(private)
ITEM_TEXT_OPEN :: `<span class="` + ITEM_TEXT + `" data-oh-selectbox-item-text>`
@(private)
ITEM_TEXT_CLOSE :: "</span>"

/* Runs at the end of the caller's block: the row's text is written and the
span around it is still open. Closing it by hand is what lets the tick be a
sibling of the text rather than part of it, which is what the truncate needs. */
@(private)
item_close :: proc() {
	h.raw(ITEM_TEXT_CLOSE)

	{h.span(a.class(ITEM_CHECK, ITEM_CHECK_SHOWN))
		{ icon.icon(.Check, {class = ITEM_CHECK_ICON}) }
	}

	h.close_all()
}

/* popover's trigger, a button, and the hidden input that posts -- then the
caller's children, then the clear and the chevron. See trigger_close. */
@(deferred_none = trigger_close)
trigger :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	multiple := props.multiple || props.show_pills

	{h.open_scope()
		popover.trigger_open({trigger_type = .Click})
		button.open(
			{
				id = props.id,
				type = .Button,
				variant = .Outline,
				class = joined(
					TRIGGER_BASE,
					TRIGGER_LAYOUT,
					TRIGGER_BOX,
					TRIGGER_DARK,
					TRIGGER_SELECTION,
					TRIGGER_FOCUS,
					TRIGGER_INVALID,
					props.has_error ? TRIGGER_ERROR : "",
					props.class,
				),
				disabled = props.disabled,
			},
			a.data("oh-selectbox-trigger", true),
			a.data("oh-selectbox-multiple", bool_attr(multiple)),
			a.data("oh-selectbox-show-pills", bool_attr(props.show_pills)),
			a.data("oh-selectbox-selected-count-text", props.selected_count_text),
			a.tabindex("0"),
			a.attr_if(props.has_error, a.aria("invalid", "true")),
		)

		/* The caller's attributes land here rather than on the button, as
		upstream puts them: the input is the thing that posts. */
		{h.input(
				..a.join(
					[]a.Attr {
						a.type("hidden"),
						a.attr_if(props.name != "", a.name(props.name)),
						a.attr_if(props.form != "", a.form(props.form)),
						a.data("oh-selectbox-hidden-input", true),
					},
					attrs,
				),
			)
		}
	}
}

/* Runs at the end of the caller's block: the value span is written and the
button is still open, which is where the clear and the chevron belong -- after
the caption and inside the control. */
@(private)
trigger_close :: proc() {
	{h.span(
			a.class(CLEAR_CLASS),
			a.data("oh-selectbox-clear-trigger", true),
			a.aria("label", "Clear selection"),
			a.role("button"),
		)
		{ icon.icon(.Circle_X, {class = CLEAR_ICON}) }
	}

	{h.span(a.class(CHEVRON_WRAPPER), a.data("oh-selectbox-chevron", true))
		{ icon.icon(.Chevron_Down, {class = CHEVRON_ICON}) }
	}

	h.close_all()
}

/* The caption. The placeholder is rendered as text so it shows before any
script runs, and kept in a data attribute so selectbox.ts can put it back when
the selection is cleared. */
@(deferred_none = h.close_all)
value :: proc(props := Value_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.span_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(VALUE_BASE, props.class),
						a.data("oh-selectbox-display", true),
						a.attr_if(props.placeholder != "", a.data("oh-selectbox-placeholder", props.placeholder)),
					},
					attrs,
				),
			)
			if props.placeholder != "" {
				h.text(props.placeholder)
			}
		}
	}
}

/* Returns show_arrow for the deferred half -- popover's own flag, which is
always false here since a select box has no arrow. */
@(deferred_out = content_close)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) -> popover.Content_State {
	state: popover.Content_State

	{h.open_scope()
		state = popover.content_open(
			{
				id = props.id,
				class = joined(CONTENT_BASE, props.class),
				placement = .Bottom_Start,
				offset = CONTENT_OFFSET,
			},
			..a.join([]a.Attr{a.role("listbox"), a.tabindex("-1"), a.data("oh-selectbox-content", "true")}, attrs),
		)

		if !props.no_search {
			search_box(props.search_placeholder)
		}

		// The blank line above is load bearing: an element block directly
		// under the close of an if trips -strict-style, which reads it as an
		// else.
		h.raw(ROWS_OPEN)
	}
	return state
}

/* Three closes in order: the scrolling list, popover's own inner wrapper, and
then back to the mark. Written by hand because they interleave -- close_all
would emit all of them at once and put popover's wrapper inside the list. */
@(private)
content_close :: proc(state: popover.Content_State) {
	h.raw(ROWS_CLOSE)
	popover.content_trailing(state)
	h.close_all()
}

/* Sticky, so it stays put while the rows scroll under it. The magnifier is
absolutely positioned over the field's left padding rather than inside it. */
@(private)
search_box :: proc(placeholder: string) {
	{h.div(a.class(SEARCH_STICKY))
		{h.div(a.class(SEARCH_RELATIVE))
			{h.span(a.class(SEARCH_ICON_WRAPPER))
				{ icon.icon(.Search, {class = SEARCH_ICON}) }
			}

			{input.input(
					{
						type = .Search,
						class = SEARCH_INPUT_CLASS,
						placeholder = placeholder != "" ? placeholder : DEFAULT_SEARCH_PLACEHOLDER,
					},
					a.data("oh-selectbox-search", ""),
				)}
		}
	}
}
