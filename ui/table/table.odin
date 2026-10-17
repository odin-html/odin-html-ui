/* Table, ported from templui's components/table/table.templ.

Eight components, one per table element: the table, thead, tbody, tfoot, tr, th,
td and the caption. All eight take children, so all eight are _open components
and the braces at the call site are not optional.

    {table.table()
        {table.header()
            {table.row()
                {table.head(); h.text("Asset")}
                {table.head(); h.text("State")}
            }
        }
        {table.body()
            for p in pumps {
                {table.row({selected = p.id == current})
                    {table.cell(); h.text(p.name)}
                    {table.cell(); h.text(p.state)}
                }
            }
        }
    }

Nothing here enforces table structure -- a cell outside a row renders, and the
browser's parser will move it or drop it. That is upstream's position too, and
the reason a loop over rows reads cleanly: the components are the tags, and the
shape is the caller's.

Three of the class lists reach across elements rather than styling their own,
which is what makes the borders come out right and also what makes them break
if a caller replaces the class instead of adding to it. The header draws a
bottom border on every row inside it, the body removes it from the last row, and
the footer removes it from its own last row.

Row.selected does two things: it writes a bare data attribute and it adds the
class that reads that attribute. Both are conditional on the same flag, so as
rendered it is the same as adding a background outright -- the indirection buys
a hook rather than a behaviour. Kept as upstream has it, since the attribute is
the part something else might look for.

No TwMerge, so a caller's class is appended rather than merged. */
package table

import "html:html/a"
import "html:html/h"

Props :: struct {
	id:    string,
	class: string,
}

Header_Props :: struct {
	id:    string,
	class: string,
}

Body_Props :: struct {
	id:    string,
	class: string,
}

Footer_Props :: struct {
	id:    string,
	class: string,
}

Row_Props :: struct {
	id:       string,
	class:    string,
	selected: bool,
}

Head_Props :: struct {
	id:    string,
	class: string,
}

Cell_Props :: struct {
	id:    string,
	class: string,
}

Caption_Props :: struct {
	id:    string,
	class: string,
}

/* One constant per string literal upstream, so a diff against it still lines
up. */
@(private)
TABLE_BASE :: "w-full caption-bottom text-sm"
@(private)
HEADER_BASE :: "[&_tr]:border-b"
@(private)
BODY_BASE :: "[&_tr:last-child]:border-0"
@(private)
FOOTER_BASE :: "border-t bg-muted/50 font-medium [&>tr]:last:border-b-0"
@(private)
ROW_BASE :: "border-b transition-colors hover:bg-muted/50"
@(private)
ROW_SELECTED :: "data-[tui-table-state-selected]:bg-muted"
@(private)
HEAD_BASE :: "h-10 px-2 text-left align-middle font-medium text-muted-foreground"
@(private)
CELL_BASE :: "p-2 align-middle"
@(private)
CAPTION_BASE :: "mt-4 text-sm text-muted-foreground"

/* Upstream writes this same string into both th and td. One constant used
twice rather than two identical ones, since a change to either would be a
change to both: it tightens a cell around a checkbox and nudges the box onto
the text's baseline. */
@(private)
CHECKBOX_FIT :: "[&:has([role=checkbox])]:pr-0 [&>[role=checkbox]]:translate-y-[2px]"

/* caption-bottom, so a caption renders under the table wherever it is written
in the markup -- which is why upstream's caption carries a top margin rather
than a bottom one. */
@(deferred_none = h.close_all)
table :: proc(props := Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.table_open(
				..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(TABLE_BASE, props.class)}, attrs),
			)
		}
	}
}

@(deferred_none = h.close_all)
header :: proc(props := Header_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.thead_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(HEADER_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
body :: proc(props := Body_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.tbody_open(
				..a.join([]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(BODY_BASE, props.class)}, attrs),
			)
		}
	}
}

@(deferred_none = h.close_all)
footer :: proc(props := Footer_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.tfoot_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(FOOTER_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}

/* a.data with a bool renders bare when true and nothing when false, which is
exactly upstream's conditional attribute -- and a.class drops the empty part, so
the conditional class needs no branch either. */
@(deferred_none = h.close_all)
row :: proc(props := Row_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.tr_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(ROW_BASE, props.selected ? ROW_SELECTED : "", props.class),
						a.data("tui-table-state-selected", props.selected),
					},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
head :: proc(props := Head_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.th_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(HEAD_BASE, CHECKBOX_FIT, props.class)},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
cell :: proc(props := Cell_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.td_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(CELL_BASE, CHECKBOX_FIT, props.class)},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
caption :: proc(props := Caption_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.caption_open(
				..a.join(
					[]a.Attr{a.attr_if(props.id != "", a.id(props.id)), a.class(CAPTION_BASE, props.class)},
					attrs,
				),
			)
		}
	}
}
