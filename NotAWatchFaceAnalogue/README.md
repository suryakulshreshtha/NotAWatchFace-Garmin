# NotAWatchFaceAnalogue

Three-hand analogue watch face for the Garmin Instinct 2 Solar Tactical Edition
(Connect IQ device `instinct2`, 176 x 176, black and white). Built to be
sideloaded over USB.

Also on the Connect IQ Store: [NotAWatchFace Analogue](https://apps.garmin.com/apps/6a2355c0-1984-43ea-807d-c7742cecb055).

## What it shows

- Hour and minute hands
- Seconds needle (thin stem, hollow arrow tip), shown for about 10 seconds
  after a wrist raise and hidden when the watch is idle
- Arabic numerals 1-12 and a 60-tick minute track. Numerals that fall under
  the round subscreen are skipped.
- Day window below 12, date window above 6
- Current time in digital form inside the round subscreen, following the
  watch's 12/24-hour setting

No permissions, no network, no phone connection.

## Files

| File | Purpose |
| --- | --- |
| `manifest.xml` | App ID, target device, type `watchface` |
| `monkey.jungle` | Build file |
| `source/NotAWatchFaceAnalogueApp.mc` | Entry point |
| `source/NotAWatchFaceAnalogueView.mc` | All drawing |
| `resources/` | App name and launcher icon |
| `INSTALL.md` | Full install guide: software, developer key, build, simulator, USB copy |
| `QA-REPORT.md` | What was tested, defects fixed, known limitations |

## Build and install

See `INSTALL.md`. In short: open this folder in VS Code with Garmin's
Monkey C extension, build for `instinct2`, test in the simulator, then copy
the `.prg` file into `GARMIN/APPS` on the watch.

## Release notes

**1.0.2** (30 Oct 2026)
- Launcher icon redrawn at 62 x 62, the Instinct 2's native size (clears the compiler's icon-size warning)

**1.0.1** (30 Oct 2026)
- Numerals stay full size unless shrinking actually clears the subscreen
- Manifest uses the `minApiLevel` attribute, as current Garmin tooling writes it

**1.0.0** - first build
