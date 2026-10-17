/* Lucide icons, ported from templui's components/icon.

The table is generated -- icons.odin, from Lucide's icon set -- and this
is the whole of the hand-written half:

    {icon.icon(.Chevron_Down, {class = "size-4 text-muted-foreground"})}

Upstream is a name-keyed map plus a mutex-guarded cache of rendered SVG strings,
because the Go alternative is 1700 exported vars. None of that survives the
port and none of it is missed: the name is an enum member, so the lookup is an
array index that cannot miss, there is no error path, and the strings are
rodata rather than something to memoise.

What the enum buys beyond that is the thing to remember when writing components
against it. Odin has no closures, so a component that takes an icon has to
store one, and an enum member is a value -- it goes in a Props struct, compares,
and has a zero:

    Props :: struct {
        leading: icon.Name,
        label:   string,
    }

Name.None is that zero and is not a Lucide icon. It renders nothing, so a
component can pass its icon field straight through without guarding it, and an
unset field draws nothing rather than whichever icon sorted first. */
package icon

import "html:html/a"
import "html:html/h"

Props :: struct {
	class: string,
}

/* Writes a complete <svg>. Not a component in the odin-html-builder's html/h/component.odin
sense -- an icon has no children, so it closes itself inside this proc and the
braces at the call site are the ordinary element convention rather than load
bearing.

Upstream stamps nine fixed attributes on every icon, identical across all 1702
of them, which on an icon-heavy page is the same ~170 bytes repeated per icon.
Seven of them are now `.icon` in web/src/index.css. What is left is the two that
could not go, and they are worth knowing apart:

  - viewBox stays because there is no CSS property for it, and it is not
    decoration. It maps the 24-unit coordinate space the bodies are drawn in
    onto whatever box the element ends up being. Without it the paths render at
    1:1 in a viewport the size utilities shrank, so a small icon would be
    cropped to its top-left corner rather than scaled. Every call site sizes its
    icon, so dropping this breaks all of them.
  - xmlns was dropped rather than moved. A namespace is not a CSS property
    either, but nothing needs it here: the HTML parser puts <svg> in the SVG
    namespace on its own. It matters only if this markup is reparsed as XML or
    lifted out as a standalone .svg file, neither of which happens to a
    server-rendered page.

data-lucide is gone too. It was upstream's family marker, the literal string
"icon" rather than the icon's name, and nothing in this repo selects on it.

The cost of all this is a dependency that did not exist before: an icon is no
longer self-contained markup. Rendered anywhere the stylesheet is not -- an
email, a copied-out SVG -- it is now an unpainted, unsized 24-unit box. And
because CSS beats presentation attributes, the seven that moved can no longer be
overridden through `attrs`; that is a class's job now. `attrs` still reaches
viewBox, and still adds whatever upstream had no field for.

The body is written with h.raw, i.e. unescaped, because it is markup and not
text: escaping it would put &lt;path&gt; on the page. This is the one call in
the repo where the argument's provenance is the entire safety argument, so it is
worth stating. BODIES is generated rodata indexed by an enum. There is no
runtime string, no caller-supplied name, and no path to a value that did not
come out of lucide.json. Do not add an overload that takes a name as a string. */
icon :: proc(name: Name, props := Props{}, attrs: ..a.Attr) {
	if name == .None {
		return
	}

	{h.svg(..a.join([]a.Attr{a.view_box("0 0 24 24"), a.class("icon", props.class)}, attrs))
		h.raw(BODIES[name])
	}
}
