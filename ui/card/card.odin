/* Card, ported from templui's components/card/card.templ.

Six components, all of them a wrapper and nothing else: the card, a header, a
title, a description, a body and a footer.

    {card.card()
        {card.header()
            {card.title(); h.text("Bearing 6203")}
            {card.description(); h.text("Last serviced in March")}
        }
        {card.content()
            {h.p(); h.text("Running warm since the last inspection.")}
        }
        {card.footer()
            {button.button({size = .Sm}); h.text("Open")}
        }
    }

All six take children, so all six are _open components and the braces at the
call site are not optional -- see odin-html-builder's html/h/component.odin.

The padding is split across three of them rather than owned by the card: the
header pads all round but not at the bottom, the body pads all round, and the
footer pads all round but not at the top. That is what makes a header directly
above a body look right, and it is also why a card holding only a header has
noticeably less space beneath its text than above it. Nothing is wrong when that
happens; add a body, or pad the header yourself.

None of the six is required by any other, and the card does not check what it
holds. A title outside a header renders, unpadded; a footer with no body sits
directly under the header. Upstream is the same.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package card

import "html:html/a"
import "html:html/h"

/* Six Props types with the same two fields, as upstream has them. Kept separate
rather than shared so one component can gain a prop without the other five
growing it. */
Props :: struct {
	id:    string,
	class: string,
}

Header_Props :: struct {
	id:    string,
	class: string,
}

Title_Props :: struct {
	id:    string,
	class: string,
}

Description_Props :: struct {
	id:    string,
	class: string,
}

Content_Props :: struct {
	id:    string,
	class: string,
}

Footer_Props :: struct {
	id:    string,
	class: string,
}

/* One constant per string literal upstream, so a diff against it still lines
up. */
@(private)
CARD_BASE :: "w-full rounded-lg border bg-card text-card-foreground shadow-xs"
@(private)
HEADER_BASE :: "flex flex-col space-y-1.5 p-6 pb-0"
@(private)
TITLE_BASE :: "text-lg font-semibold leading-none tracking-tight"
@(private)
DESCRIPTION_BASE :: "text-sm text-muted-foreground"
@(private)
CONTENT_BASE :: "p-6"
@(private)
FOOTER_BASE :: "flex items-center p-6 pt-0"

/* w-full, so a card fills its column and is sized by what it is put in rather
than by itself. A row of cards wants a grid around them, not widths on them. */
@(deferred_none = h.close_all)
card :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(CARD_BASE, props.class)}, attrs),
			)
		}
	}
}

@(deferred_none = h.close_all)
header :: proc(props := Header_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(HEADER_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}

/* h3, as upstream has it. The level is fixed and will be wrong in some
documents; a caller who cares writes the heading itself and keeps the class. */
@(deferred_none = h.close_all)
title :: proc(props := Title_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.h3_open(
				..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(TITLE_BASE, props.class)}, attrs),
			)
		}
	}
}

/* A p, so it cannot hold another p -- the parser would close this one at the
opening tag of the next. Text, or spans, or nothing. */
@(deferred_none = h.close_all)
description :: proc(props := Description_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.p_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(DESCRIPTION_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
content :: proc(props := Content_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(CONTENT_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
footer :: proc(props := Footer_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(FOOTER_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}
