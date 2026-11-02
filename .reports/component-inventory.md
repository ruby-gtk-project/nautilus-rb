# nautilus-rb — upstream component inventory

Survey step. No app code written. Upstream is read from `origin/main`
(GNOME Files / nautilus, C + blueprint); the port lives on `ruby`.

Method: `component-identification` skill. Blueprint files were read first
(they *are* the component inventory), then the `.c` files that build widgets
in code, then the menu models, the GSettings schema, the GResource manifest
and `po/POTFILES.in` (which names every user-facing source file).

## Totals

| | Upstream | `ruby` branch |
|---|---:|---:|
| Blueprint templates / named roots | 36 files, 38 roots | 0 (house style has no `.ui`) |
| GMenu models | 10 (3 `.ui` + 7 inline in `.blp`) | 6 (app menu, tab menus, view menu, pathbar context menu, column-chooser row menu) |
| Action groups | 7 (`app.`, `win.`, `slot.`, `view.`, `pathbar.`, `row.`, `dialog.`, `column-chooser.`, `chooser.`, `preferences.`, `search-popover.`, `listitem.`) | 0 |
| Distinct actions | 123 | ~30 (all 8 `app.`, all 14 `win.`, most `slot.`; `view.` largely missing) |
| Keyboard shortcuts in the shortcuts dialog | 56 items in 18 sections | dialog ported (`lib/nautilus/shortcuts_dialog.rb`); only one `set_accels_for_action` site so far |
| GSettings keys | 11 keys, 10 enums, 3 schemas | 0 |
| `po/` catalogue | 134 languages, `POTFILES.in` lists 66 `src/*.c` + 36 `.blp`/`.ui` | no `po/` yet |
| App CSS classes in `src/resources/style.css` | 18 app-defined | 36 classes applied from `lib/`, 12 of the 18 app-defined ones defined in `lib/nautilus/style.rb` |
| Port `lib/*.rb` files | — | 47 (43 of the 73 component files below, plus `nautilus.rb`, `nautilus/rb/version.rb` and the `file.rb`/`directory.rb` model pair) |

Status as of the window-shell/views/first-dialogs port commit: the app
shell, both file views, the cells, the sidebar, the path bar and nine of
the dialogs exist on `ruby`; the properties window, the search stack, the
progress stack, the network stack, the portal file chooser, DnD and the
remaining dialogs do not. Per-component status:

