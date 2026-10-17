/* Sidebar, ported from templui's components/sidebar/sidebar.templ -- and onto
the authoring model (the checklist in web/src/ui/README.md): the
markup is wrapped in <oh-sidebar class="contents">, whose behaviour is one custom
element in web/src/ui/sidebar.ts. What the element reads from this markup is
declared in web/src/ui/sidebar.contract.json and asserted against the rendered
output by sidebar_test.odin.

Seventeen components: a layout, the sidebar itself, a trigger, the four
regions inside it, a menu and its parts, and an inset for the page beside it.

    {sidebar.layout()
        {sidebar.sidebar({id = "main", collapsible = .Icon})
            {sidebar.header()
                {sidebar.trigger({target = "main"})}
            }
            {sidebar.content()
                {sidebar.group()
                    {sidebar.group_label(); h.text("Warehouse")}
                    {sidebar.menu()
                        {sidebar.menu_item()
                            {sidebar.menu_button({href = "/shelves", is_active = true})
                                {icon.icon(.Boxes)}
                                {h.span(); h.text("Shelves")}
                            }
                        }
                    }
                }
            }
        }
        {sidebar.inset()
            // the page
        }
    }

All of them take children except trigger() and separator(), whose braces are
the void-element kind.

## Almost all of it is CSS

The state lives in two attributes on the wrapper -- data-oh-sidebar-state and
data-oh-sidebar-collapsible -- and every part of the sidebar reads them
through `group-data-[...]` selectors. So collapsing is one attribute changing,
and web/src/ui/sidebar.ts does little more than write it and remember it in a
cookie.

The one thing the script really does is the mobile portal: below 768px the
sidebar's content is *moved* out of the desktop aside and into a sheet, and
back again on resize. Which is why sidebar() renders a sheet with an empty
portal div in it, and why the content is rendered once rather than twice.

## The element is on layout(), not on sidebar()

Every other ported component wraps itself. This one cannot, and the reason is
in the CSS above: the wrapper sidebar() renders is a Tailwind `peer`, and
`peer-data-` is a *sibling* selector. inset() reads the sidebar's state that
way (INSET_MARGIN and the four below it), so an <oh-sidebar> around sidebar()
would put the wrapper one level down and leave the inset matching nothing --
the sidebar would still collapse, and the page beside it would stop noticing.

Wrapping layout() changes no relationship inside it, and it is also the right
boundary for the handlers: a trigger is routinely rendered in the page rather
than in the sidebar (upstream delegated its click from `document` for exactly
that reason), and every trigger, every wrapper and every mobile portal that
belongs to a sidebar is inside the layout it was written in. So the click
listener sits on the element and the checklist's "listeners live on `this`"
holds; the keyboard shortcut still needs the document, because a keydown with
nothing focused never reaches here.

The cost is stated rather than hidden: a sidebar() written without a layout()
around it renders and styles correctly but has no behaviour at all -- no
toggling, no shortcut, no mobile portal. Upstream's document-wide delegation
had no such requirement. Put the layout in.

## Ids, and the deviation

Upstream puts the sidebar's id in the Go context so that Trigger and Sidebar
can find each other without being told. There is no context here, so
sidebar() takes an id and trigger() takes a `target` -- and they have to match.
A trigger whose target names no sidebar is inert and looks fine, the same trap
tabs has.

Upstream also generates the id when none is given. This port does not invent
ids, so a sidebar without one renders a wrapper whose data-oh-sidebar-id is
empty; sidebar.ts keys its cookie on that, and two id-less sidebars would share
one. Give it an id.

## menu_button has no tooltip prop, and that is deliberate

Upstream's MenuButton takes a Tooltip string and renders the button *twice*:
once inside a tooltip, in a div shown only when the sidebar is collapsed, and
once bare in a div shown only when it is expanded. It can do that because templ
children are a component that can be rendered repeatedly.

A component here writes its caller's block exactly once -- that is what the
close_all pairing means -- so the two copies are not expressible. Rather than
render one copy and quietly change when the tooltip fires, the prop is left out
and the composition is the caller's:

    {sidebar.menu_item()
        {tooltip.tooltip()
            {tooltip.trigger()
                {sidebar.menu_button({href = "/shelves"})
                    {icon.icon(.Boxes)}
                    {h.span(); h.text("Shelves")}
                }
            }
            {tooltip.content({position = .Right}); h.text("Shelves")}
        }
    }

which is upstream's collapsed arm exactly, using the same components. What it
gives up is upstream's suppression of the tooltip while the sidebar is
expanded; a caller who wants that adds the two wrapper divs and their
visibility classes, and writes the label twice, as upstream does.

No TwMerge, so a caller's class is appended rather than merged -- see the file
comment in button/button.odin. */
package sidebar

