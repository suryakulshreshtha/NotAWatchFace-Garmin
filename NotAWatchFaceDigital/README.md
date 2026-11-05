# NotAWatchFaceDigital

Tactical digital watch face for the Garmin Instinct 2 Solar Tactical Edition
(Connect IQ device `instinct2`, 176 x 176, black and white). Built to be
sideloaded over USB.

Also on the Connect IQ Store: [NotAWatchFace Digital](https://apps.garmin.com/apps/8f0efe92-5363-4ee6-a537-8fa09dc91be7).

## What it shows

| Slot | Shows | Comes from |
| --- | --- | --- |
| 1 | Day and date (`FRI 30 OCT`) | Watch clock |
| 2 | `Bravo01One` | `source/Settings.mc` |
| 3 | Moon phase (in the round subscreen) | Calculated from the date |
| Time | Large, follows the watch's 12/24-hour setting | Watch clock |
| 4, 5 | Sunrise, sunset | Calculated from the last known GPS position |
| 6 | Heart rate | Wrist sensor, then the latest all-day reading |
| 7 | Steps today | Activity tracking |
| 8 | Distance today (km or miles per watch setting) | Activity tracking |
| 9 | Altitude (m or ft per watch setting) | Barometric altimeter |
| 10 | Last compass reading, in degrees | Watch heading, kept until a new one arrives |
| 11 | Pressure in hPa, with a 3-hour trend arrow | Barometer history |

Values the watch can't provide show as `--`. Nothing uses the network or
the phone.

## Changing the text in slot 2

Edit `source/Settings.mc`, rebuild, and copy the new `.prg` to the watch.

## Files

| File | Purpose |
| --- | --- |
| `manifest.xml` | App ID, target device, permissions (Positioning, SensorHistory) |
| `monkey.jungle` | Build file |
| `source/Settings.mc` | Your text for slot 2 |
| `source/Astro.mc` | Sunrise, sunset and moon phase maths |
| `source/NotAWatchFaceDigitalApp.mc` | Entry point |
| `source/NotAWatchFaceDigitalView.mc` | Layout, drawing and sensor reading |
| `resources/` | App name and launcher icon |
| `INSTALL.md` | Full install guide: software, developer key, build, simulator, USB copy |
| `QA-REPORT.md` | What was tested, defects fixed, known limitations |

## Build and install

See `INSTALL.md`. In short: open this folder in VS Code with Garmin's
Monkey C extension, build for `instinct2`, test in the simulator, then copy
the `.prg` file into `GARMIN/APPS` on the watch.

## Release notes

**1.0.3** (30 Oct 2026)
- Fixed 6 compiler errors: local variables no longer declare a type (Garmin's compiler infers local types)

**1.0.2** (30 Oct 2026)
- Launcher icon redrawn at 62 x 62, the Instinct 2's native size (clears the compiler's icon-size warning)

**1.0.1** (30 Oct 2026)
- One font per bottom row, so values in a row always match in size
- Bottom row, margins and corner brackets moved clear of the screen's cut corners
- Date drops the weekday if it would touch the subscreen
- Sensor data read once per redraw
- Manifest uses the `minApiLevel` attribute, as current Garmin tooling writes it

**1.0.0** - first build