| Upstream | Port file | Kind | Exists on `ruby` |
|---|---|---|---|
| `src/nautilus-application.c` | `lib/nautilus/application.rb` | application class / app actions | yes (176 lines) |
| `src/resources/ui/nautilus-window.blp + src/nautilus-window.c` | `lib/nautilus/window.rb` | main window | yes (457 lines) |
| `src/nautilus-window-slot.c` | `lib/nautilus/window_slot.rb` | tab content shell | yes (275 lines) |
| `src/resources/ui/nautilus-toolbar.blp + .c` | `lib/nautilus/toolbar.rb` | header bar | yes (260 lines) |
| `src/resources/ui/nautilus-history-controls.blp + .c` | `lib/nautilus/history_controls.rb` | nav buttons + history menus | yes (154 lines) |
| `src/resources/ui/nautilus-view-controls.blp + .c + menu/nautilus-toolbar-view-menu.ui` | `lib/nautilus/view_controls.rb` | view switcher + view menu | yes (154 lines) |
| `src/nautilus-sidebar.c` | `lib/nautilus/sidebar.rb` | sidebar | yes (768 lines) |
| `src/resources/ui/nautilus-sidebar-row.blp + .c` | `lib/nautilus/sidebar_row.rb` | sidebar row | yes (158 lines) |
| `src/nautilus-pathbar.c + menu/nautilus-pathbar-context-menu.ui` | `lib/nautilus/pathbar.rb` | path bar + its context menu | yes (319 lines) |
| `src/nautilus-location-entry.c` | `lib/nautilus/location_entry.rb` | location entry | yes (226 lines) |
| `src/resources/ui/nautilus-files-view.blp + .c + menu/nautilus-files-view-context-menus.ui` | `lib/nautilus/files_view.rb` | files view + context menus | yes (916 lines) |
| `src/nautilus-list-base.c` | `lib/nautilus/list_base.rb` | shared view base | yes (207 lines) |
| `src/nautilus-list-view.c` | `lib/nautilus/list_view.rb` | list view | yes (210 lines) |
| `src/nautilus-grid-view.c` | `lib/nautilus/grid_view.rb` | grid view | yes (136 lines) |
| `src/nautilus-network-view.c` | `lib/nautilus/network_view.rb` | network view | no |
| `src/nautilus-view-cell.c` | `lib/nautilus/view_cell.rb` | cell base | yes (102 lines) |
| `src/nautilus-grid-cell.c + .blp` | `lib/nautilus/grid_cell.rb` | grid cell | yes (187 lines) |
| `src/nautilus-name-cell.c + .blp` | `lib/nautilus/name_cell.rb` | name cell | yes (221 lines) |
| `src/nautilus-label-cell.c` | `lib/nautilus/label_cell.rb` | label cell | yes (48 lines) |
| `src/nautilus-star-cell.c` | `lib/nautilus/star_cell.rb` | star cell | yes (87 lines) |
| `src/nautilus-network-cell.c + .blp` | `lib/nautilus/network_cell.rb` | network cell | no |
| `src/nautilus-minimal-cell.c` | `lib/nautilus/minimal_cell.rb` | minimal cell data object | yes (24 lines) |
| `src/nautilus-image.c` | `lib/nautilus/image.rb` | icon/thumbnail widget | yes (103 lines) |
| `src/nautilus-query-editor.c` | `lib/nautilus/query_editor.rb` | search bar | no |
| `src/resources/ui/nautilus-search-popover.blp + .c` | `lib/nautilus/search_popover.rb` | search filters popover | no |
| `src/resources/ui/nautilus-search-types-dialog.blp` | `lib/nautilus/search_types_dialog.rb` | file-types dialog | no |
| `src/resources/ui/nautilus-date-range-dialog.blp + .c` | `lib/nautilus/date_range_dialog.rb` | date range dialog | no |
| `src/resources/ui/nautilus-date-entry-row.blp + .c` | `lib/nautilus/date_entry_row.rb` | date entry row | no |
| `src/nautilus-preferences-dialog.c + .blp` | `lib/nautilus/preferences_dialog.rb` | preferences dialog | yes (289 lines) |
| `src/resources/ui/shortcuts-dialog.blp` | `lib/nautilus/shortcuts_dialog.rb` | keyboard shortcuts dialog | yes (167 lines) |
| `src/nautilus-properties.c + nautilus-properties-window.blp` | `lib/nautilus/properties.rb` | properties window | no |
| `src/resources/ui/nautilus-properties-widget.blp` | `lib/nautilus/properties_widget.rb` | properties widget | no |
| `src/resources/ui/nautilus-file-properties-change-permissions.blp` | `lib/nautilus/change_permissions_dialog.rb` | enclosed-permissions dialog | no |
| `src/nautilus-new-folder-dialog.c + .blp` | `lib/nautilus/new_folder_dialog.rb` | new folder dialog | yes (125 lines) |
| `src/nautilus-compress-dialog.c + .blp` | `lib/nautilus/compress_dialog.rb` | compress dialog | no |
| `src/nautilus-batch-rename-dialog.c + .blp` | `lib/nautilus/batch_rename_dialog.rb` | batch rename dialog | no |
| `src/nautilus-batch-rename-item.c` | `lib/nautilus/batch_rename_item.rb` | batch rename preview row model | yes (55 lines) |
| `src/nautilus-rename-file-popover.c + .blp` | `lib/nautilus/rename_file_popover.rb` | rename popover | yes (156 lines) |
| `src/nautilus-column-chooser.c + .blp` | `lib/nautilus/column_chooser.rb` | column chooser dialog | yes (246 lines) |
| `src/nautilus-grid-view-captions-dialog.c + .blp` | `lib/nautilus/grid_view_captions_dialog.rb` | grid captions dialog | yes (112 lines) |
| `src/resources/ui/nautilus-files-view-select-items.blp` | `lib/nautilus/select_items_dialog.rb` | select-items dialog | yes (121 lines) |
| `src/nautilus-app-chooser.c + .blp` | `lib/nautilus/app_chooser.rb` | open-with dialog | no |
| `src/nautilus-app-chooser-widget.c + .blp` | `lib/nautilus/app_chooser_widget.rb` | app list + empty state | no |
| `src/nautilus-file-conflict-dialog.c + .blp` | `lib/nautilus/file_conflict_dialog.rb` | file conflict dialog | no |
| `src/nautilus-operations-ui-manager.c + -request-passphrase.blp` | `lib/nautilus/operations_ui_manager.rb` | passphrase prompt + conflict orchestration | no |
| `src/nautilus-dialog-utilities.c` | `lib/nautilus/dialog_utilities.rb` | generic alert dialogs | yes (126 lines) |
| `src/nautilus-error-reporting.c` | `lib/nautilus/error_reporting.rb` | error states | yes (117 lines) |
| `src/nautilus-mime-actions.c` | `lib/nautilus/mime_actions.rb` | open/launch prompts | yes (237 lines) |
| `src/nautilus-file-chooser.c + .blp` | `lib/nautilus/file_chooser.rb` | portal file chooser window | no |
| `src/nautilus-location-banner.c` | `lib/nautilus/location_banner.rb` | 11 location banners | yes (193 lines) |
| `src/nautilus-floating-bar.c` | `lib/nautilus/floating_bar.rb` | overlay status bar | yes (193 lines) |
| `src/nautilus-x-content-bar.c` | `lib/nautilus/x_content_bar.rb` | removable-media info bar | no |
| `src/nautilus-network-address-bar.c + .blp` | `lib/nautilus/network_address_bar.rb` | connect-to-server bar | no |
| `src/nautilus-recent-servers.c` | `lib/nautilus/recent_servers.rb` | recent servers model | no |
| `src/nautilus-progress-indicator.c + .blp` | `lib/nautilus/progress_indicator.rb` | operations button + popover | no |
| `src/nautilus-progress-info-widget.c + .blp` | `lib/nautilus/progress_info_widget.rb` | one operation row | no |
| `src/nautilus-progress-paintable.c` | `lib/nautilus/progress_paintable.rb` | animated progress icon | no |
| `src/nautilus-progress-persistence-handler.c` | `lib/nautilus/progress_persistence_handler.rb` | finished-operation notifications | no |
| `src/nautilus-shortcut-manager.c` | `lib/nautilus/shortcut_manager.rb` | shortcut scope wrapper | no |
| `src/nautilus-filename-validator.c` | `lib/nautilus/filename_validator.rb` | filename feedback states | yes (282 lines) |
| `src/nautilus-column-utilities.c` | `lib/nautilus/column_utilities.rb` | list columns | yes (158 lines) |
| `src/nautilus-global-preferences.c` | `lib/nautilus/global_preferences.rb` | GSettings keys | yes (300 lines) |
| `src/nautilus-ui-utilities.c` | `lib/nautilus/ui_utilities.rb` | menu + date helpers | yes (248 lines) |
| `src/nautilus-date-utilities.c` | `lib/nautilus/date_utilities.rb` | date strings | yes (222 lines) |
| `src/nautilus-previewer.c` | `lib/nautilus/previewer.rb` | Sushi preview client | no |
| `src/nautilus-dbus-launcher.c` | `lib/nautilus/dbus_launcher.rb` | Console/Disks/Settings launcher | yes (115 lines) |
| `src/nautilus-file-operations.c` | `lib/nautilus/file_operations.rb` | operations + confirmations | yes (264 lines) |
| `src/nautilus-file-undo-operations.c` | `lib/nautilus/file_undo_operations.rb` | undo/redo labels | no |
| `src/nautilus-clipboard.c` | `lib/nautilus/clipboard.rb` | cut/copy/paste | yes (72 lines) |
| `src/nautilus-dnd.c + nautilus-files-view-dnd.c` | `lib/nautilus/dnd.rb` | drop menus + drag icons | no |
| `src/nautilus-shell-search-provider.c` | `lib/nautilus/shell_search_provider.rb` | Shell search results | no |
| `src/nautilus-autorun-software.c` | `lib/nautilus/autorun_software.rb` | autorun confirmation | no |
| `src/resources/style.css` | `lib/nautilus/style.rb` | 18 app CSS classes | yes (58 lines) |

43 of 73 present, 30 missing.

---

## 1. Application and window shell

### `src/nautilus-application.c` → `lib/nautilus/application.rb` (ported)

Not a widget class; it owns the app actions, the accelerators, the About
dialog and the preferences entry point.

| Item | × | Notes |
|---|---:|---|
| `app.new-window`, `app.clone-window` | 2 | `clone-window` accel `<Primary>n` |
| `app.preferences` | 1 | accel `<Primary>comma`; opens the preferences dialog |
| `app.search-settings` | 1 | opens GNOME Settings search panel over D-Bus |
| `app.about` | 1 | `Adw.AboutDialog` built in code |
| `app.help` | 1 | `Gtk.UriLauncher` to the help URI |
| `app.shortcuts` | 1 | presents `shortcuts-dialog.blp` |
| `app.quit`, `app.kill` | 2 | `quit` accel `<Primary>q` |

Repeaters: one window per `activate`/`open`. Conditional: dev-profile icon
(`org.gnome.NautilusDevel`).