import "core:strings"

import "html:html/a"
import "html:html/h"

import "ui:ui/button"
import "ui:ui/icon"
import "ui:ui/sheet"

Side :: enum {
	Left,
	Right,
}

Variant :: enum {
	Sidebar,
	Floating,
	Inset,
}

Collapsible :: enum {
	Offcanvas,
	Icon,
	None,
}

Menu_Button_Size :: enum {
	Default,
	Sm,
	Lg,
}

Props :: struct {
	// Should be given -- see the file comment.
	id:                string,
	class:             string,
	side:              Side,
	variant:           Variant,
	collapsible:       Collapsible,

	// The state the page starts in. sidebar.ts takes over from there.
	collapsed:         bool,

	// The letter, with ctrl or cmd. Defaults to "b".
	keyboard_shortcut: string,
}

Layout_Props :: struct {
	class: string,
}

Trigger_Props :: struct {
	id:     string,
	class:  string,

	// The sidebar's id. Required -- see the file comment.
	target: string,
}

Header_Props :: struct {
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

Inset_Props :: struct {
	id:    string,
	class: string,
}

Group_Props :: struct {
	id:    string,
	class: string,
}

Group_Label_Props :: struct {
	id:    string,
	class: string,
}

Menu_Props :: struct {
	id:    string,
	class: string,
}

Menu_Item_Props :: struct {
	id:    string,
	class: string,
}

Menu_Button_Props :: struct {
	id:        string,
	class:     string,

	// With one, the button is an <a>; without, a <button>.
	href:      string,
	is_active: bool,
	size:      Menu_Button_Size,
}

Menu_Badge_Props :: struct {
	id:    string,
	class: string,
}

Menu_Sub_Props :: struct {
	id:    string,
	class: string,
}

Menu_Sub_Item_Props :: struct {
	id:    string,
	class: string,
}

Menu_Sub_Button_Props :: struct {
	id:        string,
	class:     string,
	href:      string,
	is_active: bool,
}

Separator_Props :: struct {
	id:    string,
	class: string,
}

@(private)
DEFAULT_SHORTCUT :: "b"

// The width every part of the sidebar is measured against. Set as an inline
// custom property so a caller can override it per sidebar.
@(private)
WIDTH_STYLE :: "--sidebar-width:16rem"

/* One constant per string literal upstream, in upstream's order. */
@(private)
LAYOUT_BASE :: "flex min-h-svh relative"
@(private)
LAYOUT_INSET :: "has-[[data-oh-sidebar-variant=inset]]:bg-sidebar"

/* `group peer` is what the rest of this file hangs off: `group-data-` inside
the sidebar and `peer-data-` in the inset both read the state attributes from
this one element. */
@(private)
WRAPPER_BASE :: "group peer hidden md:block"

@(private)
MOBILE_SHEET_CLASS :: "md:hidden bg-sidebar text-sidebar-foreground !p-0 !gap-0 flex flex-col h-full"
@(private)
MOBILE_PORTAL_CLASS :: "sidebar-mobile-portal flex h-full flex-col"

/* An element that takes up the sidebar's width in the document flow, so the
page beside it is pushed over. The aside itself is fixed. */
@(private)
GAP_BASE :: "relative bg-transparent transition-[width] duration-200 ease-linear"
@(private)
GAP_WIDTH :: "w-[var(--sidebar-width,16rem)]"
@(private)
GAP_OFFCANVAS :: "group-data-[oh-sidebar-state=collapsed]:" + "group-data-[oh-sidebar-collapsible=offcanvas]:w-0"
@(private)
GAP_RIGHT :: "group-data-[oh-sidebar-side=right]:rotate-180"
@(private)
GAP_FLOATING_ICON ::
	"group-data-[oh-sidebar-variant=floating]:" +
	"group-data-[oh-sidebar-state=collapsed]:" +
	"group-data-[oh-sidebar-collapsible=icon]:w-[calc(3rem+theme(spacing.4))]"
@(private)
GAP_INSET_ICON ::
	"group-data-[oh-sidebar-variant=inset]:" +
	"group-data-[oh-sidebar-state=collapsed]:" +
	"group-data-[oh-sidebar-collapsible=icon]:w-[calc(3rem+theme(spacing.4))]"
@(private)
GAP_SIDEBAR_ICON ::
	"group-data-[oh-sidebar-variant=sidebar]:" +
	"group-data-[oh-sidebar-state=collapsed]:" +
	"group-data-[oh-sidebar-collapsible=icon]:w-12"

@(private)
ASIDE_BASE :: "fixed inset-y-0 z-10 hidden h-svh transition-transform duration-200 ease-linear md:flex"
@(private)
ASIDE_WIDTH :: "w-[var(--sidebar-width,16rem)]"
@(private)
ASIDE_RIGHT ::
	"group-data-[oh-sidebar-side=right]:right-0 " +
	"group-data-[oh-sidebar-side=right]:" +
	"group-data-[oh-sidebar-state=collapsed]:" +
	"group-data-[oh-sidebar-collapsible=offcanvas]:translate-x-full"
@(private)
ASIDE_LEFT ::
	"group-data-[oh-sidebar-side=left]:left-0 " +
	"group-data-[oh-sidebar-side=left]:" +
	"group-data-[oh-sidebar-state=collapsed]:" +
	"group-data-[oh-sidebar-collapsible=offcanvas]:-translate-x-full"
@(private)
ASIDE_FLOATING ::
	"group-data-[oh-sidebar-variant=floating]:p-2 " +
	"group-data-[oh-sidebar-variant=floating]:" +
	"group-data-[oh-sidebar-state=collapsed]:" +
	"group-data-[oh-sidebar-collapsible=icon]:w-[calc(3rem+(theme(spacing.4))+2px)]"
@(private)
ASIDE_INSET ::
	"group-data-[oh-sidebar-variant=inset]:p-2 " +
	"group-data-[oh-sidebar-variant=inset]:" +
	"group-data-[oh-sidebar-state=collapsed]:" +
	"group-data-[oh-sidebar-collapsible=icon]:w-[calc(3rem+(theme(spacing.4))+2px)]"
@(private)
ASIDE_SIDEBAR_ICON ::
	"group-data-[oh-sidebar-variant=sidebar]:" +
	"group-data-[oh-sidebar-state=collapsed]:" +
	"group-data-[oh-sidebar-collapsible=icon]:w-12"
@(private)
ASIDE_BORDER ::
	"group-data-[oh-sidebar-variant=sidebar]:" +
	"group-data-[oh-sidebar-side=left]:border-r " +
	"group-data-[oh-sidebar-variant=sidebar]:" +
	"group-data-[oh-sidebar-side=right]:border-l"

@(private)
INNER_BASE ::
	"bg-sidebar group-data-[oh-sidebar-variant=floating]:border-sidebar-border " + "flex h-full w-full flex-col"
@(private)
INNER_FLOATING ::
	"group-data-[oh-sidebar-variant=floating]:rounded-lg " +
	"group-data-[oh-sidebar-variant=floating]:border " +
	"group-data-[oh-sidebar-variant=floating]:shadow-sm"

/* The element sidebar.ts moves between the aside and the mobile sheet. The data
attribute is the hook it queries by; `sidebar-content` is upstream's class,
carried over and matched by nothing -- neither this collection's stylesheet nor
the element reads it. */
@(private)
CONTENT_WRAPPER :: "flex h-full w-full flex-col sidebar-content"

@(private)
TRIGGER_MOBILE_CLASS :: "md:hidden"
@(private)
TRIGGER_DESKTOP_WRAPPER :: "hidden md:block"
@(private)
TRIGGER_BUTTON_CLASS :: "size-7"
@(private)
TRIGGER_ICON :: "size-4"

@(private)
HEADER_BASE :: "flex flex-col gap-2 p-2"
@(private)
FOOTER_BASE :: "mt-auto flex flex-col gap-2 p-2"

@(private)
CONTENT_BASE :: "flex min-h-0 flex-1 flex-col gap-2 overflow-auto"
@(private)
CONTENT_ICON ::
	"group-data-[oh-sidebar-state=collapsed]:" + "group-data-[oh-sidebar-collapsible=icon]:overflow-hidden"

@(private)
GROUP_BASE :: "relative flex w-full min-w-0 flex-col p-2"

@(private)
GROUP_LABEL_BASE ::
	"flex h-8 shrink-0 items-center rounded-md px-2 text-xs font-medium " + "text-sidebar-foreground/70"
@(private)
GROUP_LABEL_RING :: "ring-sidebar-ring outline-none transition-[margin,opacity] duration-200 ease-linear"
@(private)
GROUP_LABEL_FOCUS :: "focus-visible:ring-2 [&>svg]:size-4 [&>svg]:shrink-0"
@(private)
GROUP_LABEL_ICON ::
	"group-data-[oh-sidebar-state=collapsed]:" +
	"group-data-[oh-sidebar-collapsible=icon]:-mt-8 " +
	"group-data-[oh-sidebar-state=collapsed]:" +
	"group-data-[oh-sidebar-collapsible=icon]:opacity-0"

@(private)
MENU_BASE :: "flex w-full min-w-0 flex-col gap-1"
@(private)
MENU_ITEM_BASE :: "group/menu-item relative"

@(private)
MENU_BUTTON_BASE :: "flex w-full items-center gap-2 rounded-md p-2 text-left overflow-hidden"
@(private)
MENU_BUTTON_HOVER :: "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
@(private)
MENU_BUTTON_TRANSITION :: "transition-[width,height,padding]"
@(private)
MENU_BUTTON_SM :: "data-[oh-sidebar-size=sm]:h-7 data-[oh-sidebar-size=sm]:text-xs"
@(private)
MENU_BUTTON_LG :: "data-[oh-sidebar-size=lg]:h-12 data-[oh-sidebar-size=lg]:text-sm"
@(private)
MENU_BUTTON_DEFAULT :: "data-[oh-sidebar-size=default]:h-8 data-[oh-sidebar-size=default]:text-sm"
@(private)
MENU_BUTTON_ACTIVE ::
	"data-[oh-sidebar-active=true]:bg-sidebar-accent " +
	"data-[oh-sidebar-active=true]:text-sidebar-accent-foreground " +
	"data-[oh-sidebar-active=true]:font-medium"
@(private)
MENU_BUTTON_ICON_SIZE ::
	"group-data-[oh-sidebar-state=collapsed]:" + "group-data-[oh-sidebar-collapsible=icon]:!size-8"
@(private)
MENU_BUTTON_ICON_PAD :: "group-data-[oh-sidebar-state=collapsed]:" + "group-data-[oh-sidebar-collapsible=icon]:!p-2"
@(private)
MENU_BUTTON_ICON_LG ::
	"group-data-[oh-sidebar-state=collapsed]:" +
	"group-data-[oh-sidebar-collapsible=icon]:" +
	"data-[oh-sidebar-size=lg]:!p-0"
@(private)
MENU_BUTTON_TRUNCATE :: "[&>span:last-child]:truncate [&>svg]:size-4 [&>svg]:shrink-0"

@(private)
MENU_BADGE_BASE :: "ml-auto flex h-5 min-w-5 items-center justify-center rounded-md px-1 text-xs font-medium"
@(private)
MENU_BADGE_COLOURS :: "bg-sidebar-accent text-sidebar-accent-foreground"
@(private)
MENU_BADGE_ICON :: "group-data-[oh-sidebar-state=collapsed]:" + "group-data-[oh-sidebar-collapsible=icon]:hidden"

@(private)
MENU_SUB_BASE :: "mx-3.5 flex min-w-0 translate-x-px flex-col gap-1 border-l border-sidebar-border " + "px-2.5 py-0.5"
@(private)
MENU_SUB_ICON :: "group-data-[oh-sidebar-state=collapsed]:" + "group-data-[oh-sidebar-collapsible=icon]:hidden"
@(private)
MENU_SUB_ITEM_BASE :: "group/menu-sub-item relative"

@(private)
MENU_SUB_BUTTON_LINK :: "flex items-center gap-2 rounded-md px-2 py-1.5 text-sm"
@(private)
MENU_SUB_BUTTON_BUTTON :: "flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-sm text-left"
@(private)
MENU_SUB_BUTTON_HOVER :: "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
@(private)
MENU_SUB_BUTTON_TRANSITION :: "transition-colors"
@(private)
MENU_SUB_BUTTON_ACTIVE ::
	"data-[oh-sidebar-active=true]:bg-sidebar-accent " +
	"data-[oh-sidebar-active=true]:text-sidebar-accent-foreground " +
	"data-[oh-sidebar-active=true]:font-medium"

@(private)
SEPARATOR_BASE :: "mx-2 my-2 border-t border-sidebar-border"

@(private)
INSET_BASE :: "relative flex w-full flex-1 flex-col bg-background"
@(private)
INSET_MARGIN :: "md:peer-data-[oh-sidebar-variant=inset]:m-2"
@(private)
INSET_MARGIN_LEFT :: "md:peer-data-[oh-sidebar-variant=inset]:ml-0"
@(private)
INSET_ROUNDED :: "md:peer-data-[oh-sidebar-variant=inset]:rounded-xl"
@(private)
INSET_SHADOW :: "md:peer-data-[oh-sidebar-variant=inset]:shadow-sm"
@(private)
INSET_COLLAPSED ::
	"md:peer-data-[oh-sidebar-variant=inset]:" +
	"peer-data-[oh-sidebar-state=collapsed]:" +
	"peer-data-[oh-sidebar-collapsible=offcanvas]:ml-2"

@(private)
MOBILE_SUFFIX :: "-mobile"

@(private)
side_attr :: proc(s: Side) -> string {
	return s == .Right ? "right" : "left"
}

@(private)
variant_attr :: proc(v: Variant) -> string {
	switch v {
	case .Sidebar:
		return "sidebar"
	case .Floating:
		return "floating"
	case .Inset:
		return "inset"
	}
	return "sidebar"
}

@(private)
collapsible_attr :: proc(c: Collapsible) -> string {
	switch c {
	case .Offcanvas:
		return "offcanvas"
	case .Icon:
		return "icon"
	case .None:
		return "none"
	}
	return "offcanvas"
}

@(private)
size_attr :: proc(s: Menu_Button_Size) -> string {
	switch s {
	case .Default:
		return "default"
	case .Sm:
		return "sm"
	case .Lg:
		return "lg"
	}
	return "default"
}

/* button's Props.class is a string rather than an attribute list, so the parts
are joined by hand. Into the temp allocator, which is the render arena. */
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

@(private)
suffixed :: proc(id, suffix: string) -> string {
	return strings.concatenate({id, suffix}, context.temp_allocator)
}

/* The page. Everything reads the sidebar's state through it: the sidebar is a
`peer`, so the inset beside it can see the same attributes.

This is also where the custom element goes -- see the file comment. */
@(deferred_none = h.close_all)
layout :: proc(props := Layout_Props{}, attrs: ..a.Attr) {
	// The wrapper is the element boundary and nothing else: an explicit display
	// utility (an unknown element is display:inline before upgrade), with
	// everything the caller configures on the markup inside, unchanged. It is
	// opened into the same scope as the flex box, so close_all writes both
	// closing tags at the end of the caller's block, innermost first.
	{h.open_scope()
		{h.elem_open("oh-sidebar", a.class("contents"))
			{h.div_open(
					..a.join(
						[]a.Attr{a.class(LAYOUT_BASE, LAYOUT_INSET, props.class), a.data("oh-sidebar-layout", true)},
						attrs,
					),
				)
			}
		}
	}
}

/* Five elements deep, and the caller's children land in the innermost -- the
one sidebar.ts moves into the mobile sheet.

The sheet above it is written complete and empty: it is a shell for the portal,
and the content is moved into it rather than rendered twice. */
@(deferred_none = h.close_all)
sidebar :: proc(props := Props{}, attrs: ..a.Attr) {
	shortcut := props.keyboard_shortcut != "" ? props.keyboard_shortcut : DEFAULT_SHORTCUT
	state := props.collapsed ? "collapsed" : "expanded"

	// The mobile shell. Empty until the script moves the content in.
	//
	// The side is passed to both halves, because sheet has no context to
	// thread it through -- see the file comment there. Setting only the root's
	// would leave a left-hand sidebar sliding in from the right.
	sheet_side: sheet.Side = props.side == .Right ? .Right : .Left

	{sheet.sheet({id = suffixed(props.id, MOBILE_SUFFIX), side = sheet_side})
		{sheet.content({class = MOBILE_SHEET_CLASS, hide_close_button = true, side = sheet_side})
			{h.div(a.class(MOBILE_PORTAL_CLASS), a.data("oh-sidebar-mobile-portal", props.id))
			}
		}
	}

	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.class(WRAPPER_BASE, props.class),
						a.data("oh-sidebar-state", state),
						a.data("oh-sidebar-collapsible", collapsible_attr(props.collapsible)),
						a.data("oh-sidebar-variant", variant_attr(props.variant)),
						a.data("oh-sidebar-side", side_attr(props.side)),
						a.data("oh-sidebar-wrapper", true),
						a.data("oh-sidebar-id", props.id),
						a.data("oh-sidebar-keyboard-shortcut", shortcut),
						a.style(WIDTH_STYLE),
					},
					attrs,
				),
			)
			// Holds the sidebar's width open in the document flow; the aside
			// itself is fixed and takes up none.
			{h.div(
					a.class(
						GAP_BASE,
						GAP_WIDTH,
						GAP_OFFCANVAS,
						GAP_RIGHT,
						GAP_FLOATING_ICON,
						GAP_INSET_ICON,
						GAP_SIDEBAR_ICON,
					),
				)
			}

			{h.aside_open(
					a.attr_if(props.id != "", a.id(props.id)),
					a.class(
						ASIDE_BASE,
						ASIDE_WIDTH,
						ASIDE_RIGHT,
						ASIDE_LEFT,
						ASIDE_FLOATING,
						ASIDE_INSET,
						ASIDE_SIDEBAR_ICON,
						ASIDE_BORDER,
					),
					a.data("sidebar", "sidebar"),
				)
				{h.div_open(a.data("sidebar", "sidebar"), a.class(INNER_BASE, INNER_FLOATING))
					{h.div_open(a.data("oh-sidebar-content", props.id), a.class(CONTENT_WRAPPER))
					}
				}
			}
		}
	}
}

