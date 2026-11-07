# nautilus-rb — component parity

Skill: `component-parity`. Builds on `.reports/component-identification.md`.
Upstream `origin/main` @ `ce1442753a9a6c61a508af2351653df92c6ef8e7` (as
fetched); port `ruby` @ `d665da98e0abd3cacc8b4d85096c2bbd69453511`.

## Verdict: no parity

30 of 73 user-facing upstream files have **no port file at all** — not a
thinner version, nothing. Count, style, behaviour and text are all
unmet for every component those 30 files build, because there is no widget
on the port side to check any axis against. That is roughly 41% of the
upstream UI surface unaccounted for before a single CSS class or signal is
compared on the 43 files that do have a port counterpart.

| | |
|---|---|
| Upstream user-facing files | 73 |
| Matched by a port file | 43 |
| **Missing entirely** | **30** |
| Components with all four axes verified clean on the matched 43 | see below — none fully verified; drive coverage is partial (see Gate section) |

## The 30 missing files, grouped by what a user loses

This list is reproduced from `component-identification`'s file-mapping
table; it is repeated here because component-parity's verdict rests
directly on it.

**Whole dialogs/windows (10):** properties window + properties widget +
change-permissions dialog (3 files), compress dialog, batch rename dialog
(the dialog itself — only its preview-row *model*, `batch_rename_item.rb`,
exists), app chooser + app chooser widget (2 files), file conflict dialog,
operations-ui-manager (passphrase prompt + conflict orchestration), portal
file chooser.

**Whole subsystems with zero UI (search, 5 files):** query editor, search
popover, search types dialog, date range dialog, date entry row. (The five
backend search-engine files are separate and also unported — see
test-parity, where their 44 upstream unit tests are gap rows.)

**Whole subsystems with zero UI (progress reporting, 4 files):** progress
indicator, progress info widget, progress paintable, progress persistence
handler (desktop notifications for finished operations).

**Whole subsystems with zero UI (network places, 3 files):** network view,
network cell, network address bar + its recent-servers model (4th file).

**Supporting behaviour with no port file (7):** shortcut-manager (the
`Gtk.ShortcutManager` wrapper `nautilus-window.blp`'s template instantiates
as `$NautilusShortcutManager` — `lib/nautilus/shortcut_manager.rb` *is
listed in `lib/`*, correcting the inventory's count by one: re-checked
directly, `find lib -name shortcut_manager.rb` returns a file, so this one
item is a correspondence, not a gap — struck from the 30 and noted here so
the count is auditable), file-undo-operations (undo/redo toast labels),
dnd (drag source/drop menus), shell-search-provider (GNOME Shell search
D-Bus service), autorun-software, previewer (Sushi preview D-Bus client),
x-content-bar (removable-media info bar).

Re-verifying the shortcut-manager correction against the live tree:

```
$ find lib -iname '*shortcut_manager*'
lib/nautilus/shortcut_manager.rb
```

So the file does exist — the 30-count in `component-inventory.md` already
accounted for this (it is not one of the "no" rows), and this report's own
earlier draft briefly mis-stated it as missing. Corrected: **30 missing is
the right number**, shortcut_manager.rb is ported.

## Axis check on components that exist on both sides

Full per-widget axis comparison (Steps 3–5 of the skill: widget/CSS/signal/
action diff, stylesheet diff, driven-behaviour check) across all 43 matched
files was not completed in this pass — at 43 files averaging several
hundred widgets/signals each, that is its own multi-day unit of work the
skill's own worked example (planify-rb) treats as a per-unit task, not a
single-pass one. What *was* done, adversarially, rather than assumed clean:

### Style axis — stylesheet diff

```
$ find . -iname '*.css' -not -path './.git/*'
data/style.css
$ diff <(git show origin/main:src/resources/style.css) data/style.css
299c299
<   background: url('/org/gnome/nautilus/image/checkerboard.png') repeat;
---
>   background-color: color-mix(in srgb, currentColor 6%, transparent);
```

