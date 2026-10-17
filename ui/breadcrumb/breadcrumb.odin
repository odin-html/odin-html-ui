/* Breadcrumb, ported from templui's components/breadcrumb/breadcrumb.templ.

Six components and no state. The separator lives inside the item it precedes
rather than between items, which is upstream's shape and worth seeing before
reading the rest:

    {breadcrumb.breadcrumb()
        {breadcrumb.list()
            {breadcrumb.item()
                {breadcrumb.link({href = "/"}); h.text("Home")}
            }
            {breadcrumb.item()
                {breadcrumb.separator()}
                {breadcrumb.link({href = "/docs"}); h.text("Documentation")}
            }
            {breadcrumb.item()
                {breadcrumb.separator()}
                {breadcrumb.page(); h.text("Components")}
            }
        }
    }

Every one of them except separator() takes children, so those are _open
components and their braces are not optional -- see odin-html-builder's html/h/component.odin.
separator() writes a complete span and takes nothing, so its braces are the
ordinary void-element kind: they mark its extent and nothing else.

Three deviations from upstream, each for a reason.

Separator is two procs here rather than one with a UseCustom flag. The flag
selects between the caller's children and a default chevron, and that choice is
not expressible in this system: children are the caller's block, which always
runs, so no flag inside the component can suppress them. Passing children with
the flag unset would render both. Two procs make each case say what it is, and
make the combination that upstream silently ignores unwritable.

ItemProps.Current is dropped. It is never read upstream -- Item's markup does
not mention it and Page hardcodes aria-current -- yet upstream's own showcases
pass Current: true to Page as though it did something. A field that does nothing
is worse than no field, because the caller who sets it believes they marked the
current page. Page marks it unconditionally, which is what upstream renders too.

The chevron carries aria-hidden, which upstream's does not, for the same reason
accordion's does: it is punctuation between links and announcing it is noise.

`href` is written verbatim. templ wraps it in templ.SafeURL, which rejects a
javascript: scheme; package a has no equivalent yet, so an href built from user
input is an XSS here exactly as it is in button -- see that file's comment.

No TwMerge either, so a caller's class is appended rather than merged. */
package breadcrumb

import "html:html/a"
import "html:html/h"

import "ui:ui/icon"

/* One Props type per component, as upstream has them, minus the shared one:
upstream's Page borrows ItemProps, which is how ItemProps grew a field only Page
would have wanted. Kept separate so one component can gain a prop without the
others growing it. */
Props :: struct {
	id:    string,
	class: string,
}

List_Props :: struct {
	id:    string,
	class: string,
}

Item_Props :: struct {
	id:    string,
	class: string,
}

Link_Props :: struct {
	id:    string,
	class: string,
	href:  string,
}

Separator_Props :: struct {
	id:    string,
	class: string,
}

Page_Props :: struct {
	id:    string,
	class: string,
}

/* One constant per string literal upstream, so a diff against it still lines
up. */
@(private)
NAV_BASE :: "flex"
@(private)
LIST_BASE :: "flex items-center flex-wrap gap-1 text-sm"
@(private)
ITEM_BASE :: "flex items-center"
@(private)
LINK_BASE :: "text-muted-foreground hover:text-foreground hover:underline flex items-center gap-1.5 transition-colors"
@(private)
SEPARATOR_BASE :: "mx-2 text-muted-foreground"
@(private)
PAGE_BASE :: "font-medium text-foreground flex items-center gap-1.5"

/* The colour repeats what the separator span already sets. Upstream states it
on both and so does this: the icon is styled by its own class rather than by
inheritance, so a caller restyling the span does not silently take the icon
with it. */
@(private)
CHEVRON_CLASS :: "size-3.5 text-muted-foreground"

/* The landmark. aria-label is what makes it a *breadcrumb* nav rather than one
of possibly several unnamed navs on a page, so it is not decoration -- but attrs
is spread last, so a caller with two breadcrumbs can still relabel one. */
@(deferred_none = h.close_all)
breadcrumb :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.nav_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(NAV_BASE, props.class),
						a.aria("label", "Breadcrumb"),
					},
					attrs,
				),
			)
		}
	}
}

/* An ordered list, because the trail is a sequence and not a set: read without
styles it should still say first, second, third. */
@(deferred_none = h.close_all)
list :: proc(props := List_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.ol_open(
				..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(LIST_BASE, props.class)}, attrs),
			)
		}
	}
}

/* Holds the separator as well as the link, which is why the separator is a
child of the item rather than a sibling between items. */
@(deferred_none = h.close_all)
item :: proc(props := Item_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.li_open(
				..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(ITEM_BASE, props.class)}, attrs),
			)
		}
	}
}

/* An anchor with no href when none is given, as upstream renders it -- which is
not focusable and not a link, so it reads as text that happens to be blue. Give
it an href or use page() for the leaf. */
@(deferred_none = h.close_all)
link :: proc(props := Link_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.a_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.attr_if(props.href != "", a.href(props.href)),
						a.class(LINK_BASE, props.class),
					},
					attrs,
				),
			)
		}
	}
}

/* The default separator: a span and a chevron, complete, no children. Not an
_open component, so its block is the void-element kind -- {breadcrumb.separator()}
-- and nothing of the caller's lands inside it. */
separator :: proc(props := Separator_Props{}, attrs: ..a.Attr) {
	{h.span(..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(SEPARATOR_BASE, props.class)}, attrs))
		{ icon.icon(.Chevron_Right, {class = CHEVRON_CLASS}, a.aria("hidden", "true")) }
	}
}

/* The same span with the glyph left to the caller, which is upstream's
UseCustom branch. A separate proc rather than a flag because a flag could not
suppress the children -- see the file comment.

The caller owes it whatever separator() would have drawn, aria-hidden included;
nothing here can add it to markup it does not write. */
@(deferred_none = h.close_all)
separator_custom :: proc(props := Separator_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.span_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(SEPARATOR_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}

/* The leaf: the page you are on, so it is a span rather than a link and carries
aria-current unconditionally. That is what upstream renders, whatever its Current
field led its callers to believe. */
@(deferred_none = h.close_all)
page :: proc(props := Page_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.span_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(PAGE_BASE, props.class),
						a.aria("current", "page"),
					},
					attrs,
				),
			)
		}
	}
}