/* Two buttons: one that opens the mobile sheet, one that toggles the desktop
sidebar. Each is hidden at the other's breakpoint, so only one is ever
clickable. */
trigger :: proc(props := Trigger_Props{}, attrs: ..a.Attr) {
	{sheet.trigger({for_ = suffixed(props.target, MOBILE_SUFFIX), class = TRIGGER_MOBILE_CLASS})
		{button.button({size = .Icon, variant = .Ghost, class = TRIGGER_BUTTON_CLASS})
			{ icon.icon(.Panel_Left, {class = TRIGGER_ICON}) }
			{ h.span(a.class("sr-only")); h.text("Toggle Sidebar") }
		}
	}

	{h.div(a.class(TRIGGER_DESKTOP_WRAPPER))
		{button.button(
				{id = props.id, size = .Icon, variant = .Ghost, class = joined(TRIGGER_BUTTON_CLASS, props.class)},
				..a.join(
					[]a.Attr{a.data("oh-sidebar-trigger", true), a.data("oh-sidebar-target", props.target)},
					attrs,
				),
			)
			{ icon.icon(.Panel_Left, {class = TRIGGER_ICON}) }
			{ h.span(a.class("sr-only")); h.text("Toggle Sidebar") }
		}
	}
}

@(deferred_none = h.close_all)
header :: proc(props := Header_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(HEADER_BASE, props.class),
						a.data("oh-sidebar", "header"),
					},
					attrs,
				),
			)
		}
	}
}

