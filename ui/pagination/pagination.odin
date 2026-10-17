/* Pagination, ported from templui's components/pagination/pagination.templ.

Seven components and one calculation. The components are a nav, a list, its
items, and three kinds of control -- a numbered link, a previous, a next -- plus
an ellipsis for the gap. The calculation is which page numbers to show, which is
the only part with any logic in it and is exported on its own so a handler can
use it without rendering anything.

    r := pagination.pages(current, total, 5)
    {pagination.pagination()
        {pagination.content()
            {pagination.item()
                {pagination.previous({href = "?p=1", disabled = !r.has_previous})}
            }
            for n in r.pages {
                {pagination.item()
                    {pagination.link({href = fmt.tprintf("?p=%d", n), is_active = n == r.current})
                        h.textf("%d", n)
                    }
                }
            }
            {pagination.item()
                {pagination.next({href = "?p=2", disabled = !r.has_next})}
            }
        }
    }

Which of these take children is not uniform, because upstream's are not. The
nav, the list, the item and the numbered link do -- those are _open components
and their braces are not optional. previous(), next() and ellipsis() write
themselves completely and take none, so their braces are the void-element kind.

The three controls are buttons: ghost, and icon-sized for the numbers, with the
active page rendered as an outline instead. link() is why button gained an
open() -- see the comment there. It cannot call button() itself, because that
would close the tag at the end of link's own body rather than after the caller
has written the page number.

Upstream's ContentProps.Class and ItemProps.Class are dropped. Neither reaches
the markup: Content writes a fixed class attribute and Item writes none at all,
so both fields are settable and inert. As with breadcrumb's Current, a field
that does nothing is worse than no field.

No TwMerge, so a caller's class is appended rather than merged. */
package pagination

import "core:strings"

import "html:html/a"
import "html:html/h"

import "ui:ui/button"
import "ui:ui/icon"

Props :: struct {
	id:    string,
	class: string,
}

/* No class field, and neither has Item_Props: upstream has them and neither is
read. */
Content_Props :: struct {
	id: string,
}

Item_Props :: struct {
	id: string,
}

Link_Props :: struct {
	id:        string,
	class:     string,
	href:      string,
	is_active: bool,
	disabled:  bool,
}

Previous_Props :: struct {
	id:       string,
	class:    string,
	href:     string,
	disabled: bool,
	label:    string,
}

Next_Props :: struct {
	id:       string,
	class:    string,
	href:     string,
	disabled: bool,
	label:    string,
}

@(private)
NAV_BASE :: "flex flex-wrap justify-center"
@(private)
CONTENT_BASE :: "flex flex-row items-center gap-1"
@(private)
CONTROL_BASE :: "gap-1"
@(private)
ICON_CLASS :: "size-4"

/* role and aria-label together are what make this a named landmark rather than
another unlabelled nav. attrs is spread last, so a page with two of them can
relabel one. */
@(deferred_none = h.close_all)
pagination :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.nav_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.role("navigation"),
						a.aria("label", "pagination"),
						a.class(NAV_BASE, props.class),
					},
					attrs,
				),
			)
		}
	}
}

/* A ul, so the controls are a list of alternatives rather than a row of
buttons that happen to be adjacent. */
@(deferred_none = h.close_all)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.ul_open(..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(CONTENT_BASE)}, attrs))
		}
	}
}

/* Carries no class of its own, as upstream's does not: the item is structure,
and the control inside it is what is styled. */
@(deferred_none = h.close_all)
item :: proc(props := Item_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.li_open(..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id))}, attrs))
		}
	}
}

/* The page number itself. Active means outline rather than ghost, which is the
whole of "you are here" visually -- so a caller wanting it announced as well
should pass aria-current through attrs.

Disabled drops the href, because button() renders a <button> rather than an <a>
when disabled and an anchor cannot be disabled at all. */
@(deferred_none = h.close_all)
link :: proc(props := Link_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		if props.disabled {
			button.open({id = props.id, disabled = true, size = .Icon, variant = .Ghost, class = props.class}, ..attrs)
		} else {
			button.open(
				{
					id = props.id,
					href = props.href,
					size = .Icon,
					variant = props.is_active ? .Outline : .Ghost,
					class = props.class,
				},
				..attrs,
			)
		}
	}
}

