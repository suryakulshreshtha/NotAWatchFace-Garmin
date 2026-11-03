# QA report: NotAWatchFace 1.0.3

Release date: 30 Oct 2026 · Target: Garmin Instinct 2 Solar Tactical Edition (`instinct2`)
Covers both faces: NotAWatchFaceAnalogue and NotAWatchFaceDigital.

**Status: ready for simulator verification.** All checks below pass.
NotAWatchFaceAnalogue 1.0.1 compiled with Garmin's compiler on the target Mac
with 0 errors and 1 warning (launcher icon size), fixed in 1.0.2.
NotAWatchFaceDigital 1.0.2 compiled with 6 errors, all one rule (typed local
variables), fixed in 1.0.3. NotAWatchFaceDigital 1.0.3 was rebuilt on
1 Nov 2026 and copied to the watch; the compiler output was not recorded here.
Remaining release gate: the simulator checklist in INSTALL.md for both faces.

## Requirements traceability

| ID | Requirement | Implemented in | Status |
| --- | --- | --- | --- |
| A1 | Analogue: current time in digital form in the round subscreen | `drawBubble` | Pass |
| A2 | Analogue: no heart rate or moon in the subscreen | Analogue view | Pass |
| A3 | Analogue: Arabic numerals 1-12, day below 12, date above 6, sword hands | `drawNumerals`, `drawDayDate`, `drawSword` | Pass |
| A4 | No GMT; the former GMT needle design is the seconds needle | `drawSecondsNeedle` | Pass |
| A5 | Three hands only | Hour, minute, seconds | Pass |
| A6 | Side-load project named NotAWatchFaceAnalogue | Folder, app name, entry class | Pass |
| A7 | Seconds needle after a wrist raise | `onExitSleep` / `onEnterSleep` | Pass |
| D1 | Digital slot 1: day and date | `onUpdate` | Pass |
| D2 | Slot 2: text only, "Bravo01One" | `Settings.mc` | Pass |
| D3 | Slot 3: moon phase in the subscreen | `drawMoon`, `Astro.moonPhase` | Pass |
| D4-5 | Sunrise and sunset under the time | `updateSun`, `drawSunLine` | Pass |
| D6-8 | Heart rate, steps, distance | Row A | Pass |
| D9-11 | Altitude, last compass reading, pressure trend | Row B | Pass |
| D12 | No battery %; corner brackets; large time | Digital view | Pass |
| D13 | Side-load project named NotAWatchFaceDigital | Folder, app name, entry class | Pass |
| W1 | Built for the Instinct 2 Solar Tactical | Manifest product `instinct2` | Pass |
| G1 | Install guide: software, safe USB copy | INSTALL.md | Pass |
| Q1 | No credit or attribution lines for any tool in code, docs, manifests or images (the almanac method behind `Astro.mc` is credited in the root `NOTICE`) | Sweep of code, docs, manifests, images | Pass |

## Test summary

| Area | What was run | Result |
| --- | --- | --- |
| Static checks | Every called function, member variable and constant is defined; brackets balance; every Garmin API name used is checked against Garmin's API reference; no local variable carries a declared type (a rule learned from Garmin's compiler); all XML files parse | Pass |
| Sun maths | Sunrise and sunset compared with an independent astronomy library (astral 3.2) in 64 cases: 8 cities from the equator to 64 deg N, 4 dates including both solstices | Pass: worst difference 2.8 min |
| Time zones | Sunrise and sunset land on the correct local day in 6 zones (UTC-10 to UTC+13, with and without daylight saving) | Pass |
| Moon maths | Phase compared weekly for one year against the same library | Pass: worst difference 0.81 days |
| Analogue layout | Model of the drawing code run for every minute of the dial at 3 second positions: hands on screen and inside the dial, numerals clear of the subscreen or deliberately skipped, windows clear of 12 and 6, subscreen time fits | Pass |
| Digital layout | 8 scenarios x 3 times: normal, wide values, missing data, 12-hour, long label, empty label, widest date, negative altitude. Checked: no overlaps, side and bottom margins, text clear of the subscreen, each value inside its column | Pass |
| Test strength | 3 deliberate faults injected (label overflow, columns at the screen edge, numerals pulled in needlessly); each was caught | Pass |
| Garmin compiler | NotAWatchFaceAnalogue 1.0.1 built for `instinct2` on the target Mac (Connect IQ SDK, Monkey C extension 1.1.3) | Pass: 0 errors, 1 warning, fixed in 1.0.2 |
| Garmin compiler | NotAWatchFaceDigital 1.0.2 built for `instinct2` on the target Mac | Fail: 6 errors, "Invalid explicit typing of a local variable"; fixed in 1.0.3 |
| Garmin compiler | NotAWatchFaceDigital 1.0.3 rebuilt for `instinct2` on the target Mac, 1 Nov 2026 | Built and copied to the watch; compiler output not recorded |

16,486 layout checks in total, 0 failures.

**Limits of these tests:** the layout model uses stand-in fonts of similar
size. Its subscreen position (centre 176 x 176 point (144, 31), radius 31) is
taken from a working Instinct 2 watch face. The layout model is not Garmin's
simulator; the simulator checklist covers that.

## Defects found and fixed

| # | Face | Defect | Fix | Release |
| --- | --- | --- | --- | --- |
| 1 | Analogue | Numerals shrank to their minimum size, yet 1 and 2 were still under the subscreen | Numerals stay full size unless shrinking actually clears the subscreen | 1.0.1 |
| 2 | Digital | A long value dropped one cell to a smaller font, so a row could mix text sizes | One font per row | 1.0.1 |
| 3 | Digital | Bottom-corner values and brackets too close to the screen's cut corners | Columns moved in, bottom margin raised, brackets inset | 1.0.1 |
| 4 | Digital | Bottom brackets' upright arms crowded the bottom row | Short corner ticks below the row | 1.0.1 |
| 5 | Digital | Date line had no width guard next to the subscreen | Weekday dropped if the date would touch the subscreen | 1.0.1 |
| 6 | Digital | Sensor data read 5 times per redraw | Read once per redraw and shared | 1.0.1 |
| 7 | Both | Manifest used the older `minSdkVersion` attribute | `minApiLevel`, as current Garmin tooling writes it | 1.0.1 |
| 8 | Guide | First-person wording; "24-hour time" where the face follows the watch setting | Reworded | 1.0.1 |
| 9 | Both | Launcher icons were 40 x 40; Garmin's compiler reports the Instinct 2 expects 62 x 62 and scaled them (warning) | Icons redrawn at 62 x 62 | 1.0.2 |
| 10 | Digital | Six local variables declared with a type (`var x as Type`), which Garmin's compiler rejects: "Local variable types are inferred" | Rewritten with early returns and plain locals; static check now fails on any typed local | 1.0.3 |

## Known limitations and open items

| Item | Impact | Plan |
| --- | --- | --- |
| Simulator results not recorded | Layout in Garmin's simulator is unconfirmed; the layout checks use a model with stand-in fonts | Run the checklist in INSTALL.md and record the results |
| Screen's cut corners | Bottom-corner values or brackets could be clipped | Check in the simulator (checklist item) |
| Compass on a watch face | Garmin doesn't document it; the field may stay `---` | If it never fills in, swap field 10 |
| Always-on ticking seconds | Not included; needs testing against Garmin's power limit | Possible later, behind a simulator power test |
| Numerals 1 and 2 (analogue) | Skipped where the subscreen covers them | By design |
| Moon phase | Within about 1 day; northern-hemisphere orientation | By design |
| Pressure trend | Needs 2.5 hours of history after a restart; altitude changes affect it | By design |