/* mt-auto, so a footer sits at the bottom of the sidebar however little is
above it. */
@(deferred_none = h.close_all)
footer :: proc(props := Footer_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(FOOTER_BASE, props.class),
						a.data("oh-sidebar", "footer"),
					},
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
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(CONTENT_BASE, CONTENT_ICON, props.class),
						a.data("oh-sidebar", "content"),
					},
					attrs,
				),
			)
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
						a.data("oh-sidebar", "group"),
					},
					attrs,
				),
			)
		}
	}
}

/* Slides up and fades out in icon mode rather than being hidden, so the menu
below it keeps its place. */
@(deferred_none = h.close_all)
group_label :: proc(props := Group_Label_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.div_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(GROUP_LABEL_BASE, GROUP_LABEL_RING, GROUP_LABEL_FOCUS, GROUP_LABEL_ICON, props.class),
						a.data("oh-sidebar", "group-label"),
					},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
menu :: proc(props := Menu_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.ul_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(MENU_BASE, props.class),
						a.data("oh-sidebar", "menu"),
					},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
menu_item :: proc(props := Menu_Item_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.li_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(MENU_ITEM_BASE, props.class),
						a.data("oh-sidebar", "menu-item"),
					},
					attrs,
				),
			)
		}
	}
}

/* An anchor with an href, a button without -- the same split dropdown's item
makes. No tooltip: see the file comment. */
@(deferred_none = h.close_all)
menu_button :: proc(props := Menu_Button_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		menu_button_element(props, ..attrs)
	}
}

