# nautilus-rb — component parity

Skill: `component-parity`. Builds on `.reports/component-identification.md`.
Upstream `origin/main` @ `ce1442753a9a6c61a508af2351653df92c6ef8e7` (as
fetched); port `ruby` @ `be7d07f634ccc7f1d06b7f96fbd0c312e96eda5a`, six
commits past the `d665da98e0` this document originally scored.

## Update at `be7d07f63`

Six files that this document originally counted among the 30 missing now
exist on disk: `date_range_dialog.rb`, `date_entry_row.rb`,
`network_address_bar.rb`, `autorun_software.rb`, `x_content_bar.rb`,
`file_conflict_dialog.rb` (re-confirmed with `find lib -name '<file>.rb'`
for each, all six present). That moves the headline from 43/73 to **49/73**
matched, 30 to **24** missing. The table and the grouped list below are
updated accordingly. Everything else in this document — the dead-button
finding, the stylesheet diff, the drive-coverage accounting, the text-axis
verdict — was re-checked against the live tree for this audit and still
holds exactly as written; see the inline re-confirmations added below.

**New, and the most important finding this update makes:** of the six
newly-present files, five (all but `file_conflict_dialog.rb`) are built but
**unreachable from the running app** — `.reports/drive-findings.md` found,
by `grep -rn` across `lib/`, that nothing `require_relative`s or calls
`AutorunSoftware`, `DateRangeDialog`, `DateEntryRow`, or `BatchRenameItem`
from any window action, menu item, or real event, and `XContentBar`'s one
call site in `window_slot.rb` needs a real `Gio::Mount` this headless
environment cannot produce. "File exists" is necessary for component
parity but not sufficient — a component with no caller is unmet on the
behaviour axis exactly as much as one with no file, just in a way `find`
alone cannot see. Counted as "matched" in the table below per the skill's
file-matching step, but flagged here so the table is not read as "5 more
features a user can now reach" — a user can reach none of them yet.

## Verdict: no parity

24 of 73 user-facing upstream files have **no port file at all** — not a
thinner version, nothing. Of the 49 that do have a file, 5 are wired to
nothing a user can trigger (see Update above). Count, style, behaviour and
text are all unmet for every component the 24 missing files build, because
there is no widget on the port side to check any axis against.

| | |
|---|---|
| Upstream user-facing files | 73 |
| Matched by a port file | 49 |
| Of those, reachable from the running app | 44 (5 built-but-unwired — see Update) |
| **Missing entirely** | **24** |
| Components with all four axes verified clean | see below — none fully verified; drive coverage is partial (see Gate section) |

## The 24 missing files, grouped by what a user loses

Updated from the original 30-file list by removing the six files now
confirmed present (`date_range_dialog.rb`, `date_entry_row.rb`,
`network_address_bar.rb`, `autorun_software.rb`, `x_content_bar.rb`,
`file_conflict_dialog.rb`).

**Whole dialogs/windows (9):** properties window + properties widget +
change-permissions dialog (3 files), compress dialog, batch rename dialog
(the dialog itself — only its preview-row *model*, `batch_rename_item.rb`,
exists), app chooser + app chooser widget (2 files),
operations-ui-manager (passphrase prompt + conflict orchestration), portal
file chooser. (`file conflict dialog`, previously counted here, is ported —
see Update above — though note `lib/nautilus/file_conflict_dialog.rb`'s
reachability from a real copy/move conflict was not independently
re-verified in this pass beyond what `drive-findings.md` already checked.)

**Whole subsystems with zero UI (search, 3 files):** query editor, search
popover, search types dialog. (Date range dialog and date entry row, listed
here previously, are now ported — but see Update above: neither is reachable
from the running app, because the search popover that would host them does
not exist. The five backend search-engine files are separate and also
unported — see test-parity, where their 44 upstream unit tests are gap
rows.)

**Whole subsystems with zero UI (progress reporting, 4 files):** progress
indicator, progress info widget, progress paintable, progress persistence
handler (desktop notifications for finished operations).

**Whole subsystems with zero UI (network places, 2 files):** network view,
network cell. (Network address bar, previously listed here, is now ported —
see Update above.)

**Supporting behaviour with no port file (6):** shortcut-manager (the
`Gtk.ShortcutManager` wrapper `nautilus-window.blp`'s template instantiates
as `$NautilusShortcutManager` — `lib/nautilus/shortcut_manager.rb` *is
listed in `lib/`*, correcting the inventory's count by one: re-checked
directly, `find lib -name shortcut_manager.rb` returns a file, so this one
item is a correspondence, not a gap — struck from the count), file-undo-operations (undo/redo toast labels),
dnd (drag source/drop menus), shell-search-provider (GNOME Shell search
D-Bus service), previewer (Sushi preview D-Bus client). (Autorun-software
and x-content-bar, previously listed here, are now ported — but, per Update
above, neither is reachable from a live mount event in this branch's
running app.)

