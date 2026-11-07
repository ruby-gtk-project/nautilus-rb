# Drive run findings (test/drive_nautilus.rb)

Run with `nix develop --command xvfb-run -a ruby test/drive_nautilus.rb`.
Final result: **86 of 86 checks passed, DRIVE OK**, 12 of 13 attempted
screenshots written under `tmp/shots/`.

## Bug found and fixed

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