/* Complete, and takes no children: the chevron and the optional label are all
of it. Calling button() here is the ordinary use -- the close lands at the end
of this block, which is after the content is written. */
previous :: proc(props := Previous_Props{}, attrs: ..a.Attr) {
	{button.button(
			{
				id = props.id,
				href = props.href,
				disabled = props.disabled,
				variant = .Ghost,
				class = joined(CONTROL_BASE, props.class),
			},
			..attrs,
		)
		{ icon.icon(.Chevron_Left, {class = ICON_CLASS}, a.aria("hidden", "true")) }
		if props.label != "" {
			{ h.span(); h.text(props.label) }
		}
	}
}

next :: proc(props := Next_Props{}, attrs: ..a.Attr) {
	{button.button(
			{
				id = props.id,
				href = props.href,
				disabled = props.disabled,
				variant = .Ghost,
				class = joined(CONTROL_BASE, props.class),
			},
			..attrs,
		)
		if props.label != "" {
			{ h.span(); h.text(props.label) }
		}

		// The blank line above is load bearing: an element block directly under
		// the close of an if trips -strict-style, which reads it as an else.
		{ icon.icon(.Chevron_Right, {class = ICON_CLASS}, a.aria("hidden", "true")) }
	}
}

/* Props.class on button is a string rather than an attribute list, so a
component adding to it joins by hand. Into the temp allocator, which is the
render arena and freed with the page -- the same place a.class clones into. */
@(private)
joined :: proc(base, extra: string) -> string {
	if extra == "" {
		return base
	}
	return strings.concatenate({base, " ", extra}, context.temp_allocator)
}

/* The gap in a long trail. aria-hidden is not upstream's: three dots announce
nothing a screen reader needs, and the pages either side of them are already
links. */
ellipsis :: proc() {
	{ icon.icon(.Ellipsis, {class = ICON_CLASS}, a.aria("hidden", "true")) }
}

/* What pages() returns. Separate from the components on purpose: a handler
usually wants current and total for a query before anything is rendered. */
Pages :: struct {
	current:      int,
	total:        int,
	pages:        []int,
	has_previous: bool,
	has_next:     bool,
}

/* The visible window of page numbers, upstream's CreatePagination.

Clamps as upstream does -- a current page below one or past the total is pulled
into range, a total below one becomes one, a max_visible below one becomes five
-- so a handler can pass a query parameter straight in.

One upstream behaviour worth knowing before choosing max_visible: the window is
centred by taking half on each side, and for an even max_visible that is one
page wider than asked for. Four gives five numbers. Odd values give what they
say.

The slice is allocated in the temp allocator by default, which is the render
arena for a page and freed with it. */
pages :: proc(current, total, max_visible: int, allocator := context.temp_allocator) -> (result: Pages) {
	current, total, max_visible := current, total, max_visible

	if total < 1 {
		total = 1
	}
	if current < 1 {
		current = 1
	}
	if current > total {
		current = total
	}
	if max_visible < 1 {
		max_visible = 5
	}

	start, end := visible_range(current, total, max_visible)

	list := make([]int, end - start + 1, allocator)
	for i in start ..= end {
		list[i - start] = i
	}

	return {current = current, total = total, pages = list, has_previous = current > 1, has_next = current < total}
}

/* Centre the window on the current page, then push it back inside the range if
either end fell out. Kept as a separate proc, as upstream has it, because the
clamping above and the windowing here fail in different ways. */
@(private)
visible_range :: proc(current, total, max_visible: int) -> (start: int, end: int) {
	if total <= max_visible {
		return 1, total
	}

	half := max_visible / 2
	start, end = current - half, current + half

	if start < 1 {
		end += 1 - start
		start = 1
	}

	if end > total {
		start -= end - total
		if start < 1 {
			start = 1
		}
		end = total
	}

	return start, end
}