@(private)
menu_button_element :: proc(props: Menu_Button_Props, attrs: ..a.Attr) {
	class := a.class(
		MENU_BUTTON_BASE,
		MENU_BUTTON_HOVER,
		MENU_BUTTON_TRANSITION,
		MENU_BUTTON_SM,
		MENU_BUTTON_LG,
		MENU_BUTTON_DEFAULT,
		MENU_BUTTON_ACTIVE,
		MENU_BUTTON_ICON_SIZE,
		MENU_BUTTON_ICON_PAD,
		MENU_BUTTON_ICON_LG,
		MENU_BUTTON_TRUNCATE,
		props.class,
	)

	if props.href != "" {
		{h.a_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.href(props.href),
						class,
						a.data("oh-sidebar", "menu-button"),
						a.data("oh-sidebar-size", size_attr(props.size)),
						a.attr_if(props.is_active, a.data("oh-sidebar-active", "true")),
					},
					attrs,
				),
			)
		}
	} else {
		{h.button_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.type("button"),
						class,
						a.data("oh-sidebar", "menu-button"),
						a.data("oh-sidebar-size", size_attr(props.size)),
						a.attr_if(props.is_active, a.data("oh-sidebar-active", "true")),
					},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
menu_badge :: proc(props := Menu_Badge_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.span_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(MENU_BADGE_BASE, MENU_BADGE_COLOURS, MENU_BADGE_ICON, props.class),
						a.data("oh-sidebar", "menu-badge"),
					},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
menu_sub :: proc(props := Menu_Sub_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.ul_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(MENU_SUB_BASE, MENU_SUB_ICON, props.class),
						a.data("oh-sidebar", "menu-sub"),
					},
					attrs,
				),
			)
		}
	}
}