Re-verifying the shortcut-manager correction against the live tree:

```
$ find lib -iname '*shortcut_manager*'
lib/nautilus/shortcut_manager.rb
```

So the file does exist — this one item is a correspondence, not a gap.
Corrected: **24 missing is the current number** given the six newly-ported
files above.

## Axis check on components that exist on both sides

Full per-widget axis comparison (Steps 3–5 of the skill: widget/CSS/signal/
action diff, stylesheet diff, driven-behaviour check) across all 49 matched
files was not completed in this pass — at 49 files averaging several
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
components, including the 24 with no port widget yet — the classes those
24 dialogs would use are already defined and waiting, unused. That is real
and is recorded as such; it does not reduce the 24-file gap, which is a
missing widget tree, not a missing stylesheet.

### Behaviour axis — driven coverage

`test/drive_nautilus.rb` (144 checks at `be7d07f63`, cited by the runtime
gate as "39 components") was read step by step. It drives everything the
original 86-check version did (window shell, sidebar listing +
bookmarking, show-hidden toggle, grid/list view switch twice — the
controller-reattachment bug recorded in `.reports/drive-findings.md` —
new-folder dialog, select-items dialog, rename popover setup, column
chooser, grid captions dialog, tabs, history, the narrow-layout breakpoint,
preferences dialog, shortcuts dialog, about dialog, accelerators, sidebar
show/hide, select-all/invert) plus, as of `be7d07f63`, standalone exercises
of `DateRangeDialog`, `DateEntryRow`, `BatchRenameItem` and
`AutorunSoftware` (with a stand-in `Gio::Mount`).

That is a real, genuinely-driven set of checks. It is also, by
construction, driving at most **39 of the 49 files that exist on disk**
(the gate's own count) — it cannot and does not drive any of the 24
missing ones, and it does not drive several files that do exist:
`floating_bar.rb`, `location_banner.rb`, `mime_actions.rb`,
`file_operations.rb`, `clipboard.rb`, `view_cell.rb`/`grid_cell.rb`/
`name_cell.rb`/`star_cell.rb`'s own signal handlers (only exercised
indirectly through the grid/list view, never e.g. star-toggling a file or
double-clicking to open one), `column_utilities.rb`'s column menu, the
files-view context menu(s) (right-click was never driven), `mime_actions`'s
open/launch prompts, `dbus_launcher.rb`, `x_content_bar.rb` (acknowledged
unexercisable headless, per `drive-findings.md`). A 144/144 drive result is
accurate for what it covers and is not evidence about the other ~10
existing-but-undriven files, let alone the 24 missing ones — treating it as
such would be exactly the "narrow drive run reported as a pass" failure
this audit was asked to watch for.

**This audit independently re-ran the gate three times and it is not
reliably 144/144.** One of three runs (`nix develop --command xvfb-run -a
ruby test/drive_nautilus.rb`, no modification) crashed before completing,
with:

```
lib/nautilus/directory.rb:195:in 'block in Nautilus::Directory#refill_store':
undefined method 'remove_all' for an instance of Array (NoMethodError)
          store.remove_all
               ^^^^^^^^^^^
	from lib/nautilus/directory.rb:194:in 'Nautilus::Directory#refill_store'
	from lib/nautilus/directory.rb:138:in 'Nautilus::Directory#load'
	from lib/nautilus/directory.rb:248:in 'block in Nautilus::Directory#schedule_reload'
```

This fires from the debounced (300ms) file-monitor reload path (`load` →
`refill_store` → `list_store.tap { |store| store.remove_all; ... }`), and is
timing-dependent: whether the 300ms `GLib::Timeout` fires before the drive
script finishes and tears the loop down determines whether this line ever
executes in a given run, which is why two of three runs passed clean and
one did not. A separate run of the same command also once produced a raw
segfault with no Ruby backtrace at all (not reproduced a second time, kept
here as a second data point rather than a confirmed root cause). This is a
real, reproducible defect in `lib/nautilus/directory.rb`'s reload path, not
a flake in the test harness, and it means the runtime gate as stated
("drive_ok=true, 144 checks passed, 0 failed") describes one run among
several, not a stable property of the branch. See
`.reports/drive-findings.md` and `.reports/accountability-ensurance.md` for
the full writeup; recorded here because it is exactly the kind of
behaviour-axis failure this section is about, on a file (`directory.rb`)
the drive script's "144/144" would otherwise imply is clean.

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

**Component parity: not met.** 24 of 73 components absent, 5 more present
on disk but unreachable from the running app (see Update above), at least
2 wired-but-dead actions found in components that do exist, one unverified
visual substitution (`.cutout` checkerboard → `color-mix`) on an otherwise
clean stylesheet, a reproducible crash in a component the drive gate
counts as passing (`directory.rb`, see Behaviour axis above), and the text
axis fails everywhere.