### `src/resources/ui/nautilus-window.blp` + `src/nautilus-window.c` → `lib/nautilus/window.rb`

The main window. Three menu models live in this file.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template root) | 1 | `view` | title bound to active slot | 890×550, min 360×294 |
| `$NautilusShortcutManager` | 1 | — | — | composite, see §9 |
| `Adw.ToastOverlay` | 1 | — | — | `adw_toast_new` ×3 in `.c` |
| `Adw.TabOverview` | 1 | — | `create-tab` | `enable-new-tab`, secondary menu |
| `Adw.OverlaySplitView` | 1 | — | — | sidebar fraction 0.2 |
| `Adw.ToolbarView` | 2 | — | — | sidebar side + content side |
| `Adw.HeaderBar` (sidebar) | 1 | — | — | — |
| `Gtk.ToggleButton` | 1 | — | `slot.search-global` | "Search Everywhere", `edit-find-symbolic` |
| `Adw.WindowTitle` | 1 | — | — | "Files" |
| `Gtk.MenuButton` | 1 | — | `app_menu` | "Main Menu", `open-menu-symbolic` |
| `Gtk.Box` (bottom bar) | 1 | `toolbar` | — | hosts progress indicator |
| `$NautilusProgressIndicator` | 1 | — | — | §8 |
| `$NautilusSidebar` | 1 | — | — | §3 |
| `$NautilusToolbar` | 1 | — | — | §2 |
| `Adw.TabBar` | 1 | — | — | hidden under breakpoint |
| `Adw.TabView` | 1 | — | `close-page`, `setup-menu`, `notify::selected-page`, `create-window`, `page-attached`, `page-detached` | `tab_menu_model` |
| `$NautilusNetworkAddressBar` | 1 | — | — | §6, hidden by default |
| `Gtk.ActionBar` | 1 | — | — | revealed only when narrow |
| `$NautilusHistoryControls` | 1 | — | — | §2 |
| `$NautilusViewControls` | 1 | — | — | §2 |
| `Adw.TabButton` | 1 | — | `win.open-tab-overview` | — |
| `Adw.Breakpoint` | 1 | — | `max-width: 682sp` | 9 setters |
| `Gtk.PadController` | 2 | — | — | built in `.c` |

Menus in this file: `app_menu` (3 sections, 10 items incl. a rebuilt
undo/redo section), `tab_menu_model` (3 sections, 7 items),
`tab_overview_menu_model` (2 items).

`win.` actions (13): `new-tab`, `open-tab-overview`, `close-current-view`,
`close-other-tabs`, `restore-tab`, `tab-move-left`, `tab-move-right`,
`tab-move-new-window`, `go-to-tab`, `go-home`, `toggle-sidebar`, `undo`,
`redo`, `current-location-menu`.

### `src/nautilus-window-slot.c` → `lib/nautilus/window_slot.rb`

No blueprint; built entirely in code. One tab's content: view stack,
query editor, banners, location handling.

| Widget | × | Notes |
|---|---:|---|
| `Gtk.Box` | 2 | slot layout |
| `$NautilusFilesView` / `$NautilusNetworkView` | 1 (switched) | current view |
| `$NautilusQueryEditor` | 1 | §5 |
| `$NautilusXContentBar` | 1 | §7, conditional on removable media |
| location banner (`Adw.Banner`) | 1 | §7 |
| `Gtk.Shortcut` + `Gtk.NamedAction` | 3 | — |

`slot.` actions (18): `back`, `back-n`, `forward`, `forward-n`, `up`,
`down`, `reload`, `stop`, `open-location`, `files-view-mode`,
`files-view-mode-toggle`, `search-visible`, `search-global`,
`focus-search`, `bookmark-current-directory`,
`unbookmark-current-directory`, `star-current-directory`,
`unstar-current-directory`.

---

## 2. Toolbar and its controls

### `src/resources/ui/nautilus-toolbar.blp` + `src/nautilus-toolbar.c` → `lib/nautilus/toolbar.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | — | — |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Gtk.Box` (`header_toolbar`) | 1 | — | — | spacing 6 |
| `Gtk.Stack` (`toolbar_switcher`) | 1 | — | crossfade | 3 pages: pathbar / location / search |
| `$NautilusPathBar` | 1 | — | — | §4 |
| `Gtk.Box` (`linked`) | 1 | `linked` | — | location entry + cancel |
| `$NautilusLocationEntry` | 1 | — | — | §4 |
| `Gtk.Button` (cancel) | 1 | — | `clicked` → close location entry | `window-close-symbolic` |
| `Gtk.Box` (`search_container`) | 1 | — | — | hosts query editor |
| `Gtk.Stack` (`search_button_stack`) | 1 | — | crossfade | — |
| `Gtk.ToggleButton` (`search_button`) | 1 | — | `slot.search-visible` | `nautilus-folder-search-symbolic` |
| `Adw.Bin` placeholders | 2 | — | — | search + history placeholders |
| `Gtk.ToggleButton` (`show_sidebar_button`) | 1 | — | bidirectional bind | `sidebar-show-symbolic` |
| `Gtk.Stack` (`history_controls_stack`) | 1 | — | crossfade | — |
| `$NautilusHistoryControls` | 1 | — | — | — |
| `$NautilusViewControls` | 1 | — | — | — |
| `Gtk.Button` (`new_folder_button`) | 1 | — | `view.new-folder` | `folder-new-symbolic` |

Also installs `toolbar.edit-location` (referenced from the pathbar).

### `src/resources/ui/nautilus-history-controls.blp` + `.c` → `lib/nautilus/history_controls.rb`

| Widget | × | Actions | Notes |
|---|---:|---|---|
| `Adw.Bin` (root) | 1 | — | — |
| `Gtk.Box` | 1 | — | spacing 6 |
| `Gtk.Button` back / forward | 2 | `slot.back`, `slot.forward` | `go-previous/next-symbolic` |
| `Gtk.PopoverMenu` | 2 | — | top-level named roots `back_menu`, `forward_menu`; filled from history in `.c` (repeater) |

### `src/resources/ui/nautilus-view-controls.blp` + `.c` → `lib/nautilus/view_controls.rb`

| Widget | × | CSS | Actions | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (root) | 1 | — | — | — |
| `Adw.SplitButton` | 1 | — | `slot.files-view-mode-toggle` | icon + tooltip bound to slot |
| `Gtk.PopoverMenu` | 1 | — | `view_menu` | — |
| `Gtk.Button` zoom out / in | 2 | `flat` | `view.zoom-out`, `view.zoom-in` | `custom:` slots |

`view_menu`: 5 sections — "Icon Size" (inline-buttons, 2 `custom:` slots),
"Sort" (contents supplied by the view — the sort section below),
`view.show-hidden-files` (accel `<control>h`), `view.visible-columns`,
`view.visible-captions`.

