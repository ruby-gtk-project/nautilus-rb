# nautilus-rb — component identification

Skill: `component-identification`. Upstream read from `origin/main` (GNOME
Files / nautilus, C + blueprint, commit `ce1442753a9a6c61a508af2351653df92c6ef8e7`
as currently fetched); port read from `ruby` (this branch,
commit `be7d07f634ccc7f1d06b7f96fbd0c312e96eda5a` at this audit's time — six
commits past the `d665da98e0` this document originally audited).

## Update at `be7d07f63`: six more files exist, the backlog narrows, it does not close

The commits after the original pass (`9a60361b8`, `3bad8ae56`, `d569be85c`,
`eee248d47`, `be7d07f63`) added real port files for six of the items this
document previously listed as missing: `date_range_dialog.rb`,
`date_entry_row.rb`, `network_address_bar.rb`, `autorun_software.rb`,
`x_content_bar.rb`, `file_conflict_dialog.rb`. Re-run directly against the
live tree:

```
$ find lib/nautilus -maxdepth 1 -name '*.rb' | wc -l
54
```

(54 includes `rb/` is a subdir not matched by `-maxdepth 1`; the flat count
of top-level `lib/nautilus/*.rb` files is 54.) That raises the
"matched to an upstream file" count from 43 to **49** and lowers "missing
entirely" from 30 to **24** — see `.reports/component-parity.md`'s updated
table for the row-by-row accounting. The three biggest unported systems
named below (properties, search, progress) are **unchanged**: none of the
six newly-ported files touches any of them. `be7d07f63` itself did not add
new widgets at all — its commit message says so directly ("the remaining
gap is integration, not correctness") — it wired three previously-orphaned
files into the drive script and fixed one real bug the exercise found
(`Adwaita::AlertDialog#format_heading` not bound; see
`.reports/drive-findings.md`). None of those five files (`AutorunSoftware`,
`DateRangeDialog`, `DateEntryRow`, `BatchRenameItem`, `XContentBar`) is
reachable from any window action, menu item, or real mount event on this
branch today — they exist and pass their own drive checks in isolation, but
a user clicking around the running app cannot reach any of them. That is
recorded here as an identification-level fact (the widget exists, in a
file, with no caller), not re-litigated as a parity finding — see
component-parity and accountability-ensurance for the "built but unwired"
distinction.

This update was produced by re-reading the live tree for this audit, not by
trusting the prior document's numbers forward.

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
  `nautilus-search-types-dialog.blp`, plus the five backend files
  `nautilus-search-engine*.c`) is still absent as of `be7d07f63`. Two of its
  pieces — `nautilus-date-range-dialog.blp/.c` and
  `nautilus-date-entry-row.blp/.c` — now have a port file
  (`date_range_dialog.rb`, `date_entry_row.rb`), but neither is reachable:
  the search popover that would open either one does not exist, and
  nothing else in `lib/` calls them (confirmed by `grep -rn
  'DateRangeDialog\|DateEntryRow' lib/`, which turns up only each class's
  own file and its one sibling reference). `toolbar.rb` and
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

These three alone account for roughly a quarter of the 24 missing files
(see the Update section above for the current count) and are large,
user-visible, everyday-use surfaces (copying a large file, right-click →
Properties, searching a folder) — not edge cases.