@(deferred_none = h.close_all)
menu_sub_item :: proc(props := Menu_Sub_Item_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.li_open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(MENU_SUB_ITEM_BASE, props.class),
						a.data("oh-sidebar", "menu-sub-item"),
					},
					attrs,
				),
			)
		}
	}
}

/* An anchor with an href, a button without. The two differ by w-full, which a
button needs and an anchor gets from being a flex child -- the same split
dropdown's item makes. */
@(deferred_none = h.close_all)
menu_sub_button :: proc(props := Menu_Sub_Button_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		if props.href != "" {
			{h.a_open(
					..a.join(
						[]a.Attr {
							a.attr_if(props.id != "", a.id(props.id)),
							a.href(props.href),
							a.class(
								MENU_SUB_BUTTON_LINK,
								MENU_SUB_BUTTON_HOVER,
								MENU_SUB_BUTTON_TRANSITION,
								MENU_SUB_BUTTON_ACTIVE,
								props.class,
							),
							a.data("oh-sidebar", "menu-sub-button"),
							a.attr_if(props.is_active, a.data("oh-sidebar-active", "true")),
						},
						attrs,
					),
				)
			}
		} else {
			{h.button_open(
					..a.join(
						[]a.Attr {
							a.attr_if(props.id != "", a.id(props.id)),
							a.type("button"),
							a.class(
								MENU_SUB_BUTTON_BUTTON,
								MENU_SUB_BUTTON_HOVER,
								MENU_SUB_BUTTON_TRANSITION,
								MENU_SUB_BUTTON_ACTIVE,
								props.class,
							),
							a.data("oh-sidebar", "menu-sub-button"),
							a.attr_if(props.is_active, a.data("oh-sidebar-active", "true")),
						},
						attrs,
					),
				)
			}
		}
	}
}

/* An <hr>, so it is a separator to a screen reader as well as a line. */
separator :: proc(props := Separator_Props{}, attrs: ..a.Attr) {
	{h.hr(
			..a.join(
				[]a.Attr {
					a.attr_if(props.id != "", a.id(props.id)),
					a.class(SEPARATOR_BASE, props.class),
					a.data("oh-sidebar", "separator"),
				},
				attrs,
			),
		)
	}
}

/* The page beside the sidebar. peer-data-, not group-data-: it is a sibling of
the sidebar rather than inside it. */
@(deferred_none = h.close_all)
inset :: proc(props := Inset_Props{}, attrs: ..a.Attr) {
	{h.open_scope()
		{h.main__open(
				..a.join(
					[]a.Attr {
						a.attr_if(props.id != "", a.id(props.id)),
						a.class(
							INSET_BASE,
							INSET_MARGIN,
							INSET_MARGIN_LEFT,
							INSET_ROUNDED,
							INSET_SHADOW,
							INSET_COLLAPSED,
							props.class,
						),
						a.data("oh-sidebar", "inset"),
					},
					attrs,
				),
			)
		}
	}
}