### `src/resources/menu/nautilus-toolbar-view-menu.ui` → folded into `lib/nautilus/view_controls.rb`

`sort_section`: 8 items, all `view.sort` with `(sb)` targets — A-Z, Z-A,
Last Modified, First Modified, Size, Type, Last Trashed, Recency,
Relevance.

---

## 3. Sidebar

### `src/nautilus-sidebar.c` → `lib/nautilus/sidebar.rb`

No blueprint; 4343 lines built in code. The places sidebar.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` | 1 | — | — | — |
| `Gtk.ListBox` | 1 | `navigation-sidebar` | `row-activated` | a11y label "Sidebar" |
| `$NautilusSidebarRow` | N | — | — | repeater over places |
| section headers (`Gtk.Label`) | 2 | — | — | "Device", "Network" |
| `Gtk.Separator` | 1 | — | — | — |
| new-bookmark row | 1 | `sidebar-new-bookmark-row` | drop target | "Add a new bookmark" |
| `Gtk.PopoverMenu` | 2 | — | — | row context menu + rename popover |
| `Gtk.Popover` + `Gtk.Entry` + `Gtk.Button` (`suggested-action`) | 1 | `suggested-action` | — | rename bookmark; "This name is already taken" error state |
| `Gtk.Grid` | 1 | — | — | rename popover layout |
| `Gtk.GestureClick`, `Gtk.GestureLongPress`, `Gtk.GestureDrag`, `Gtk.EventControllerKey`, `Gtk.DropTarget` | 5 | — | — | controllers: context menu, reorder, DnD |
| `Gtk.MountOperation` | 2 | — | — | mount/unlock |

Built-in places: Recent, Starred, Home, Desktop, Trash, bookmarks,
drives/volumes/mounts, Network. Dynamic CSS: `has-open-popup` on the row
whose popup is open.

`row.` actions (14): `open`, `open-other`, `mount`, `unmount`, `eject`,
`rescan`, `start`, `stop`, `format`, `remove`, `rename`, `properties`,
`empty-trash`, `history-trash-settings`.

Error states: "Unable to access “%s”", "Unable to eject “%s”",
"Unable to start “%s”", "Unable to poll “%s” for media changes",
"Error unlocking “%s”".

### `src/resources/ui/nautilus-sidebar-row.blp` + `.c` → `lib/nautilus/sidebar_row.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` (root) | 1 | — | — | `focus-on-click: false` |
| `Gtk.Revealer` | 1 | `sidebar-revealer` | `notify::child-revealed` | — |
| `Gtk.Box` | 1 | — | — | — |
| `Gtk.Image` start / end | 2 | — | — | end icon hidden by default |
| `Gtk.Label` | 1 | — | — | ellipsize middle, a11y labeller |
| `Gtk.Button` (eject) | 1 | `sidebar-button` | — | `media-eject-symbolic` |
| `Adw.Spinner` | 1 | — | — | hidden, opacity 0.7 |

---

## 4. Path bar and location entry

### `src/nautilus-pathbar.c` → `lib/nautilus/pathbar.rb`

No blueprint. 1418 lines.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` + `Gtk.Viewport` + `Gtk.Adjustment` | 1 each | `nautilus-pathbar` | `Gtk.EventControllerScroll` | horizontal scroll of buttons |
| `Gtk.Box` | 5 | — | — | container + per-button boxes |
| `Gtk.Button` (path button) | N | `nautilus-path-button` | `clicked`, `Gtk.GestureClick` (right-click), `Gtk.DropTarget` | repeater, one per path segment |
| `Gtk.Image` | 2 | — | — | root/home icons |
| `Gtk.Label` | 3 | `dim-label` (separator) | — | button label + separators |
| `Gtk.MenuButton` (current folder) | 1 | — | `current-view-menu` | "Current Folder Menu" |
| `Gtk.PopoverMenu` | 2 | — | `button-menu`, `current-view-menu` | — |

Special labels: "Home", "Operating System", "Administrator Root".
`pathbar.` actions (3): `open-item-new-window`, `open-item-new-tab`,
`properties`.

### `src/resources/menu/nautilus-pathbar-context-menu.ui` → folded into `lib/nautilus/pathbar.rb`

Two menus. `button-menu`: 3 items. `current-view-menu`: 5 sections, 15
items — New Folder…, New Document (submenu), Open With…, Open in Console,
R_eload, St_op, Add/Remove Bookmarks, Star/Unstar Folder, Copy Location,
Open in File Manager, Paste, Paste as Link, Select All, Empty Trash…,
Properties — plus a `background-extensions-section` extension slot.

### `src/nautilus-location-entry.c` → `lib/nautilus/location_entry.rb`

| Widget | × | Notes |
|---|---:|---|
| `Gtk.Entry` subclass | 1 | with `Gtk.EntryIconPosition` clear icon |
| `Gtk.EntryCompletion` + `Gtk.ListStore` + `Gtk.CellRendererText` | 1 each | path completion (not widgets, but required behaviour) |
| `Gtk.EventControllerKey` | 1 | Tab completion, Escape |
| `Gtk.Shortcut` / `Gtk.SignalAction` / `Gtk.KeyvalTrigger` | 1 each | — |

---

## 5. Views, cells and search

### `src/resources/ui/nautilus-files-view.blp` + `src/nautilus-files-view.c` → `lib/nautilus/files_view.rb`

The blueprint is 17 lines; the `.c` is the biggest user-facing file in the
tree and carries 64 `view.` actions and the context menus.

| Widget | × | Notes |
|---|---:|---|
| `Adw.Bin` (root) | 1 | — |
| `Gtk.Overlay` | 1 | hosts the view + floating bar |
| `$NautilusFloatingBar` | 1 | overlay child, `show-spinner` bound to `loading` |
| `Gtk.PopoverMenu` | 2 | background menu + selection menu (built from the menu `.ui`) |
| `Adw.AlertDialog` | several | delete/trash/empty-trash confirmations (error & confirm states) |

`view.` actions (64): `new-folder`, `new-folder-with-selection`,
`template-empty`, `open-with-default-application`,
`open-with-other-application`, `open-current-directory-with-other-application`,
`open-current-directory-with-files`, `open-item-new-tab`,
`open-item-new-window`, `open-item-location`, `open-scripts-folder`,
`console`, `current-directory-console`, `run-in-terminal`,
`extract-here`, `extract-to`, `compress`, `cut`, `copy`, `paste`,
`paste-into`, `move-to`, `copy-to`, `copy-current-location`,
`copy-network-address`, `create-link`, `create-link-in-place`,
`create-link-shortcut`, `create-link-in-place-shortcut`, `rename`,
`move-to-trash`, `delete-from-trash`, `delete-permanently-menu-item`,
`permanent-delete-permanently-menu-item`, `delete-permanently-shortcut`,
`restore-from-trash`, `remove-from-recent`, `remove-recent-server`,
`empty-trash`, `star`, `unstar`, `properties`,
`current-directory-properties`, `select-all`, `invert-selection`,
`select-pattern`, `show-hidden-files`, `sort`, `zoom-in`, `zoom-out`,
`zoom-standard`, `visible-columns`, `visible-captions`,
`preview-selection`, `popup-menu`, `set-as-wallpaper`, `send-email`,
`mount-volume`, `unmount-volume`, `eject-volume`, `start-volume`,
`stop-volume`, `detect-media`.

