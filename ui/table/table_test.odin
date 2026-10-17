/* Tests for table, in the package and beside the component -- see
button/button_test.odin for why the class strings are restated rather than
referenced. */
package table

import "core:strings"
import "core:testing"

import "html:html/a"
import "html:html/h"
import "html:html/hx"

@(private = "file")
rendered :: proc(t: ^testing.T, body_: proc()) -> string {
	out, err := h.render_to_string(body_, context.temp_allocator)
	testing.expect_value(t, err, nil)
	return out
}

@(private = "file")
TB_TABLE :: "w-full caption-bottom text-sm"
@(private = "file")
TB_HEADER :: "[&amp;_tr]:border-b"
@(private = "file")
TB_BODY :: "[&amp;_tr:last-child]:border-0"
@(private = "file")
TB_FOOTER :: "border-t bg-muted/50 font-medium [&amp;>tr]:last:border-b-0"
@(private = "file")
TB_ROW :: "border-b transition-colors hover:bg-muted/50"
@(private = "file")
TB_CHECKBOX :: "[&amp;:has([role=checkbox])]:pr-0 [&amp;>[role=checkbox]]:translate-y-[2px]"
@(private = "file")
TB_HEAD :: "h-10 px-2 text-left align-middle font-medium text-muted-foreground " + TB_CHECKBOX
@(private = "file")
TB_CELL :: "p-2 align-middle " + TB_CHECKBOX
@(private = "file")
TB_CAPTION :: "mt-4 text-sm text-muted-foreground"

/* A whole table in one expectation: eight components, each handing its element
to the next block down, and every tag the one the table model requires. */
@(test)
test_table_composition :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{table()
			{ caption(); h.text("Pumps") }
			{header()
				{row()
					{ head(); h.text("Asset") }
				}
			}
			{body()
				{row()
					{ cell(); h.text("P-101") }
				}
			}
			{footer()
				{row()
					{ cell(); h.text("1 of 1") }
				}
			}
		}
	})
	testing.expect_value(
		t,
		out,
		`<table class="` +
		TB_TABLE +
		`">` +
		`<caption class="` +
		TB_CAPTION +
		`">Pumps</caption>` +
		`<thead class="` +
		TB_HEADER +
		`"><tr class="` +
		TB_ROW +
		`"><th class="` +
		TB_HEAD +
		`">Asset</th></tr></thead>` +
		`<tbody class="` +
		TB_BODY +
		`"><tr class="` +
		TB_ROW +
		`"><td class="` +
		TB_CELL +
		`">P-101</td></tr></tbody>` +
		`<tfoot class="` +
		TB_FOOTER +
		`"><tr class="` +
		TB_ROW +
		`"><td class="` +
		TB_CELL +
		`">1 of 1</td></tr></tfoot>` +
		`</table>`,
	)
}

/* selected writes a bare data attribute and adds the class that reads it, both
on the same flag -- so as rendered it is a background, and the attribute is the
hook. Absent entirely when false, rather than written empty. */
@(test)
test_table_row_selected :: proc(t: ^testing.T) {
	off := rendered(t, proc() {
			{ row(); h.text("x") }
		})
	testing.expect_value(t, off, `<tr class="` + TB_ROW + `">x</tr>`)
	testing.expect(t, !strings.contains(off, "tui-table-state-selected"))

	on := rendered(t, proc() {
		{ row({selected = true}); h.text("x") }
	})
	testing.expect_value(
		t,
		on,
		`<tr class="` + TB_ROW + ` data-[tui-table-state-selected]:bg-muted" data-tui-table-state-selected>x</tr>`,
	)
}

/* The three class lists that reach across elements rather than styling their
own: they are what makes the row borders come out right, and what a caller
replacing the class instead of adding to it would break. */
@(test)
test_table_border_rules_reach_across_elements :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
			{ header(); h.text("h") }
			{ body(); h.text("b") }
			{ footer(); h.text("f") }
		})
	testing.expect(t, strings.contains(out, `<thead class="` + TB_HEADER + `">`))
	testing.expect(t, strings.contains(out, `<tbody class="` + TB_BODY + `">`))
	testing.expect(t, strings.contains(out, `<tfoot class="` + TB_FOOTER + `">`))
}

/* th and td carry the same checkbox-fitting rules, from one constant used
twice. */
@(test)
test_table_head_and_cell_share_the_checkbox_rules :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ head(); h.text("H") }
		{ cell(); h.text("C") }
	})
	testing.expect_value(t, strings.count(out, TB_CHECKBOX), 2)
}

/* Nothing enforces the table model: a cell renders anywhere. The browser will
sort it out, or not -- upstream takes the same position. */
@(test)
test_table_parts_render_alone :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{ cell(); h.text("loose") }
	})
	testing.expect_value(t, out, `<td class="` + TB_CELL + `">loose</td>`)
}

@(test)
test_table_ids_classes_and_attrs :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{table({id = "t", class = "border"}, hx.get("/rows"))
			{body({id = "t-b", class = "divide-y"})
				{row({id = "t-r", class = "cursor-pointer"}, a.data("id", "7"))
					{cell({id = "t-c", class = "font-mono"})
						h.text("P-101")}
				}
			}
		}
	})
	testing.expect(t, strings.has_prefix(out, `<table id="t" class="` + TB_TABLE + ` border" hx-get="/rows">`))
	testing.expect(t, strings.contains(out, `<tbody id="t-b" class="` + TB_BODY + ` divide-y">`))
	testing.expect(t, strings.contains(out, `<tr id="t-r" class="` + TB_ROW + ` cursor-pointer" data-id="7">`))
	testing.expect(t, strings.contains(out, `<td id="t-c" class="` + TB_CELL + ` font-mono">P-101</td>`))
}

/* Rows written from a loop, which is the whole reason these are components
rather than one proc taking a slice: each closes back to its own mark. */
@(test)
test_table_rows_from_a_loop :: proc(t: ^testing.T) {
	out := rendered(t, proc() {
		{body()
			for name in ([?]string{"P-101", "P-102", "P-103"}) {
				{row()
					{ cell(); h.text(name) }
				}
			}
		}
	})
	testing.expect_value(t, strings.count(out, "<tr "), 3)
	testing.expect_value(t, strings.count(out, "</tr>"), 3)
	testing.expect_value(t, strings.count(out, "<td "), 3)
	testing.expect(t, strings.has_suffix(out, "P-103</td></tr></tbody>"))
}