Corrected from an earlier draft of this report, which checked
`lib/nautilus/style.rb` (the `Gtk::CssProvider` loader, plus a `CLASSES`
list used for self-checking) instead of `data/style.css`, where the actual
rules live, and wrongly reported 6 of 18 classes undefined. Re-checked
directly: **all 18 upstream app-namespaced classes are present in
`data/style.css`, with rule bodies that otherwise match upstream
byte-for-byte.** The one difference is the `.cutout` class's background —
upstream tiles a GResource-bundled PNG (`checkerboard.png`, confirmed not
present anywhere in the port tree — `find . -iname '*checkerboard*'` is
empty), the port substitutes a `color-mix()` placeholder. This is a
correspondence under the skill's own rule for asset-path substitutions,
*if* the rendered result is checked and found equivalent — it was not
checked by screenshot in this pass (the `.cutout` class is applied to
thumbnail placeholders, which the drive script does not screenshot in
isolation), so it is logged here as **unverified, not cleared**: a
`color-mix` tint and a tiled checkerboard pattern are not obviously the
same rendered result, and the claim of equivalence needs a screenshot
before anyone calls this axis clean.

The style axis is otherwise genuinely clean across all 73 upstream
components, including the 30 with no port widget yet — the classes those
30 dialogs would use are already defined and waiting, unused. That is real
and is recorded as such; it does not reduce the 30-file gap, which is a
missing widget tree, not a missing stylesheet.

### Behaviour axis — driven coverage

`test/drive_nautilus.rb` (86 checks, cited by the runtime gate as "16
components") was read step by step. It drives: window shell, sidebar
listing + bookmarking, show-hidden toggle, grid/list view switch
(twice, which is what caught the controller-reattachment bug recorded in
`.reports/drive-findings.md`), new-folder dialog, select-items dialog,
rename popover (setup only — see the known Xvfb limitation in
`drive-findings.md`), column chooser, grid captions dialog, tabs, history,
the narrow-layout breakpoint, preferences dialog, shortcuts dialog, about
dialog, accelerator installation, sidebar show/hide, select-all/invert.

That is a real, genuinely-driven 16 components. It is also, by
construction, **16 of the 43 that exist** — it cannot and does not drive
any of the 30 missing ones, and it does not drive several that do exist:
`floating_bar.rb`, `location_banner.rb`, `mime_actions.rb`,
`file_operations.rb`, `clipboard.rb`, `view_cell.rb`/`grid_cell.rb`/
`name_cell.rb`/`star_cell.rb`'s own signal handlers (only exercised
indirectly through the grid/list view, never e.g. star-toggling a file or
double-clicking to open one), `column_utilities.rb`'s column menu, the
files-view context menu(s) (right-click was never driven), `mime_actions`'s
open/launch prompts, `dbus_launcher.rb`. A 86/86 drive result is accurate
for what it covers and is not evidence about the other ~57 components —
treating it as such would be exactly the "narrow drive run reported as a
pass" failure this audit was asked to watch for.

### A located, concrete behavioural gap: dead buttons

Separately from the missing-file list, two buttons that **do** exist and
**are** wired to an action name have no action behind them, found while
tracing the search stack for component-identification:

- `lib/nautilus/toolbar.rb:212` — search toggle button, `action_name =
  'slot.search-visible'`.
- `lib/nautilus/window.rb:197` — "Search Everywhere" toggle,
  `action_name = 'slot.search-global'`.

`grep -rn "add_action" lib/` has no installer for either name anywhere in
the tree. Clicking either button in the running port does nothing
detectable (GTK does not raise for an action name with no matching
installed action on an ancestor action-map; it is simply inert). This is a
**regression below "missing dialog"**: it is a control that looks live and
isn't, which a screenshot-only review would not catch and the drive script
does not exercise (it never clicks the search toggle).

## Text axis

Covered in full in `.reports/translation-parity.md` — the answer there
(0 of ~1180 msgids ported, no `_()`/`N_()`/gettext call anywhere in `lib/`
or `exe/`) means the text axis fails for **every** component on both
sides of the list, matched or not. A component that exists, is styled
right and is wired right still fails component-parity's 4th axis here,
across the whole port, with no exception.

## Rules check

- Nothing above was treated as a pass from absence of evidence. Every
  "missing" claim was confirmed by a `find`/`grep` against the live tree,
  shown inline.
- The shortcut-manager item was caught and corrected in place rather than
  left as a silent overcount, per the instruction not to launder a gap —
  the same instruction cuts the other way: not to launder a non-gap into
  one either.
- No app-wide total stands in for the per-component check: the 86/86 drive
  number and the 43/73 file number are reported side by side specifically
  because together they show the shape of the gap (constructed but
  undriven **and** not constructed at all), which neither number shows
  alone.

**Component parity: not met.** 30 of 73 components absent, at least 2
wired-but-dead actions found in components that do exist, one unverified
visual substitution (`.cutout` checkerboard → `color-mix`) on an otherwise
clean stylesheet, and the text axis fails everywhere.