### `src/resources/menu/nautilus-files-view-context-menus.ui` → folded into `lib/nautilus/files_view.rb`

`background-menu`: 5 sections, 9 items + `background-extensions-section`.
`selection-menu`: 9 sections, ~40 items, incl. an "Open" submenu (2
sections, 5 items), a "_Scripts" submenu with a `scripts-submenu-section`
repeater, `drive-section` (6 items), `move-copy-section` (4),
`file-actions-section` (13), `network-view-section` (2), plus
`new-folder-with-selection-section`, `open-with-application-section` and
`selection-extensions-section` extension slots.

### `src/nautilus-list-base.c` + `nautilus-list-base-private.h` → `lib/nautilus/list_base.rb`

Abstract base for all three views: selection, DnD, zoom, rubberband.

| Item | × | Notes |
|---|---:|---|
| `Gtk.ListBase` subclass plumbing | 1 | — |
| `Gtk.DropTarget` | 13 | DnD onto items and background |
| `Gtk.DropControllerMotion` | 3 | auto-expand/scroll while dragging |
| `Gtk.GestureClick` | 4 | activate, context menu, rubberband |
| `Gtk.Bitset` selection handling | 3 | — |
| actions | 2 | `view.zoom-in`, `view.zoom-out` |
| CSS | — | `rubberband`, `.cutout` (cut files) |

