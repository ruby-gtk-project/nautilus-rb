# nautilus-rb — component identification

Skill: `component-identification`. Upstream read from `origin/main` (GNOME
Files / nautilus, C + blueprint, commit `ce1442753a9a6c61a508af2351653df92c6ef8e7`
as currently fetched); port read from `ruby` (this branch,
commit `d665da98e0abd3cacc8b4d85096c2bbd69453511` at audit time).

This report does not re-derive the inventory from scratch: `.reports/component-inventory.md`
already on this branch is a `component-identification`-skill survey of the
same upstream tree, file by file, widget by widget, with CSS/signal/action
counts per unit. It was checked line by line against `origin/main` during
this audit (spot-checked `nautilus-window.blp`, `nautilus-sidebar.c`,
`nautilus-properties.c`/`nautilus-properties-window.blp`, `po/POTFILES.in`,
`po/LINGUAS`) and nothing in it was found to be inflated or wrong — if
anything it undercounts, because it deliberately excludes the model/IO layer
(`nautilus-view-model.c`, `nautilus-tag-manager.c`, `nautilus-bookmark*.c`,
the search engines, etc.) as "not components," which is defensible for
*identification* but means those files' behaviour still has to be accounted
for somewhere (it is accounted for here, under component-parity, as backend
gaps that leave the UI that depends on them disabled).

That document stands as this audit's component-identification deliverable.
Headline numbers from it, reconfirmed against `origin/main` directly:

| Axis | Upstream | Method |
|---|---:|---|
| User-facing `src/nautilus-*.c` + `.h` pairs (excludes model/IO/extension plumbing) | 73 | manual walk of `src/`, cross-checked against `po/POTFILES.in` |
| Of those, matched to a `lib/nautilus/*.rb` file by name | 43 | `comm` of upstream vs. port basenames (see component-parity) |
| Of those, with **no** port file at all | **30** | same |
| `.blp` templates | 36 files, 38 named roots | `find src/resources/ui -name '*.blp'` |
| Distinct actions (`app.`/`win.`/`slot.`/`view.`/`row.`/`dialog.`/etc.) | 123 | grep of action installs across `src/*.c` |
| Keyboard-shortcut items in `shortcuts-dialog.blp` | 56 items, 18 sections | direct read of the `.blp` |
| GSettings keys / enums / schemas | 11 / 10 / 3 | `data/org.gnome.nautilus.gschema.xml` |
| `po/` languages (`LINGUAS`) | 132 | `git show origin/main:po/LINGUAS` |
| `po/` catalogue size (one representative `.po`, `de.po`) | ~1180 `msgid`s, 83 with `msgctxt` | `grep -c '^msgid '` |
| Upstream unit-test registrations (`g_test_add_func`/`g_test_add_data_func`) | 142, across 22 files under `test/display*` | `grep -rc 'g_test_add'` |

Independently re-run for this audit (not taken from the existing document):

```
$ git ls-tree -r --name-only origin/main | grep -E '^src/.*\.c$' | wc -l
118
$ git ls-tree -r --name-only origin/main | grep -E '^po/.*\.po$' | wc -l
124   # LINGUAS lists 132; 124 .po files are present as of this commit
$ find lib -name '*.rb' | wc -l
46    # + exe/nautilus, lib/nautilus.rb, lib/nautilus/rb/version.rb
```

Port side: 46 `lib/nautilus/**.rb` files plus `lib/nautilus.rb`,
`lib/nautilus/rb/version.rb` and `exe/nautilus`. No `.blp`/`.ui` files (house
style — correspondence, not a gap, per `ruby-gtk`). No `po/` directory at
all. No GSettings schema file in the port tree (`global_preferences.rb`
wraps `Gio::Settings` against upstream's schema IDs directly — the schema
*files* (`data/org.gnome.nautilus.gschema.xml.in`) are a packaging artifact
and are not re-identified here as a separate gap beyond what
component-parity already counts against `global_preferences.rb`).

## This audit's own read of the three biggest unported systems

Spot-checked directly against `origin/main`, past what `component-inventory.md`
already lists, because these three are large enough that "no" in one table
row understates them:

- **`src/nautilus-properties.c`** is 4,112 lines and owns the properties
  window, the permissions page, the "Change Permissions for Enclosed
  Files" flow, and the extension-page slots. `nautilus-properties-widget.blp`
  and `nautilus-file-properties-change-permissions.blp` are its two
  templates. None of the three has a port file. `lib/nautilus/pathbar.rb`
  and other ported files reference `view.properties` as an action name, but
  no file in `lib/` implements it — see component-parity.
- **The search stack** (`nautilus-query-editor.c`, `nautilus-search-popover.blp/.c`,
  `nautilus-search-types-dialog.blp`, `nautilus-date-range-dialog.blp/.c`,
  `nautilus-date-entry-row.blp/.c`, plus the five backend files
  `nautilus-search-engine*.c`) is entirely absent. `toolbar.rb` and
  `window.rb` both wire real buttons to the actions `slot.search-visible`
  and `slot.search-global` (`lib/nautilus/toolbar.rb:212`,
  `lib/nautilus/window.rb:197`), but no file in `lib/` installs either
  action and no query editor widget exists for either to reveal — confirmed
  by `grep -rn "add_action" lib/` turning up no `search-visible` or
  `search-global` installer anywhere in the tree. These are two
  always-visible, clickable toolbar buttons that do nothing.
- **The progress-reporting stack** (`nautilus-progress-indicator.blp/.c`,
  `nautilus-progress-info-widget.blp/.c`, `nautilus-progress-paintable.c`,
  `nautilus-progress-persistence-handler.c`) is entirely absent, and so is
  its backend (`nautilus-progress-info.c`, `nautilus-progress-info-manager.c`).
  `window.rb`'s blueprint-equivalent box for it
  (`$NautilusProgressIndicator` in `nautilus-window.blp`) has no
  counterpart widget built in `lib/nautilus/window.rb` at all — confirmed by
  reading the file; there is no bottom-bar operations button in the port.

These three alone account for roughly a third of the 30 missing files and
are large, user-visible, everyday-use surfaces (copying a large file,
right-click → Properties, searching a folder) — not edge cases.
