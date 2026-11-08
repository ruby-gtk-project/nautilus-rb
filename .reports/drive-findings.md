# Drive run findings (test/drive_nautilus.rb)

Run with `nix develop --command xvfb-run -a ruby test/drive_nautilus.rb`.
Final result: **144 of 144 checks passed, DRIVE OK**, 15 of 16 attempted
screenshots written under `tmp/shots/`.

## Update: five components that had never actually been run

`grep -rn` across `lib/` for `AutorunSoftware`, `DateRangeDialog`,
`DateEntryRow`, `BatchRenameItem` and `XContentBar` turned up only each
class's own file — none of the first four is `require_relative`d by
anything `require 'nautilus'` pulls in (`DateEntryRow` is pulled in only as
`date_range_dialog.rb`'s own dependency), and `XContentBar`'s one real call
site, `window_slot.rb`'s mount-changed handler, can never fire in this
headless Xvfb session because nothing here produces a real `Gio::Mount`.
Every prior drive run, including the one this file previously reported
"86 of 86" for, exercised none of these five classes at all, despite each
one carrying a porting comment naming its upstream `.c` file.

The drive script now `require_relative`s the three orphaned files directly
and drives all five classes with a stand-in `Gio::Mount` (`FakeMount`, a
plain object answering `#name`/`#root`/`#signal_connect`, since this Xvfb
session has no removable media and no GVfs volume-monitor backend to hand
either `AutorunSoftware` or `XContentBar` a real one). Doing so found a real
bug, below. The remaining gap is integration, not correctness: these four
classes work on their own, but nothing in the running application calls any
of them from a window action, menu item or mount event. Upstream wires
`AutorunSoftware` from `g-volume-monitor`'s mount-added signal and
`DateRangeDialog` from the search-filters popover (`src/nautilus-search-
popover.c`) — neither the mount-watching code nor the search subsystem
(`nautilus-search-popover.c` and the rest of upstream's `nautilus-search-*`
files) exists on this branch yet, which `component-identification.md` and
`component-parity.md` already name as part of the known 30-file gap.
`BatchRenameItem` is the one case with no dialog to wire it into even on
upstream's own terms as far as this branch goes: upstream's
`nautilus-batch-rename-dialog.c` (the dialog `BatchRenameItem` is a row
model for) has no port at all — only the row class exists.

### Bug found and fixed: `AutorunSoftware#dialog`

`alert.format_heading("..." % mount_name)` raised
`NoMethodError: undefined method 'format_heading' for an instance of
Adwaita::AlertDialog`. Confirmed by hand: this adwaita gem build binds the
plain `heading`/`heading=` property pair but not
`adw_alert_dialog_format_heading()`'s printf-style wrapper. Fixed by
interpolating the string in Ruby (which the call already did, via `%`) and
assigning it with `alert.heading = ...` instead — same text, no behaviour
change, just the setter the binding actually has. This had never been
caught before because nothing had ever called `AutorunSoftware#present`
until this drive run did.

### Binding quirk found while testing, not a bug: `Adwaita::Dialog#visible?`

`Adwaita::Dialog#visible?` keeps reporting `true` after `#close` — confirmed
by hand with a standalone script. It reflects the underlying `GtkWidget`'s
`visible` property, not whether the dialog host has actually removed it.
The `"closed"` signal is what fires when the close really completes (also
confirmed by hand), and is what the new `DateRangeDialog` checks and
`AutorunSoftware` itself (which already connected to it) use instead of
polling `#visible?`.

## Bug found and fixed (prior round)

`FilesView#mode=` calls `ListView#build` / `GridView#build` every time the
view is switched back to, not only the first time it is shown. Both views'
root widget and background-gesture controller are memoized, so the second
`build` re-ran `view.add_controller(background_gesture)` with the exact same
already-attached `Gtk::GestureClick` — a GTK-CRITICAL
(`gtk_widget_add_controller`'s single-parent assertion), reproduced reliably
by toggling grid/list more than once. Fixed by memoizing `build`'s own return
value in both `lib/nautilus/list_view.rb` and `lib/nautilus/grid_view.rb`, so
the controller/model/signal wiring runs exactly once per view instance.

## Known environment limitation (not a port bug, not patched around)

The rename popover's actual click-through (type a name, press Rename) could
not be driven in this headless Xvfb. Reproduced in isolation
(`RenameFilePopover#show_for` followed by a timed check):

- Immediately after `show_for`, the popover reports `visible? == true`,
  `mapped? == true`, and every property `#show_for` sets (title, pre-filled
  entry text, selection, the captured file) is correct.
- Within roughly one main-loop turn (no code of this port's calls it), the
  popover's own `closed` signal fires on its own and its `visible?` flips to
  `false` — even with `autohide` explicitly set to `false` first, which rules
  out an autohide decision.
- `Gtk::Popover` opens its own `GdkPopup` surface (unlike `Adwaita::Dialog`,
  which is presented inside the main window's own surface and was driven
  successfully here — the new-folder dialog, select-items dialog, column
  chooser and grid-captions dialog all opened, were typed into and accepted
  across real main-loop ticks with no issue). With no window manager running
  in this Xvfb, that separate surface appears unable to hold itself open.

This is recorded here rather than worked around: no autohide flag, timeout,
or retry was added to the port to force the popover to "stay open," since
that would be inventing behaviour never asked for. What `#show_for` sets up
synchronously is checked; the type-and-click round trip is not, and is named
explicitly in the drive script's comments at the point it would otherwise
have been.

Likely affected by the same cause, though not separately exercised here:
`Sidebar`'s own rename popover and the `Gtk::PopoverMenu`-based background
and selection context menus in `FilesView` are also plain `Gtk::Popover`
subtypes.

## Also not run: the RSpec suite

The dev-shell's third command,
`ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([...])'`,
fails before any example runs:

```
Failure/Error: require "kettle/test/rspec"
LoadError: cannot load such file -- kettle/test/rspec
```

`kettle-family` and friends are declared in the repo-root `Gemfile` (the
kettle-jem development bundle), but the flake's `devShell` only wires
`nix/Gemfile`'s runtime gems plus a bare `pkgs.rubyPackages_3_4.rspec` — it
never bundles the root Gemfile's dev dependencies, so `kettle/test/rspec` is
not on the load path. Separately, `spec/` currently holds only
`spec_helper.rb` and `README.md` — no example files — so even with that gem
available, this run would report `0 examples`. Not patched around here: the
flake and the dev Gemfile are out of scope for the drive gate this report is
about, and stripping the `kettle/test/rspec` require to force a load would
silently change what the suite does when specs do get written against it.