### `src/nautilus-list-view.c` → `lib/nautilus/list_view.rb`

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Gtk.ColumnView` | 3 refs | `nautilus-list-view` | — |
| `Gtk.ColumnViewColumn` | 8 | — | name, size, type, modified, detailed type, accessed, created, trashed, starred, recency, relevance (per `nautilus-column-utilities.c`) |
| `Gtk.SignalListItemFactory` | 6 | — | one per cell kind |
| `Gtk.TreeExpander` / `Gtk.TreeListRow` | 4 / 10 | — | expandable folders |
| `Gtk.CustomSorter` | 2 | — | — |
| actions | 3 | — | `listitem.collapse`, `view.sort`, `slot.reload` |

### `src/nautilus-grid-view.c` → `lib/nautilus/grid_view.rb`

`Gtk.GridView` (9 refs), `Gtk.SignalListItemFactory` ×3,
`Gtk.CustomSorter`, `Gtk.ScrollInfo`, shortcut triggers ×2.
CSS: `nautilus-grid-view`.

### `src/nautilus-network-view.c` → `lib/nautilus/network_view.rb`

`Gtk.ListView` (9 refs) with `Gtk.ListHeader` ×2 section headers,
`Gtk.SignalListItemFactory` ×5, `Gtk.CustomSorter` ×2.
CSS: `nautilus-network-view`.

### Cells

| Upstream | `lib/*.rb` | Widgets |
|---|---|---|
| `nautilus-view-cell.c` | `lib/nautilus/view_cell.rb` | base `Gtk.Widget` subclass, `Gtk.ListItem` binding |
| `nautilus-grid-cell.c` + `.blp` | `lib/nautilus/grid_cell.rb` | `$NautilusImage`, emblems `Gtk.Box` (`dim-label`), labels `Gtk.Box` (`icon-ui-labels-box`), `Gtk.Label` (3 lines, `query-tooltip`) |
| `nautilus-name-cell.c` + `.blp` | `lib/nautilus/name_cell.rb` | `Gtk.TreeExpander`, `Gtk.CenterBox`, `$NautilusImage`, `Gtk.Label` name + path (`caption dim-label`), emblems box, `Adw.Spinner`, `Gtk.MenuButton` snippet (`fts-snippet`) + `Gtk.Popover` + `Gtk.Label`; CSS `column-name-labels-box` |
| `nautilus-label-cell.c` | `lib/nautilus/label_cell.rb` | one `Gtk.Label` per column |
| `nautilus-star-cell.c` | `lib/nautilus/star_cell.rb` | `Gtk.Button` ×2 (star/unstar toggle) |
| `nautilus-network-cell.c` + `.blp` | `lib/nautilus/network_cell.rb` | `Gtk.Image` (`network-icon`), name + `target_uri` labels, `Adw.Spinner`, `Gtk.Button` unmount (`flat circular`, `clicked`) |
| `nautilus-minimal-cell.c` | `lib/nautilus/minimal_cell.rb` | data object (title/subtitle/paintable) used by the file-types dialog list |
| `nautilus-image.c` | `lib/nautilus/image.rb` | custom `Gtk.Widget` painting icon/thumbnail; CSS `image-frame`; 947 lines |

### `src/nautilus-query-editor.c` → `lib/nautilus/query_editor.rb`

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Gtk.Box`-based widget | 1 | `nautilus-query-editor` | — |
| `Gtk.Text` (`gtk_text_new`) | 1 | — | search entry text |
| `Gtk.MenuButton` | 2 | — | filter popover + scope |
| `Gtk.Image` | 2 | — | — |
| `Gtk.Button` | 1 | — | clear |
| `Gtk.Popover` | 1 | — | hosts the search popover |
| `Gtk.GestureClick` ×2, `Gtk.EventControllerKey`, `Gtk.Shortcut`/`Gtk.SignalAction`/`Gtk.KeyvalTrigger` | — | — | — |

### `src/resources/ui/nautilus-search-popover.blp` + `.c` → `lib/nautilus/search_popover.rb`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Popover` (root) + `Gtk.ScrolledWindow` + `Gtk.Box` | 1 each | — | — | — |
| `Gtk.Label` headers | 3 | `heading` | — | File Types / date / Text Matching; in a vertical `Gtk.SizeGroup` |
| `Adw.WrapBox` | 3 | — | — | child/line spacing 6 |
| `Gtk.Button` type filters | 10 | — | `file_types_button_clicked` | Audio, Documents, Folders, Images, PDF, Spreadsheets, Text, Videos, `specific_type_button` (hidden), `other_types_button` (`circular`) |
| `Gtk.MenuButton` time type | 1 | — | — | inline menu, 3 items on `search-popover.time-type-changed` (last_used / last_modified / created) |
| `Gtk.Button` date filters | 7 | — | `date_button_clicked`, `show_date_range_dialog_cb` | Today, Yesterday, Past Week, Past Month, Past Year, `specific_date_button` (hidden), custom-range (`circular`) |
| `Gtk.Button` FTS options | 3 | — | `fts_option_clicked` | Content & Filename, Only Filename, Only Contents (hidden — unimplemented upstream) |

### `src/resources/ui/nautilus-search-types-dialog.blp` → `lib/nautilus/search_types_dialog.rb`

Named root `file_types_dialog` (no template, no backing class file — owned
by the search popover).

| Widget | × | CSS | Notes |
|---|---:|---|---|
| `Adw.Dialog` | 1 | — | "Add File Type Filter" |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | no title buttons |
| `Gtk.Button` cancel / select | 2 | `suggested-action` (select) | in a `Gtk.SizeGroup`; select insensitive initially |
| `Adw.Bin` | 1 | `toolbar` | wraps the search entry |
| `Gtk.SearchEntry` | 1 | — | "Search for file types" |
| `Gtk.Stack` | 1 | — | 3 pages |
| `Adw.StatusPage` | 2 | — | **empty state** "Search File Types"; **no-results state** "No Results Found" / "Try a different search" |
| `Gtk.ListView` + `BuilderListItemFactory` | 1 | — | rows: `Gtk.Image` 32px + title + subtitle (`caption dim-label`) over `$NautilusMinimalCell` |

### `src/resources/ui/nautilus-date-range-dialog.blp` + `.c` → `lib/nautilus/date_range_dialog.rb`

`Adw.Dialog` "Add Date Filter" → `Adw.ToolbarView`/`Adw.HeaderBar` with
`Adw.WindowTitle` "Filter by Date"; `Adw.PreferencesPage` with
`Adw.ComboRow` (`Gtk.StringList` of 6: Single Day, ± 1/3/7/14 days,
Specify Range) and three `$NautilusDateEntryRow` (Date, From, To — the
latter two visible only in Specify Range mode) and a `Gtk.Button`
"_Filter" (`pill suggested-action`).

### `src/resources/ui/nautilus-date-entry-row.blp` + `.c` → `lib/nautilus/date_entry_row.rb`

`Adw.EntryRow` (root, `changed`) with a suffix `Gtk.MenuButton` (`flat`,
`x-office-calendar-symbolic`, "Pick Date", direction left) → `Gtk.Popover`
→ `Gtk.Calendar` (`day-selected`).

---

## 6. Dialogs

| Upstream | `lib/*.rb` | Root | Key components |
|---|---|---|---|
| `nautilus-preferences-dialog.{c,blp}` | `lib/nautilus/preferences_dialog.rb` | `Adw.PreferencesDialog` (named root, search enabled) | 1 page, 5 groups: General (2 `Adw.SwitchRow`, `Adw.ActionRow` + `Adw.ToggleGroup` with 2 `Adw.Toggle` single/double-click); Optional Context Menu Actions (2 `Adw.SwitchRow`); Performance (3 `Adw.ComboRow`); Date and Time Format (2 `Adw.ActionRow` + grouped `Gtk.CheckButton`, action `preferences.date-time-format` targets `'simple'`/`'detailed'`) |
| `shortcuts-dialog.blp` | `lib/nautilus/shortcuts_dialog.rb` | `Adw.ShortcutsDialog` (named root, **no backing `.c`**) | 18 `Adw.ShortcutsSection` (Actions, View, Select, Navigation, Search, Windows & Tabs, App) / 56 `Adw.ShortcutsItem` |
| `nautilus-properties.{c,h}` + `nautilus-properties-window.blp` + `nautilus-properties-widget.blp` | `lib/nautilus/properties.rb` (+ `lib/nautilus/properties_widget.rb`) | `Adw.Window` named root + `Adw.Bin` template | 3 `Adw.NavigationPage` (Loading… / Properties / Set Custom Permissions / extension page); star + popout buttons (`external-link-symbolic`); icon `Gtk.Stack` with overlay edit + remove-custom-icon buttons; name/type/size/contents/free-space labels; `disk_group` with `Gtk.LevelBar` and `.disk-space-used`/`.disk-space-free` legend; `Adw.ButtonRow` "Open in Disks"; `locations_group` (link target, parent folder rows + `folder-open-symbolic` buttons); `trashed_group`; `times_group` (accessed/modified/created); permissions navigation row + `Adw.SwitchRow` executable; `extension_models_group`; permissions page: `Adw.Banner` "Only the owner can edit these permissions", `Adw.StatusPage` "Unknown Permissions" error state, 30 `Adw.ComboRow`, security-context row, `Adw.ButtonRow` "Change Permissions for _Enclosed Files…". CSS `nautilus-properties`. 4112 lines |
| `nautilus-file-properties-change-permissions.blp` | `lib/nautilus/change_permissions_dialog.rb` | `Adw.Dialog` named root (owned by properties) | 3 `Adw.PreferencesGroup` (Owner/Group/Others) × 2 `Adw.ComboRow` = 6; cancel + `C_hange` (`suggested-action`); `Gtk.ShortcutController` Escape |
| `nautilus-new-folder-dialog.{c,blp}` | `lib/nautilus/new_folder_dialog.rb` | `Adw.Dialog` template | `Adw.EntryRow` name, `Gtk.Revealer` + warning `Gtk.Label` (`warning caption`) feedback state, `Gtk.Button` `_Create` (`pill suggested-action`), `$NautilusFilenameValidator` |
| `nautilus-compress-dialog.{c,blp}` | `lib/nautilus/compress_dialog.rb` | `Adw.Dialog` template | `Adw.EntryRow` name + feedback revealer, `Adw.ComboRow` compression method, encryption group with 2 `Adw.PasswordEntryRow`, `C_ompress` (`suggested-action`) with a multi-arg sensitivity binding, validator |
| `nautilus-batch-rename-dialog.{c,blp}` | `lib/nautilus/batch_rename_dialog.rb` | `Adw.Dialog` template | `Adw.Breakpoint` (480sp); 2 grouped `Gtk.CheckButton` mode switcher; `Gtk.Stack` Format/Replace; `Gtk.Entry` + `Gtk.MenuButton` (`add_tag_menu`: 3 sections, 12 items) in a `linked` box; numbering `Gtk.Revealer` + `Gtk.MenuButton` (`numbering_order_menu`, 4 items); `Gtk.ListView` preview (`batch-rename-preview`, `BuilderListItemFactory`, `.conflict-row` dynamic CSS, `Gio.ListStore`); bottom `toolbar` with conflict label and 2 `flat` nav buttons. 14 `dialog.` actions |
| `nautilus-batch-rename-item.c` | `lib/nautilus/batch_rename_item.rb` | plain object | name-before / name-after / has-conflict, drives the preview rows |
| `nautilus-rename-file-popover.{c,blp}` | `lib/nautilus/rename_file_popover.rb` | `Gtk.Popover` template | `title-2` label, `Gtk.Entry` (a11y "New Filename"), feedback revealer, `_Rename` (`suggested-action`), validator |
| `nautilus-column-chooser.{c,blp}` | `lib/nautilus/column_chooser.rb` | `Adw.Dialog` template | `Adw.Banner` "This folder uses custom settings" / `_Revert`; `Adw.PreferencesPage` + `Gtk.ListBox` (`boxed-list`) of column rows (repeater); bottom `Adw.SwitchRow` "_Only Apply to Current Folder"; `row_button_menu` (`column-chooser.move-up`/`move-down`) |
| `nautilus-grid-view-captions-dialog.{c,blp}` | `lib/nautilus/grid_view_captions_dialog.rb` | `Adw.Dialog` template | `Adw.WindowTitle` "Grid View Captions", 3 `Adw.ComboRow` (First/Second/Third) |
| `nautilus-files-view-select-items.blp` | `lib/nautilus/select_items_dialog.rb` | `Adw.Dialog` named root (owned by files view) | "Select Items Matching"; `heading` label, `Gtk.Entry` pattern, example label, cancel + `_Select` (`suggested-action`) |
| `nautilus-app-chooser.{c,blp}` | `lib/nautilus/app_chooser.rb` | `Adw.Dialog` template | "Open File"; `Gtk.SearchEntry` in a `toolbar` bin; `Adw.Clamp` + description label; `$NautilusAppChooserWidget`; bottom `Gtk.ListBox` (`background`) with `Adw.SwitchRow` "Always use for this file type"; cancel + `_Open` (`suggested-action`) |
| `nautilus-app-chooser-widget.{c,blp}` | `lib/nautilus/app_chooser_widget.rb` | `Adw.Bin` template | `Gtk.Stack` 2 pages: `Gtk.ListView` in a framed `Gtk.ScrolledWindow`; **empty state** `Gtk.Image` (`dim-label`) + "No applications found" |
| `nautilus-file-conflict-dialog.{c,blp}` | `lib/nautilus/file_conflict_dialog.rb` | `Adw.Window` template | 4 header buttons (Cancel, Skip, Rename hidden, Replace — both `suggested-action`); `title-2` primary + secondary labels; 2 `$NautilusImage` 48px + labels; `Gtk.Expander` "Select a _new name…" with `linked` `Gtk.Entry` + `R_eset`; `Gtk.CheckButton` "apply to all"; Escape `Gtk.ShortcutController` |
| `nautilus-operations-ui-manager-request-passphrase.blp` + `nautilus-operations-ui-manager.c` | `lib/nautilus/operations_ui_manager.rb` | `Adw.AlertDialog` named root | "Password Required" with `Gtk.PasswordEntry` (peek icon), responses cancel / Extract (suggested); plus the conflict and app-chooser orchestration |
| `nautilus-dialog-utilities.c` | `lib/nautilus/dialog_utilities.rb` | — | 3 `Adw.AlertDialog` builders used for generic confirm/error prompts |
| `nautilus-error-reporting.c` | `lib/nautilus/error_reporting.rb` | — | rename/display/permissions **error states** reported as alert dialogs |
| `nautilus-mime-actions.c` | `lib/nautilus/mime_actions.rb` | — | 5 `adw_alert_dialog_new` sites (unknown type, too many windows, no handler, untrusted launcher, mount prompts), `Gtk.FileLauncher` ×3, `Gtk.MountOperation` ×3. 2353 lines |
| `nautilus-file-chooser.{c,blp}` | `lib/nautilus/file_chooser.rb` | `Adw.Window` template | Portal file chooser: `Adw.OverlaySplitView` + sidebar + `$NautilusToolbar`; `Adw.MultiLayoutView` with wide/narrow `Adw.Layout` and 4 `Adw.LayoutSlot`; filename `Gtk.Stack` (button-with-overlay-undo ↔ `Gtk.Entry`, `Gtk.EventControllerFocus`); `accept_button` (`pill suggested-action`, `chooser.accept`); `choices_menu_button`; `filters_dropdown` (`flat-dropdown`, 2 factories); `Gtk.DropTarget`; `Adw.Breakpoint` 682sp; CSS `nautilus-file-chooser`. Actions `chooser.accept`, `chooser.focus-entry` |

---

## 7. Banners, bars and empty/error states

| Upstream | `lib/*.rb` | Kind | Components |
|---|---|---|---|
| `nautilus-location-banner.c` | `lib/nautilus/location_banner.rb` | banner set | 11 `Adw.Banner` configurations: NONE, SCRIPTS ("Executable files in this folder will appear in the Scripts menu"), SHARING (2 variants), TEMPLATES, TRASH, TRASH_AUTO_EMPTIED (with button label → `Gtk.UriLauncher` to settings) |
| `nautilus-floating-bar.c` | `lib/nautilus/floating_bar.rb` | overlay status bar | `Gtk.Box` + 2 `Gtk.Label` (primary/details) + `Adw.Spinner` + `Gtk.Button` (`circular flat`, stop) ; `Gtk.EventControllerMotion` ×2 to move out of the pointer's way; `stop` signal; CSS `floating-bar` |
| `nautilus-x-content-bar.c` | `lib/nautilus/x_content_bar.rb` | info bar | `Adw.Bin` + `Gtk.InfoBar` + `Gtk.Image` + 2 `Gtk.Label` + action buttons for autorun content types |
| `nautilus-network-address-bar.{c,blp}` | `lib/nautilus/network_address_bar.rb` | bottom bar + popover | `Gtk.Box` (`toolbar`) with url `Gtk.Entry`, `Con_nect` `Gtk.Button`, `Gtk.MenuButton` (`flat circular`, `info-outline-symbolic`); named-root `server_adresses_popover` with `title-4`/`heading` labels and a `Gtk.Grid` of protocols (repeater) |
| `nautilus-recent-servers.c` | `lib/nautilus/recent_servers.rb` | model | backs the network view's recent-servers section |

---

## 8. Progress reporting

| Upstream | `lib/*.rb` | Components |
|---|---|---|
| `nautilus-progress-indicator.{c,blp}` | `lib/nautilus/progress_indicator.rb` | `Adw.Bin` (`nautilus-progress-indicator`) → `Gtk.MenuButton` (`flat`, "Show File Operations", direction right) → `Gtk.Popover` → `Gtk.ScrolledWindow` → `Gtk.ListBox` (`operations-list`, repeater of progress widgets); plus a `Gtk.ListView` with a `BuilderListItemFactory` (icon + short-status label) for the collapsed sidebar form; `notify::visible` handler |
| `nautilus-progress-info-widget.{c,blp}` | `lib/nautilus/progress_info_widget.rb` | `Gtk.Grid` template: `Gtk.Label` status, `Gtk.ProgressBar`, `Gtk.Button` cancel (`circular`, `cancel-operation-symbolic`), `Gtk.Label` details (`dim-label numeric`) |
| `nautilus-progress-paintable.c` | `lib/nautilus/progress_paintable.rb` | `Gtk.SymbolicPaintable` implementation with `Adw.TimedAnimation` + `Adw.CallbackAnimationTarget` — the animated progress icon |
| `nautilus-progress-persistence-handler.c` | `lib/nautilus/progress_persistence_handler.rb` | desktop notifications for finished operations ("File Operations", "Files" notifications) |

---

## 9. Supporting user-facing units

| Upstream | `lib/*.rb` | Kind | Note |
|---|---|---|---|
| `nautilus-shortcut-manager.c` | `lib/nautilus/shortcut_manager.rb` | `Gtk.ShortcutManager` impl | 52 lines; wrapped around window and file-chooser content so managed shortcut scopes work |
| `nautilus-filename-validator.c` | `lib/nautilus/filename_validator.rb` | validator object | drives the `has-feedback` / `feedback-text` / `passed` / `will-overwrite` states of 4 dialogs; all its feedback strings are user-facing |
| `nautilus-column-utilities.c` | `lib/nautilus/column_utilities.rb` | column definitions | the 11 list-view columns and their labels; feeds the column chooser |
| `nautilus-global-preferences.c` | `lib/nautilus/global_preferences.rb` | GSettings access | 3 schemas (`org.gnome.nautilus.preferences`, `.list-view`, `.icon-view`), 11 keys, 10 enums |
| `nautilus-ui-utilities.c` | `lib/nautilus/ui_utilities.rb` | helpers | menu-model manipulation, date formatting for the UI |
| `nautilus-date-utilities.c` | `lib/nautilus/date_utilities.rb` | helpers | "simple"/"detailed" date strings shown in views and properties |
| `nautilus-previewer.c` | `lib/nautilus/previewer.rb` | D-Bus client | Sushi preview window; forwards `view.rename` / `view.move-to-trash` |
| `nautilus-dbus-launcher.c` | `lib/nautilus/dbus_launcher.rb` | D-Bus client | opens Console, Disks, Settings from menu items |
| `nautilus-file-operations.c` | `lib/nautilus/file_operations.rb` | operations + prompts | 10k+ lines; owns most of the app's user-visible strings and confirmation dialogs |
| `nautilus-file-undo-operations.c` | `lib/nautilus/file_undo_operations.rb` | undo descriptions | the `win.undo`/`win.redo` labels and toasts |
| `nautilus-clipboard.c` | `lib/nautilus/clipboard.rb` | clipboard | cut/copy/paste plumbing behind `view.cut`/`copy`/`paste` |
| `nautilus-dnd.c` + `nautilus-files-view-dnd.c` | `lib/nautilus/dnd.rb` | DnD | drop menus ("Move Here"/"Copy Here"/"Link Here"), drag icons |
| `nautilus-shell-search-provider.c` | `lib/nautilus/shell_search_provider.rb` | D-Bus service | GNOME Shell search results |
| `nautilus-autorun-software.c` | `lib/nautilus/autorun_software.rb` | separate binary | autorun confirmation dialog |
| `src/resources/style.css` | `lib/nautilus/style.rb` (or a `data/` CSS asset) | stylesheet | 18 app classes: `batch-rename-preview`, `conflict-row`, `cutout`, `disk-space-free`, `disk-space-used`, `floating-bar`, `image-frame`, `nautilus-app-chooser`, `nautilus-file-chooser`, `nautilus-grid-view`, `nautilus-list-view`, `nautilus-network-view`, `nautilus-pathbar`, `nautilus-path-button`, `nautilus-progress-indicator`, `nautilus-properties`, `nautilus-query-editor`, `operations-list` |

Not user-facing, listed for completeness and deliberately **out of the
component inventory**: the model/IO layer (`nautilus-file*.c`,
`nautilus-directory*.c`, `nautilus-search-engine*.c`, `nautilus-query.c`,
`nautilus-bookmark*.c`, `nautilus-tag-manager.c`, `nautilus-thumbnails.c`,
`nautilus-icon-info.c`, `nautilus-monitor.c`, `nautilus-metadata.c`,
`nautilus-view-model.c`, `nautilus-view-item.c`,
`nautilus-view-item-filter.c`, `nautilus-module.c`, the D-Bus/portal
plumbing, `libnautilus-extension/` and `extensions/`). These are needed to
make the components work, but they are not components.

---

## Blockers / open questions

1. **Scale.** 66 user-facing `src/*.c` files, 36 blueprint files, ~70 port
   files, 123 actions. This is an order of magnitude larger than the pilot
   port (29 `lib/*.rb`). Parity needs to be planned as units, not as one pass.
2. **No `PLAN.md`** on `ruby`. Unit boundaries above were derived from
   template roots per the skill's fallback rule.
3. **`libnautilus-extension`** is a public C ABI for third-party extensions.
   A Ruby port cannot reproduce it; the extension slots in the context menus
   (`background-extensions-section`, `selection-extensions-section`,
   `scripts-submenu-section`) and the extension pages in the properties
   dialog will be empty unless a Ruby-side plugin story is invented.
4. **D-Bus surfaces** (`org.freedesktop.FileManager1`, the search provider,
   the `org.freedesktop.impl.portal.FileChooser` portal, `nautilus-portal.c`,
   `nautilus-portal-request.c`) are part of the app's behaviour but not of
   its widget tree. Decide whether they are in scope before the file chooser
   unit, since `nautilus-file-chooser.c` exists only to serve the portal.
5. **Binding gaps to verify with the `ruby-gtk` skill before planning:**
   `Adw.ShortcutsDialog` / `Adw.ShortcutsSection` / `Adw.ShortcutsItem`,
   `Adw.WrapBox`, `Adw.MultiLayoutView` / `Adw.Layout` / `Adw.LayoutSlot`,
   `Adw.ToggleGroup` / `Adw.Toggle`, `Adw.ButtonRow`, `Adw.Spinner`,
   `Gtk.ColumnView` + `Gtk.TreeListModel`, `BuilderListItemFactory`
   (house style has no `.ui`, so each of these becomes a
   `Gtk.SignalListItemFactory`), and `Gtk.SymbolicPaintable` for the
   progress paintable. Also noted in AGENTS.md: `Adwaita::Application` is
   broken in the Ruby bindings.
6. **`po/` catalogue**: 134 languages exist upstream and the port has no
   `po/` directory at all. Translation parity is a separate axis
   (`translation-parity` skill) and is not costed here.
