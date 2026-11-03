# NotAWatchFaceDigital: how to code it

A line-by-line guide to writing the NotAWatchFaceDigital watch face for the Garmin Instinct 2 Solar Tactical, from the empty project folder to the finished 710-line View, the 104-line sun and moon maths module and the 8-line Settings file.

## Start here

You will build a data-rich digital watch face that reads the clock, the wrist sensors and the last GPS position, and every file and code segment is shown here in the order you would write them.

**The finished face (version 1.0.3) shows eleven things:**

| Slot | Shows | Comes from | If the watch has no value |
| --- | --- | --- | --- |
| 1 | Day and date, for example `FRI 30 OCT` | The watch clock | The weekday is dropped if the line is too wide |
| 2 | Your own text | `source/Settings.mc` | Cut to fit |
| 3 | Moon phase, drawn in the round subscreen | Calculated from the date | Not drawn without a subscreen |
| Time | Large, in 12- or 24-hour form following the watch setting | The watch clock |  |
| 4, 5 | Sunrise and sunset | Calculated from the last known GPS position | `--:--` |
| 6 | Heart rate | Wrist sensor, then the latest all-day reading | `--` |
| 7 | Steps today | Activity tracking | `--` |
| 8 | Distance today, in km or miles | Activity tracking | `--` |
| 9 | Altitude, in metres or feet | Barometric altimeter | `--` |
| 10 | Last compass reading, in degrees | The watch's heading, kept until a new one arrives | `---` |
| 11 | Pressure in hPa, with a 3-hour trend arrow | Barometer history | `--` |

The layout, in rough sketch form:

```
 date                      ( moon  )
 your text                 ( phase )

            TIME
       sunrise    sunset
  heart     steps     distance
  altitude  compass   pressure
```

Nothing uses the network or the phone.

**Target watch:** Garmin Instinct 2 Solar Tactical, Connect IQ device id `instinct2`: 176 × 176 pixels, two colours (black and white), a round subscreen in the top-right corner and cut bottom corners.

**Who this is for:** students who know variables, `if`, loops and functions. You do not need any Garmin experience. If you have not built a watch face before, read the companion guide *NotAWatchFaceAnalogue: how to code it* first, because this guide skips the explanations that repeat.

**How each segment is laid out:**

1. A heading with the file name and the line numbers.
2. The code, exactly as it is in the project. Copy it as it stands.
3. *What it does*, then *Why*, and sometimes a worked example.

**What is and isn't verified.** Facts about Garmin's programming interfaces (`getSubscreen`, the drawing calls, the sleep methods) were checked against Garmin's published API reference; the pages are listed under Sources. Statements marked *(language rule)* describe how Monkey C behaves, taken from this project's compiler messages and tests. Garmin's Monkey C language pages would not load when this guide was written, so confirm those rules in Garmin's documentation. Where the project could not verify a behaviour on the real watch, this guide says so.

## Project map

The face is eight small files plus one 710-line View, and the View leans on two helpers: a text setting and a maths module.

```
NotAWatchFaceDigital/
  manifest.xml
  monkey.jungle
  resources/
    drawables/
      drawables.xml
      launcher_icon.png        (62 x 62 pixels)
    strings/
      strings.xml
  source/
    NotAWatchFaceDigitalApp.mc
    NotAWatchFaceDigitalView.mc
    Settings.mc                (your text for slot 2)
    Astro.mc                   (sun and moon maths)
  README.md   INSTALL.md   QA-REPORT.md
  bin/                         (created by the build; not source code)
```

| Order | File | Lines | Job |
| --- | --- | --- | --- |
| 1 | `manifest.xml` | 31 | The face's identity card, including the two permissions it asks for |
| 2 | `monkey.jungle` | 1 | The build recipe: which manifest to use |
| 3 | `resources/strings/strings.xml` | 3 | The app name text |
| 3 | `resources/drawables/drawables.xml` | 3 | Declares the launcher icon |
| 3 | `resources/drawables/launcher_icon.png` | 62 × 62 px | The icon shown in the watch-face list |
| 4 | `source/Settings.mc` | 8 | One editable value: the text for slot 2 |
| 5 | `source/Astro.mc` | 104 | Pure maths: sunrise, sunset and moon phase |
| 6 | `source/NotAWatchFaceDigitalApp.mc` | 21 | The entry point the watch starts first |
| 7 | `source/NotAWatchFaceDigitalView.mc` | 710 | Layout, drawing and sensor reading: the face itself |
|  | `README.md`, `INSTALL.md`, `QA-REPORT.md` | 65, 343, 83 | Documentation, install guide and test record |

**How the pieces connect when the watch runs the face:**

1. The manifest names the entry class, `NotAWatchFaceDigitalApp`, and asks for the `Positioning` and `SensorHistory` permissions.
2. The watch creates that class and calls its `getInitialView()`, which returns the View.
3. The View reads the constant `LABEL_TEXT` from `Settings.mc` and calls functions in the `Astro` module for the sun and the moon.
4. The system calls the View's `onLayout` so it can measure the screen, then `onUpdate` whenever the face must be redrawn.

Files in the same `source/` folder can use each other's names without extra set-up. That is why the View can say `LABEL_TEXT` and `Astro.moonPhase(...)` with no import for them *(language rule, observed in this project)*.

## Before you code

The tools are exactly the ones in the Analogue guide, and what is new is that this face asks the watch for permission to read data.

**Tools, once:** Visual Studio Code with Garmin's *Monkey C* extension, the Connect IQ SDK (installed with Garmin's SDK Manager; 9.3.0 was used here), Java for the compiler, and a developer key. `INSTALL.md` in the project walks through each, including the key. Treat the key like a password: back it up, and never put it in a project you share.

**The build command** has the same shape as for the Analogue face, run from this project's folder:

```
java -jar "<sdk folder>/bin/monkeybrains.jar" \
  -f monkey.jungle \
  -d instinct2 \
  -y <path to your developer key> \
  -o NotAWatchFaceDigital.prg
```

**Permissions are new here.** A face that reads GPS or sensor history must say so in the manifest. This face declares two:

| Permission | Used for | Where in the code |
| --- | --- | --- |
| `Positioning` | Reading the last known position, for sunrise and sunset | `lastKnownLocation`, `updateLocation` |
| `SensorHistory` | Barometer history (pressure and its trend) and elevation history (an altitude fallback) | `updatePressure`, `altitudeText` |

**What the face needs from the watch.**

- It never switches GPS on. It reuses the last position the watch already knows, so sunrise and sunset show `--:--` until the watch has had a position at least once. After that the position is saved and survives restarts of the face.
- The pressure trend needs about 2.5 hours of barometer history, and that history is wiped when the watch restarts. Until then the pressure icon is a plain dial.
- The compass field shows the last heading the watch reports. Garmin does not document how heading behaves for a watch face, so the field may stay `---`. The project's QA report lists this as a known limit.

## Manifest, resources and Settings.mc

These files hold no drawing logic, but the manifest is where this face differs from the Analogue one, and `Settings.mc` is the only file a user is meant to edit.

### manifest.xml (31 lines)

```xml
<?xml version="1.0"?>
<iq:manifest xmlns:iq="http://www.garmin.com/xml/connectiq" version="3">
    <iq:application
        entry="NotAWatchFaceDigitalApp"
        id="344b6cee189246f49eadf87fc139a98f"
        launcherIcon="@Drawables.LauncherIcon"
        minApiLevel="3.2.7"
        name="@Strings.AppName"
        type="watchface"
        version="1.0.3">

        <iq:products>
            <!-- Instinct 2 / Instinct 2 Solar / Instinct 2 Solar Tactical Edition
                 176 x 176, 2-colour memory-in-pixel screen, round subscreen top-right -->
            <iq:product id="instinct2"/>
        </iq:products>

        <iq:permissions>
            <!-- Last known GPS position, for sunrise and sunset -->
            <iq:uses-permission id="Positioning"/>
            <!-- Barometer history (pressure trend) and elevation history (altitude fallback) -->
            <iq:uses-permission id="SensorHistory"/>
        </iq:permissions>

        <iq:languages>
            <iq:language>eng</iq:language>
        </iq:languages>

        <iq:barrels/>
    </iq:application>
</iq:manifest>
```

| Lines | What it says |
| --- | --- |
| 1–2 | The XML header and the root element. Copy these two lines unchanged. |
| 4 `entry` | The name of the App class in your code. It must match the class name exactly. |
| 5 `id` | This face's own identity: 32 hexadecimal digits, different from the Analogue face's. Keep it the same across updates. |
| 6 `launcherIcon`, 8 `name` | Pointers (the `@`) to the icon and the app name in the resource files below. |
| 7 `minApiLevel` | The oldest Connect IQ API level the face accepts: `3.2.7`. |
| 9 `type` | `watchface` makes it appear in the watch-face list. |
| 10 `version` | Your own release number, `1.0.3`. |
| 12–16 | The watches you build for: `instinct2` only. |
| 18–23 | **Permissions, the new part.** Each `<iq:uses-permission id="..."/>` line asks for one capability, with the reason in the comment above it. `Positioning` is for the last known GPS position and `SensorHistory` is for the barometer and elevation history. |
| 25–27 | Languages: English only. |
| 29 | Barrels are reusable code libraries. This project uses none. |

Ask only for what you use: a face that reads nothing from the watch, like the Analogue one, leaves `<iq:permissions/>` empty.

### monkey.jungle (1 line)

```
project.manifest = manifest.xml
```

The build recipe is the same single line as before. The project builds with only this line, and the `source/` and `resources/` folders are picked up without being listed. That is observed behaviour here, not something quoted from Garmin's documentation.

### resources/strings/strings.xml (3 lines)

```xml
<strings>
    <string id="AppName">NotAWatchFaceDigital</string>
</strings>
```

### resources/drawables/drawables.xml (3 lines)

```xml
<drawables>
    <bitmap id="LauncherIcon" filename="launcher_icon.png"/>
</drawables>
```

These two files work exactly as in the Analogue face: the name text, and a declaration for a 62 × 62 pixel icon. Like that face, the View never loads a resource.

### source/Settings.mc (8 lines)

```
// ---------------------------------------------------------------------
// Your text for slot 2 (under the date).
//
// To change it: edit the text between the quotes, rebuild, and copy the
// new file to the watch. Plain letters, numbers and basic symbols only.
// Anything wider than the space left of the subscreen is cut off.
// ---------------------------------------------------------------------
const LABEL_TEXT = "Bravo01One";
```

- Lines 1–7 are a comment that tells the user what to do. Writing instructions *inside* the file people edit is good practice.
- Line 8 declares a constant. `const` means the value never changes while the face runs. It sits outside any class, so every file in `source/` can read it, and the View reads it as `LABEL_TEXT`.
- A string is text between double quotes. To change the label, change the characters between the quotes and nothing else.
- Too-wide text is not an error: the View shortens it, one character at a time, until it fits (lines 150–156, explained in part 2 of the View).

**Try it:** change the text, rebuild, and copy the new `.prg` to the watch as the Analogue guide describes.

## The App class

The App class has the same 21 lines as the Analogue face's, with only the two names changed.

### source/NotAWatchFaceDigitalApp.mc (all 21 lines)

```
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point. The watch creates this class first and asks it for the view.
class NotAWatchFaceDigitalApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        return [new NotAWatchFaceDigitalView()];
    }
}
```

| Lines | What it does |
| --- | --- |
| 1–3 | Make the `Application`, `Lang` and `WatchUi` parts of Garmin's *Toybox* library available by name. |
| 6 | Creates the class and makes it inherit from `AppBase`. The name must match `entry="NotAWatchFaceDigitalApp"` in the manifest. |
| 8–10 | The constructor: it calls the parent's `initialize()`. |
| 12–16 | `onStart` and `onStop` are hooks the system calls when the app starts and stops. Both are empty. |
| 18–20 | `getInitialView()` returns an array whose first item is a new `NotAWatchFaceDigitalView`. This is the hand-over to the View. |

The Analogue guide explains each of these lines in more detail. The point to carry over is that a watch face's App class does almost nothing: all the work is in the View.

## The View, part 1: imports, constants and state

The View's first 107 lines declare everything it will use: the Garmin modules, the named constants, the layout numbers, the cached values and the restore-from-storage step.

### Imports (lines 1–12 of NotAWatchFaceDigitalView.mc)

```
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Position;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
```

| Import | What the face takes from it |
| --- | --- |
| `Toybox.Activity` | `Activity.getActivityInfo()`: the live reading of heart rate, altitude, pressure, heading and position |
| `Toybox.ActivityMonitor` | All-day data: steps, distance and the heart-rate history |
| `Toybox.Application` | `Application.Storage`, a small saved memory that survives restarts of the face |
| `Toybox.Graphics` | Colours and fonts |
| `Toybox.Lang` | The basic types: `Number`, `Float`, `Boolean`, `String`, `Array` |
| `Toybox.Math` | `sin`, `cos`, `sqrt`, `floor`, `toRadians`, `toDegrees` and friends |
| `Toybox.Position` | The watch's last known position |
| `Toybox.SensorHistory` | Barometer and elevation history |
| `Toybox.System` | The clock and the watch's settings |
| `Toybox.Time`, `Toybox.Time.Gregorian` | Moments in time and calendar dates |
| `Toybox.WatchUi` | The `WatchFace` base class and the subscreen lookup |

### The header comment (lines 14–28)

```
// NotAWatchFaceDigital
//
// Tactical digital face for the Garmin Instinct 2 Solar Tactical
// (176 x 176, black-and-white memory-in-pixel screen).
//
//   1  day and date                      FRI 30 OCT
//   2  your text (see Settings.mc)        Bravo01One
//   3  moon phase                         inside the round subscreen
//      time                               large, follows the watch's 12/24 h setting
//   4  sunrise   5  sunset                from the last known GPS position
//   6  heart rate   7  steps   8  distance
//   9  altitude    10  last compass reading    11  pressure + 3-hour trend
//
// Nothing here uses the network or the phone. Values the watch can't
// provide show as "--".
```

This comment is the face's specification: eleven numbered slots. **Note:** the sketch shows the label as `Bravo01One`, matching `Settings.mc`. The comment has no effect on the program, because the real text comes from `Settings.mc`. When you change a value like this, update the comments too.

### Named constants (lines 30–45)

```
const DAY_NAMES = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
const MONTH_NAMES = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

// Icon ids
const ICON_HEART = 0;
const ICON_STEPS = 1;
const ICON_DISTANCE = 2;
const ICON_ALTITUDE = 3;
const ICON_COMPASS = 4;
const ICON_PRESSURE = 5;

// Pressure trend values
const TREND_FALLING = -1;
const TREND_STEADY = 0;
const TREND_RISING = 1;
const TREND_UNKNOWN = 2;
```

- The two lists hold the text for the date line. The weekday list starts at Sunday and the month list at January, so a date number needs a small adjustment to become a list position. The adjustments appear later: `(dow + 6) % 7` for the weekday and `(month + 11) % 12` for the month.
- The icon ids and trend values are **named numbers**, a simple way to fake an enumeration. `drawIcon(dc, ICON_HEART, ...)` says what it means, while `drawIcon(dc, 0, ...)` does not.
- The trend values are chosen so the sign means something: −1 falling, 0 steady, +1 rising, and 2 for "don't know yet".

### The class and its state (lines 47–87)

```
class NotAWatchFaceDigitalView extends WatchUi.WatchFace {

    // ---- Layout (set in onLayout) ----
    private var _mainW as Number = 176;
    private var _h as Number = 176;
    private var _leftX as Number = 17;
    private var _dateY as Number = 12;
    private var _labelY as Number = 26;
    private var _labelFont as Graphics.FontType = Graphics.FONT_TINY;
    private var _labelText as String = "";
    private var _topMaxW as Number = 90;   // width available left of the subscreen
    private var _timeY as Number = 60;
    private var _timeFont as Graphics.FontType = Graphics.FONT_NUMBER_MILD;
    private var _sunY as Number = 110;
    private var _rowAY as Number = 128;
    private var _rowBY as Number = 148;
    private var _bottomLimit as Number = 164;
    private var _rowFont as Graphics.FontType = Graphics.FONT_TINY;
    private var _colX as Array<Number> = [35, 88, 141];
    private var _colW as Number = 52;

    // Round subscreen
    private var _hasSub as Boolean = false;
    private var _subX as Number = 0;
    private var _subY as Number = 0;
    private var _subR as Number = 0;

    // ---- Cached values ----
    private var _lat as Float? = null;
    private var _lon as Float? = null;
    private var _sunKey as String = "";
    private var _sunRiseStr as String = "--:--";
    private var _sunSetStr as String = "--:--";

    private var _pressTrend as Number = TREND_UNKNOWN;
    private var _pressHistoryNewest as Float? = null;   // Pa
    private var _pressCheckedAt as Number = 0;

    private var _heading as Number? = null;              // degrees 0-359
    private var _headingDirty as Boolean = false;
    private var _headingSavedAt as Number = 0;
```

**Three groups of fields.**

| Lines | Group | Meaning |
| --- | --- | --- |
| 50–66 | Layout | Where things go: left margin, the y position of each line, the chosen fonts, the three column centres `_colX` and the column width `_colW`. All are overwritten in `onLayout`. |
| 69–72 | Round subscreen | Whether one exists, its centre and its radius. |
| 75–87 | Cached values | Results kept between redraws so slow work is not repeated. |

**Why cache?** In high-power mode `onUpdate` runs every second, according to Garmin's reference. Sunrise maths, a 4-hour barometer scan and storage writes are far too slow to repeat every second, so the face remembers the last answer and recomputes only when its inputs change.

**The `?` in `Float?` and `Number?`** means "a value of that type, or null" *(language rule)*. `_lat` starts as `null` because no position is known yet. Every use of such a field must check for `null` first, and you will see that check again and again below.

**A cache key** such as `_sunKey` is a piece of text that describes the inputs of the last calculation. If today's key equals the saved key, the saved answer is still right. `_pressCheckedAt` and `_headingSavedAt` hold the time (in seconds) of the last pressure scan and the last storage write, so each can be rate-limited.

### initialize (lines 89–107)

```
    function initialize() {
        WatchFace.initialize();
        // Restore the last compass reading and last known position, so they
        // survive the face being reloaded.
        try {
            var h = Application.Storage.getValue("hdg");
            if (h instanceof Number) {
                _heading = h;
            }
            var la = Application.Storage.getValue("lat");
            var lo = Application.Storage.getValue("lon");
            if (la instanceof Float && lo instanceof Float) {
                _lat = la;
                _lon = lo;
            }
        } catch (e) {
            // Nothing stored yet: start empty.
        }
    }
```

- `WatchFace.initialize();` calls the parent's constructor first, as in every View.
- `Application.Storage.getValue("hdg")` asks the saved memory for the value saved under the name `"hdg"`.
- `h instanceof Number` checks that what came back really is a number before using it. A missing or wrong-typed value is simply ignored. The position is accepted only if both halves are `Float`.
- The `try { ... } catch (e) { ... }` wrapper means any failure while reading storage is caught instead of crashing the face. The comment says what the empty `catch` means: "nothing stored yet, start empty."
- **Why restore at all?** The comment gives the reason: the heading and position should "survive the face being reloaded". Without this, every reload would show `---` and `--:--` until new data arrived.

## The View, part 2: onLayout

`onLayout` treats the screen as a fixed budget of vertical space and spends it in priority order: the top text first, then the biggest time font that still leaves room for everything below. A banner comment on lines 109–111 reads "Layout: runs once, works out every size from the actual screen". The function spans lines 112–198 and has four jobs.

### Job 1: find the screen and the subscreen (lines 112–140)

```
    function onLayout(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        _h = h;
        _mainW = w;

        var subLeft = w;
        var subBottom = 0;
        _hasSub = false;
        if (WatchUi has :getSubscreen) {
            var sub = WatchUi.getSubscreen();
            if (sub != null) {
                var sx = sub.x;
                var sy = sub.y;
                if (sx != null && sy != null) {
                    _hasSub = true;
                    var sw = sub.width;
                    var sh = sub.height;
                    _subR = (sw < sh ? sw : sh) / 2;
                    _subX = sx + sw / 2;
                    _subY = sy + sh / 2;
                    subLeft = sx;
                    subBottom = sy + sh;
                    if (w > h) {
                        _mainW = h;
                    }
                }
            }
        }
```

This is the same subscreen detection as in the Analogue face: `has :getSubscreen` is a feature check, and `getSubscreen()` returns a bounding box or `null`, per Garmin's reference. This version also remembers two extra edges, `subLeft` (the subscreen's left edge) and `subBottom` (its bottom edge), because the date, the text and the time must stay clear of them. Without a subscreen they start as the full width and zero, which means "nothing in the way".

**Worked example.** The QA model assumes the subscreen box is x = 113, y = 0, width 62, height 62 (the QA report says this comes from a working Instinct 2 face; it has not been confirmed on this watch here). Then `subLeft` = 113 and `subBottom` = 0 + 62 = 62.

### Job 2: the top-left text block (lines 142–157)

```
        // Top-left block: date, then your text, kept clear of the subscreen.
        _leftX = (_mainW * 0.10).toNumber();
        _dateY = (h * 0.07).toNumber();
        var xtinyH = dc.getFontHeight(Graphics.FONT_XTINY);
        _labelY = _dateY + xtinyH;
        var labelMaxW = (_hasSub ? subLeft - 3 : _mainW - _leftX) - _leftX;
        _topMaxW = labelMaxW;
        _labelFont = Graphics.FONT_TINY;
        if (dc.getTextWidthInPixels(LABEL_TEXT, _labelFont) > labelMaxW) {
            _labelFont = Graphics.FONT_XTINY;
        }
        _labelText = LABEL_TEXT;
        while (_labelText.length() > 0 && dc.getTextWidthInPixels(_labelText, _labelFont) > labelMaxW) {
            _labelText = _labelText.substring(0, _labelText.length() - 1) as String;
        }
        var labelBottom = _labelY + dc.getFontHeight(_labelFont);
```

- The margins are **percentages of the screen**, not pixel counts: the left margin is 10% of the main width and the date line starts 7% down. This is what lets the layout adapt to other screens.
- The label line sits directly under the date line, one small-font height lower (`_labelY`).
- `labelMaxW` is the room for text between the left margin and the subscreen, with a 3-pixel gap. On the QA model that is (113 − 3) − 17 = about 93 pixels, and `_topMaxW` keeps the same number for the date line to use later.
- **A fit-or-shrink ladder.** Try the normal font (`FONT_TINY`); if the text is too wide, use the smaller one (`FONT_XTINY`); if it is still too wide, the `while` loop cuts the last character off, one at a time, until it fits. `substring(0, length - 1)` keeps all but the last character. The `as String` at the end is a cast that tells the compiler what type the result is *(language rule)*.
- `labelBottom` records where the label ends, for the next job.

### Job 3: choose the time font and the row font (lines 159–185)

```
        // Time starts below both the text block and the subscreen.
        var timeTop = (labelBottom > subBottom ? labelBottom : subBottom) + 1;

        // Pick the largest time font and row font that fit top to bottom.
        var bottomLimit = h - 12;   // keep clear of the cut bottom corners
        _bottomLimit = bottomLimit;
        var sunH = xtinyH;
        var timeFonts = [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD,
                         Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL];
        var rowFonts = [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
        _timeFont = Graphics.FONT_SMALL;
        _rowFont = Graphics.FONT_XTINY;
        var found = false;
        for (var i = 0; i < timeFonts.size() && !found; i += 1) {
            var tf = timeFonts[i];
            if (dc.getTextWidthInPixels("00:00", tf) <= _mainW - 10) {
                for (var j = 0; j < rowFonts.size() && !found; j += 1) {
                    var rf = rowFonts[j];
                    var total = timeTop + dc.getFontHeight(tf) + sunH + 2 + 2 * dc.getFontHeight(rf) + 1;
                    if (total <= bottomLimit) {
                        _timeFont = tf;
                        _rowFont = rf;
                        found = true;
                    }
                }
            }
        }
```

- The time may start only below both the label (`labelBottom`) and the subscreen (`subBottom`), so `timeTop` is the lower of the two plus 1 pixel.
- `bottomLimit = h - 12` stops the layout 12 pixels above the bottom edge because the screen's bottom corners are cut.
- **The vertical budget.** Stacked from the top, the face needs the time font's height, the sun line (`sunH`), 2 pixels of gap, two data rows, and 1 pixel more. A combination is acceptable when `total <= bottomLimit`.
- **The search is greedy.** The outer loop tries time fonts from biggest to smallest. For each one that is narrow enough (`"00:00"` must fit in `_mainW - 10`), the inner loop tries row fonts from biggest to smallest. The first pair that fits wins, and `found` stops both loops. Time size therefore has priority over row size.
- The fonts are set to small defaults first, so something valid is used even if no pair fits.

**Illustration with assumed font heights.** These heights come from the QA model's stand-in fonts, not from the watch. With `timeTop` = 63 (just under the 62-pixel subscreen), `sunH` = 13 and `bottomLimit` = 164:

| Time font (height) | Row font (height) | total | Fits? |
| --- | --- | --- | --- |
| NUMBER\_HOT (64) | XTINY (13) | 63 + 64 + 13 + 2 + 26 + 1 = 169 | No: too tall, and every other row font is taller |
| NUMBER\_MEDIUM (50) | SMALL (19) | 63 + 50 + 13 + 2 + 38 + 1 = 167 | No |
| NUMBER\_MEDIUM (50) | TINY (16) | 63 + 50 + 13 + 2 + 32 + 1 = 161 | **Yes: chosen** |

### Job 4: anchor everything (lines 187–198)

```
        // Rows anchored to the bottom; sunrise/sunset line centred in the gap.
        var rowH = dc.getFontHeight(_rowFont);
        _rowBY = bottomLimit - rowH;
        _rowAY = _rowBY - rowH - 1;
        _timeY = timeTop;
        var timeBottom = timeTop + dc.getFontHeight(_timeFont);
        _sunY = timeBottom + ((_rowAY - timeBottom) - sunH) / 2;

        // Columns kept away from the cut bottom corners of the screen.
        _colX = [(_mainW * 0.21).toNumber(), (_mainW * 0.50).toNumber(), (_mainW * 0.79).toNumber()];
        _colW = (_mainW * 0.28).toNumber();
    }
```

- The two data rows are **anchored to the bottom**: row B sits at `bottomLimit - rowH`, and row A one row height plus 1 pixel above it.
- The time starts at `timeTop`. The sun line is centred in whatever gap is left between the time and row A: `gap = rowAY - timeBottom`, and the line is placed half of `(gap - sunH)` below the time.
- The three columns are centred at 21%, 50% and 79% of the width, and each is 28% wide. The outer columns are pulled in from the edges so they clear the cut corners. On a 176-pixel screen that is about 37, 88 and 139 for the centres and about 49 pixels for the width.

## The View, part 3: onUpdate, brackets and the sun line

`onUpdate` follows a clean recipe: take one snapshot of the world, refresh the cached values, then paint the face from the back to the front.

### onUpdate (lines 203–267)

A banner comment on lines 200–202 marks the start of the drawing section.

```
    function onUpdate(dc as Dc) as Void {
        var nowMoment = Time.now();
        var nowSecs = nowMoment.value();
        var today = Gregorian.info(nowMoment, Time.FORMAT_SHORT);
        var clock = System.getClockTime();
        var settings = System.getDeviceSettings();

        // One snapshot of the sensor data for this whole redraw
        var act = Activity.getActivityInfo();

        updateSun(today, settings.is24Hour, act);
        updatePressure(nowSecs);
        updateHeading(nowSecs, act);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        drawBrackets(dc);

        // 1 + 2: date and your text
        var dow = today.day_of_week as Number;
        var month = today.month as Number;
        var day = today.day as Number;
        var dateStr = DAY_NAMES[(dow + 6) % 7] + " " + day.toString() + " " + MONTH_NAMES[(month + 11) % 12];
        if (dc.getTextWidthInPixels(dateStr, Graphics.FONT_XTINY) > _topMaxW) {
            // Too wide to clear the subscreen: drop the weekday
            dateStr = day.toString() + " " + MONTH_NAMES[(month + 11) % 12];
        }
        dc.drawText(_leftX, _dateY, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(_leftX, _labelY, _labelFont, _labelText, Graphics.TEXT_JUSTIFY_LEFT);

        // Time
        dc.drawText(_mainW / 2, _timeY, _timeFont, formatTime(clock.hour, clock.min, settings.is24Hour),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // 4 + 5: sunrise and sunset
        drawSunLine(dc);

        // 6 7 8
        var hdg = _heading;
        var hdgText = "---";
        if (hdg != null) {
            hdgText = hdg.format("%d");
        }
        var rowA = [heartRateText(act), stepsText(), distanceText(settings)];
        var rowB = [altitudeText(settings, act), hdgText, pressureText(act)];
        var degB = [false, hdg != null, false];
        var degNone = [false, false, false];

        // Each row uses one font, so all three values in a row match in size.
        var fontA = rowFont(dc, rowA, degNone);
        drawCell(dc, 0, _rowAY, ICON_HEART, rowA[0], false, TREND_UNKNOWN, fontA);
        drawCell(dc, 1, _rowAY, ICON_STEPS, rowA[1], false, TREND_UNKNOWN, fontA);
        drawCell(dc, 2, _rowAY, ICON_DISTANCE, rowA[2], false, TREND_UNKNOWN, fontA);

        // 9 10 11
        var fontB = rowFont(dc, rowB, degB);
        drawCell(dc, 0, _rowBY, ICON_ALTITUDE, rowB[0], false, TREND_UNKNOWN, fontB);
        drawCell(dc, 1, _rowBY, ICON_COMPASS, rowB[1], degB[1], TREND_UNKNOWN, fontB);
        drawCell(dc, 2, _rowBY, ICON_PRESSURE, rowB[2], false, _pressTrend, fontB);

        // 3: moon, drawn last inside the subscreen
        drawMoon(dc, nowSecs);
    }
```

**Step 1: one snapshot (lines 204–211).**

- `Time.now()` is the current moment. `.value()` turns it into a count of seconds, used for rate-limiting and for the moon.
- `Gregorian.info(nowMoment, Time.FORMAT_SHORT)` splits the moment into calendar parts: year, month, day, weekday.
- `System.getClockTime()` gives the watch's local hour, minute and second. `System.getDeviceSettings()` gives its settings, such as the 12/24-hour flag.
- `Activity.getActivityInfo()` is called **once** and the result `act` is passed to every helper. An earlier version read sensors five times per redraw; reading once was QA defect 6.

**Step 2: refresh the caches (lines 213–215).** Each of the three `update...` functions decides for itself whether anything needs recomputing, as the later parts explain.

**Step 3: paint the background (lines 217–221).** Clear to black, set the pen to white, draw the corner brackets.

**Step 4: the date line (lines 223–233).**

- The weekday and month numbers become text through list positions. For Friday 30 October, `dow` is 6, so `(6 + 6) % 7 = 5` gives `"FRI"`, and `month` is 10, so `(10 + 11) % 12 = 9` gives `"OCT"`. Strings are joined with `+`: `"FRI 30 OCT"`.
- **A width guard.** If the full date is wider than `_topMaxW` (the room left of the subscreen), the weekday is dropped, giving `"30 OCT"`. This was QA defect 5.
- `drawText(x, y, font, text, TEXT_JUSTIFY_LEFT)` writes from the left edge, with `(x, y)` as the text's top-left. The label goes on the next line down, using the font and the already-trimmed text chosen in `onLayout`.

**Step 5: the time (lines 235–237).** Centred horizontally on `_mainW / 2`, at the `_timeY` and font from `onLayout`, formatted by `formatTime`, which follows the watch's 12/24-hour setting.

**Step 6: the data rows (lines 242–263).**

- `var hdg = _heading;` copies the field into a local before testing it for `null`. That is a common habit in Monkey C: test a local copy, then use the same copy *(language rule, as understood in this project)*.
- The compass text is `"---"` until there is a heading, otherwise the number as text. `format("%d")` turns a whole number into text.
- Each row is an array of three strings. `degB` and `degNone` are arrays of three true/false values: "does this cell get a degree mark?" Only the compass cell does.
- `rowFont` picks **one font per row**, so the three values in a row always match in size. This was QA defect 2.
- `drawCell(dc, column, y, icon, text, degree, trend, font)` draws one cell. Only the pressure cell receives the real trend; the others pass `TREND_UNKNOWN` because they have no arrow.

**Step 7: the moon (lines 265–266).** Drawn last, inside the subscreen, so nothing is painted over it.

### drawBrackets (lines 269–289)

```
    private function drawBrackets(dc as Dc) as Void {
        var m = 9;     // inset from the edge; the screen's corners are cut
        var len = 11;
        var r = _mainW - m;
        var b = _h - m;
        // Bottom brackets: short upright arms so they stay below the bottom row.
        var up = b - _bottomLimit - 2;
        if (up < 3) {
            up = 3;
        } else if (up > len) {
            up = len;
        }
        dc.setPenWidth(1);
        dc.drawLine(m, m, m + len, m);
        dc.drawLine(m, m, m, m + len);
        dc.drawLine(m, b, m + len, b);
        dc.drawLine(m, b, m, b - up);
        dc.drawLine(r, b, r - len, b);
        dc.drawLine(r, b, r, b - up);
        // No top-right bracket: that corner is the subscreen.
    }
```

- The brackets are 11-pixel corner marks inset 9 pixels from the edges, because the real screen's corners are cut. `r` and `b` are the right and bottom lines.
- The bottom brackets' upright arms must stay below the bottom data row, so their height `up` is the space between the row limit and the bracket line, clamped to between 3 and 11 pixels. `if ... else if` is how the clamp is written. On a 176-pixel screen, `up` = 167 − 164 − 2 = 1, which the clamp raises to 3. This was QA defect 4.
- Three corners get two lines each. The top-right corner is left empty because the subscreen lives there.

### drawSunLine (lines 291–312)

```
    private function drawSunLine(dc as Dc) as Void {
        var font = Graphics.FONT_XTINY;
        var tri = 7;
        var gapIn = 3;
        var gapMid = 10;
        var w1 = dc.getTextWidthInPixels(_sunRiseStr, font);
        var w2 = dc.getTextWidthInPixels(_sunSetStr, font);
        var total = tri + gapIn + w1 + gapMid + tri + gapIn + w2;
        var x = _mainW / 2 - total / 2;
        var midY = _sunY + dc.getFontHeight(font) / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // Sunrise: up triangle
        dc.fillPolygon([[x, midY + 3], [x + tri, midY + 3], [x + tri / 2.0, midY - 3]]);
        x += tri + gapIn;
        dc.drawText(x, midY, font, _sunRiseStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += w1 + gapMid;
        // Sunset: down triangle
        dc.fillPolygon([[x, midY - 3], [x + tri, midY - 3], [x + tri / 2.0, midY + 3]]);
        x += tri + gapIn;
        dc.drawText(x, midY, font, _sunSetStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
```

- **Centring a group.** The line is a triangle, a gap, the sunrise text, a bigger gap, a triangle, a gap and the sunset text. `total` adds up all the pieces, and `x = _mainW / 2 - total / 2` starts the group so it is centred. Each piece then moves `x` rightwards past itself.
- `midY` is the vertical middle of the line. The text uses `TEXT_JUSTIFY_VCENTER`, so its `y` is its middle too.
- Each triangle is `fillPolygon` with three points, 6 pixels tall. For sunrise the base is below (`midY + 3`) and the apex above (`midY - 3`), so it points up; for sunset it is the other way round. `x + tri / 2.0` is the apex, halfway across; the `2.0` keeps the half-pixel.
- No bitmaps are used: every symbol in this face is drawn from lines, circles and polygons.

## The View, part 4: rows, cells and icons

Every data field is a small cell made of an icon and a value, and the icons are drawn from shapes, so the face needs no image files at all.

### rowFont (lines 314–331)

```
    // Largest row font at which all three values fit their columns.
    private function rowFont(dc as Dc, texts as Array<String>, degrees as Array<Boolean>) as Graphics.FontType {
        var candidates = [_rowFont, Graphics.FONT_XTINY];
        for (var c = 0; c < candidates.size(); c += 1) {
            var f = candidates[c];
            var fits = true;
            for (var i = 0; i < texts.size(); i += 1) {
                var need = 12 + dc.getTextWidthInPixels(texts[i], f) + (degrees[i] ? 6 : 0);
                if (need > _colW) {
                    fits = false;
                }
            }
            if (fits) {
                return f;
            }
        }
        return Graphics.FONT_XTINY;
    }
```

- The function receives the three texts of one row and the three "has a degree mark" flags, and returns **one font for the whole row**.
- It tries the font chosen in `onLayout` first, then the smallest font.
- A cell needs `12 + text width (+ 6 if it has a degree mark)` pixels. The 12 is the icon width (10) plus the gap (2) used in `drawCell`, and the 6 is the room for the small degree circle. If any of the three needs more than the column width `_colW`, that font fails and the next is tried.
- The first font where all three fit is returned straight away; `return` leaves the function. If none fits, the smallest font is the fallback.

**Illustration with assumed widths.** With `_colW` about 49, suppose the steps text `"24567"` is 40 pixels wide in the bigger font and 32 in the smaller. Bigger: 12 + 40 = 52 > 49, so it fails. Smaller: 12 + 32 = 44 ≤ 49, so the whole row uses the smaller font. The widths here are made up to show the arithmetic; the watch reports the real ones.

### drawCell (lines 333–352)

```
    // One data field: small icon on the left, value on the right, centred in its column.
    private function drawCell(dc as Dc, col as Number, y as Number, icon as Number, text as String,
                              degree as Boolean, trend as Number, font as Graphics.FontType) as Void {
        var iconW = 10;
        var gap = 2;
        var degW = degree ? 6 : 0;
        var tw = dc.getTextWidthInPixels(text, font);
        var total = iconW + gap + tw + degW;
        var left = _colX[col] - total / 2;
        var midY = y + dc.getFontHeight(_rowFont) / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawIcon(dc, icon, left + iconW / 2, midY, trend);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + iconW + gap, midY, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (degree) {
            var fh = dc.getFontHeight(font);
            dc.drawCircle(left + iconW + gap + tw + 3, midY - fh / 4, 2);
        }
    }
```

- **Centre the whole cell in its column.** The cell is as wide as icon + gap + text + degree room (`total`). Its left edge is the column's centre minus half of that: `left = _colX[col] - total / 2`.
- `midY` is the vertical middle of the row. It is measured with `_rowFont`, the row's nominal font, so every cell in the row shares one centre line even when the chosen font is smaller.
- The icon is drawn centred inside the first 10 pixels. The text starts after the icon and the gap, left-justified and vertically centred on `midY`.
- The pen colour is set before the icon and again before the text, so each is drawn in white regardless of what `drawIcon` did.
- The degree mark is a circle of radius 2, placed 3 pixels after the text and a quarter of the font height above the middle, so it looks like a raised ° sign.

### drawIcon (lines 354–394)

```
    private function drawIcon(dc as Dc, icon as Number, x as Number, y as Number, trend as Number) as Void {
        dc.setPenWidth(1);
        if (icon == ICON_HEART) {
            dc.fillCircle(x - 2, y - 2, 2);
            dc.fillCircle(x + 2, y - 2, 2);
            dc.fillPolygon([[x - 4, y - 1], [x + 4, y - 1], [x, y + 4]]);
        } else if (icon == ICON_STEPS) {
            dc.fillRectangle(x - 4, y - 4, 3, 5);
            dc.fillRectangle(x + 1, y - 1, 3, 5);
        } else if (icon == ICON_DISTANCE) {
            dc.drawLine(x - 4, y, x + 5, y);
            dc.drawLine(x - 4, y, x - 2, y - 2);
            dc.drawLine(x - 4, y, x - 2, y + 2);
            dc.drawLine(x + 4, y, x + 2, y - 2);
            dc.drawLine(x + 4, y, x + 2, y + 2);
        } else if (icon == ICON_ALTITUDE) {
            dc.fillPolygon([[x - 5, y + 4], [x - 1, y - 4], [x + 1, y], [x + 2, y - 2], [x + 5, y + 4]]);
        } else if (icon == ICON_COMPASS) {
            // North half filled, south half outlined
            dc.fillPolygon([[x, y - 5], [x + 3, y], [x - 3, y]]);
            dc.drawLine(x - 3, y, x, y + 5);
            dc.drawLine(x + 3, y, x, y + 5);
        } else if (icon == ICON_PRESSURE) {
            if (trend == TREND_RISING) {
                dc.drawLine(x - 4, y + 3, x + 3, y - 4);
                dc.drawLine(x + 3, y - 4, x - 1, y - 4);
                dc.drawLine(x + 3, y - 4, x + 3, y);
            } else if (trend == TREND_FALLING) {
                dc.drawLine(x - 4, y - 3, x + 3, y + 4);
                dc.drawLine(x + 3, y + 4, x - 1, y + 4);
                dc.drawLine(x + 3, y + 4, x + 3, y);
            } else if (trend == TREND_STEADY) {
                dc.drawLine(x - 4, y, x + 4, y);
                dc.drawLine(x + 4, y, x + 1, y - 3);
                dc.drawLine(x + 4, y, x + 1, y + 3);
            } else {
                // Not enough history yet: plain barometer dial
                dc.drawCircle(x, y, 4);
            }
        }
    }
```

**The idea.** `(x, y)` is the icon's centre. Every shape is described by its offset from that centre, in whole pixels, and no icon is wider than 10 pixels, matching `iconW` in `drawCell`. An `if ... else if` chain on the icon id picks which shape to draw.

| Icon | How it is built |
| --- | --- |
| Heart | Two filled circles of radius 2 side by side, plus a downward-pointing filled triangle under them |
| Steps | Two 3 × 5 filled rectangles, one higher on the left and one lower on the right, like two footprints |
| Distance | A horizontal line with a small arrowhead made of two short slanted lines at each end |
| Altitude | One five-point filled polygon: a mountain outline with a tall peak on the left, a dip, and a smaller peak on the right |
| Compass | A filled triangle for the north half, and two lines forming an open triangle for the south half |
| Pressure | A trend arrow of three lines: a diagonal and two arrowhead lines pointing up-right when rising, down-right when falling, or a flat arrow when steady. With no trend yet, a circle of radius 4, a plain dial |

**Why draw icons instead of using pictures?** A picture needs a resource file and is scaled by the system. Shapes drawn in code are exact on a two-colour screen, cost no extra files, and can be changed by editing a number. The trade-off is that every icon is hand-tuned, so a new one means a new `else if` branch.

## The View, part 5: the moon phase picture

The moon is drawn one pixel row at a time, and it is the best lesson in the project for turning maths into a picture.

### drawMoon (lines 396–430)

```
    // 3: moon phase picture inside the round subscreen (northern-hemisphere view).
    private function drawMoon(dc as Dc, nowSecs as Number) as Void {
        if (!_hasSub) {
            return;
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillCircle(_subX, _subY, _subR);

        var r = (_subR * 0.62).toNumber();
        if (r < 5) {
            r = 5;
        }
        var phase = Astro.moonPhase(nowSecs);
        var c = Math.cos(2.0 * Math.PI * phase);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Fill the lit part row by row. Waxing: lit on the right; waning: on the left.
        for (var yy = -r; yy <= r; yy += 1) {
            var half = Math.sqrt((r * r - yy * yy).toFloat());
            var x1 = 0.0;
            var x2 = 0.0;
            if (phase < 0.5) {
                x1 = half * c;
                x2 = half;
            } else {
                x1 = -half;
                x2 = -half * c;
            }
            if (x2 - x1 >= 0.5) {
                dc.drawLine(_subX + x1, _subY + yy, _subX + x2, _subY + yy);
            }
        }
        dc.drawCircle(_subX, _subY, r);
    }
```

**Set-up (lines 398–409).**

- Without a subscreen there is nowhere to draw, so the function returns at once.
- The subscreen circle is filled black to wipe anything underneath, then the moon's radius `r` is 62% of the subscreen's radius (never below 5 pixels). With a 31-pixel subscreen radius that is about 19 pixels.
- `phase` comes from `Astro.moonPhase`: 0 is a new moon, 0.25 first quarter, 0.5 full, 0.75 last quarter, and back to 1 for the next new moon.
- `c = cos(2π × phase)` is a single number between −1 and 1 that describes how far the day/night edge is from the middle.

**The row-by-row fill (lines 414–428).**

1. The loop visits every pixel row from `-r` (top) to `+r` (bottom). `yy` is that row's distance from the middle.
2. `half = sqrt(r² − yy²)` is how far the full circle reaches left and right on that row. This is Pythagoras: a point on the circle satisfies `x² + y² = r²`. The `.toFloat()` turns the whole-number result into a decimal before the square root.
3. The lit part of that row is a stretch from `x1` to `x2`:
   - **Waxing** (`phase < 0.5`, growing toward full): lit on the right, from `half * c` to `half`.
   - **Waning** (`phase >= 0.5`): lit on the left, from `-half` to `-half * c`.
4. If the stretch is at least half a pixel long, one horizontal line draws it. Thinner slivers are skipped.
5. After the loop, a 1-pixel circle outlines the whole moon, so the dark part still shows its shape.

**How the phases come out.**

| Phase | Name | c | Lit stretch on each row |
| --- | --- | --- | --- |
| 0 | New | 1 | `half` to `half`: nothing |
| 0.10 | Thin waxing crescent | cos 36° ≈ 0.81 | `0.81 × half` to `half`: a thin right-hand sliver |
| 0.25 | First quarter | 0 | 0 to `half`: the right half |
| 0.35 | Waxing gibbous | cos 126° ≈ −0.59 | `−0.59 × half` to `half`: more than the right half |
| 0.50 | Full | −1 | `−half` to `half`: the whole disc |
| 0.75 | Last quarter | 0 | `−half` to 0: the left half |

**The idea behind it.** The curved edge between light and dark, the terminator, is an ellipse. On every row it sits at `half * c`: the shape is a circle squashed sideways by the factor `c`. At a quarter moon the squash is total and the edge is a straight line; at a full or new moon it matches the circle.

**Orientation.** The comment says "northern-hemisphere view": a waxing moon is lit on the right. A viewer in the southern hemisphere sees the same phases mirrored. The project's QA report lists this as a deliberate limit.

**Accuracy.** The phase uses the average length of a lunar month, so it can be off by up to about a day. That is fine for a small picture, and the next sections show where that comes from.

## The View, part 6: reading the watch

Each reader function follows one pattern: try the best source, fall back to the next, and finally return `"--"`, so the drawing code never has to handle a missing value.

### formatTime (lines 432–444)

```
    // ------------------------------------------------------------------
    // Data
    // ------------------------------------------------------------------
    private function formatTime(hour as Number, minute as Number, is24 as Boolean) as String {
        if (is24) {
            return hour.format("%02d") + ":" + minute.format("%02d");
        }
        var h12 = hour % 12;
        if (h12 == 0) {
            h12 = 12;
        }
        return h12.toString() + ":" + minute.format("%02d");
    }
```

The Analogue face reads the 12/24-hour setting inside this function. Here the caller passes it in as `is24`, because `onUpdate` has already fetched the settings and `updateSun` needs the same flag. `format("%02d")` pads to two digits with a leading zero. In 12-hour mode `hour % 12` gives 0 at midnight and noon, which becomes 12, and the hour has no leading zero: 13:07 shows as `1:07`.

### Heart rate and steps (lines 446–473)

```
    // 6: heart rate. Current reading first, then the newest sample from the
    // watch's all-day heart-rate history.
    private function heartRateText(act as Activity.Info?) as String {
        if (act != null) {
            var current = act.currentHeartRate;
            if (current != null) {
                return current.toString();
            }
        }
        if (ActivityMonitor has :getHeartRateHistory) {
            var it = ActivityMonitor.getHeartRateHistory(1, true);
            var s = it.next();
            if (s != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                return s.heartRate.toString();
            }
        }
        return "--";
    }

    // 7: steps today
    private function stepsText() as String {
        var info = ActivityMonitor.getInfo();
        var steps = info.steps;
        if (steps == null) {
            return "--";
        }
        return steps.toString();
    }
```

- **The ladder for heart rate.** `act` may be `null`, so test it first. If the live reading `currentHeartRate` exists, return it as text. Otherwise check that the history feature exists (`has :getHeartRateHistory`), ask for one sample, and use it unless it equals `INVALID_HR_SAMPLE`, Garmin's marker for "no valid reading". If everything fails, return `"--"`.
- `act as Activity.Info?` in the parameter list means "an `Activity.Info`, or null".
- **Steps** have a single source. `ActivityMonitor.getInfo().steps` can be `null`, which becomes `"--"`; otherwise the number is turned into text.

### Distance (lines 475–484)

```
    // 8: distance today, in km or miles to match the watch's unit setting
    private function distanceText(settings as System.DeviceSettings) as String {
        var info = ActivityMonitor.getInfo();
        var cm = info.distance;
        if (cm == null) {
            return "--";
        }
        var value = (settings.distanceUnits == System.UNIT_STATUTE) ? cm / 160934.4 : cm / 100000.0;
        return value < 100.0 ? value.format("%.1f") : value.toNumber().toString();
    }
```

- The watch reports distance in **centimetres**. A kilometre is 100,000 cm and a mile is 160,934.4 cm, so the divisor depends on the watch's unit setting: `System.UNIT_STATUTE` means miles.
- The `? :` expression picks one of two values, and the last line uses it again: below 100 the value is shown with one decimal (`format("%.1f")`), otherwise as a whole number. That keeps the text short enough for its column.

| Distance (cm) | Unit setting | Shown |
| --- | --- | --- |
| 420,000 | Metric | `4.2` |
| 420,000 | Statute | `2.6` |
| 12,300,000 | Metric | `123` |

### Altitude (lines 486–513)

```
    // 9: altitude in metres or feet to match the watch's unit setting
    private function altitudeText(settings as System.DeviceSettings, act as Activity.Info?) as String {
        if (act != null) {
            var fromActivity = act.altitude;
            if (fromActivity != null) {
                return altitudeString(fromActivity, settings);
            }
        }
        if ((Toybox has :SensorHistory) && (SensorHistory has :getElevationHistory)) {
            var it = SensorHistory.getElevationHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
            var s = it.next();
            if (s != null) {
                var v = s.data;
                if (v != null) {
                    return altitudeString(v.toFloat(), settings);
                }
            }
        }
        return "--";
    }

    private function altitudeString(metres as Float, settings as System.DeviceSettings) as String {
        var value = metres;
        if (settings.elevationUnits == System.UNIT_STATUTE) {
            value = metres * 3.28084;
        }
        return value.toNumber().toString();
    }
```

- The first choice is the live altitude from the activity data. The fallback is the elevation history, behind a **two-level feature check**: first that the `SensorHistory` module exists at all (`Toybox has :SensorHistory`), then that it offers `getElevationHistory`.
- The argument `{:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST}` is a dictionary with symbol keys: one sample, newest first. `s.data` is the value and may be `null`.
- `altitudeString` converts metres to feet when the elevation unit is statute (1 metre = 3.28084 feet) and shows a whole number. For example, 216 m is about 708 ft.
- This is why the manifest asks for the `SensorHistory` permission.

### Pressure (lines 515–541)

```
    // 11: current pressure in hPa (the arrow icon shows the 3-hour trend)
    private function pressureText(act as Activity.Info?) as String {
        if (act != null) {
            if (act has :meanSeaLevelPressure) {
                var seaLevel = act.meanSeaLevelPressure;
                if (seaLevel != null) {
                    return hpaString(seaLevel);
                }
            }
            if (act has :ambientPressure) {
                var ambient = act.ambientPressure;
                if (ambient != null) {
                    return hpaString(ambient);
                }
            }
        }
        var fromHistory = _pressHistoryNewest;
        if (fromHistory != null) {
            return hpaString(fromHistory);
        }
        return "--";
    }

    // Pascals to whole hectopascals, as text
    private function hpaString(pa as Float) as String {
        return (pa / 100.0).toNumber().toString();
    }
```

- A three-step ladder: sea-level pressure, then the raw (ambient) pressure, then the newest barometer-history value saved by `updatePressure`. `act has :meanSeaLevelPressure` checks that this *object* offers the field before reading it.
- The watch reports pascals, and a hectopascal is 100 pascals. A standard 101,325 Pa becomes 1013 hPa.
- The arrow beside the value is not decided here. It comes from the trend, computed in the next part.

## The View, part 7: the pressure trend

The pressure cell shows a number (from part 6) and a small arrow icon. This function decides which arrow. It answers one question: *is the air pressure now higher, lower or about the same as roughly three hours ago?*

```
    // Pressure trend from the barometer history: newest reading compared with
    // the reading about 3 hours earlier. Checked at most every 10 minutes.
    // A change under 1 hPa counts as steady.
    private function updatePressure(nowSecs as Number) as Void {
        if (_pressCheckedAt != 0 && nowSecs - _pressCheckedAt < 600) {
            return;
        }
        _pressCheckedAt = nowSecs;
        _pressTrend = TREND_UNKNOWN;
        _pressHistoryNewest = null;
        if (!((Toybox has :SensorHistory) && (SensorHistory has :getPressureHistory))) {
            return;
        }
        var it = SensorHistory.getPressureHistory({
            :period => new Time.Duration(4 * 3600),
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });
        var haveNewest = false;
        var newest = 0.0;
        var newestT = 0;
        var haveOlder = false;
        var older = 0.0;
        var olderAge = 0;
        var guard = 0;
        var s = it.next();
        while (s != null && guard < 600) {
            guard += 1;
            var v = s.data;
            if (v != null) {
                var t = s.when.value();
                if (!haveNewest) {
                    newest = v.toFloat();
                    newestT = t;
                    haveNewest = true;
                } else {
                    older = v.toFloat();
                    olderAge = newestT - t;
                    haveOlder = true;
                    if (olderAge >= 3 * 3600) {
                        break;
                    }
                }
            }
            s = it.next();
        }
        if (haveNewest) {
            _pressHistoryNewest = newest;
        }
        // Need at least 2.5 hours of history (it is wiped when the watch restarts).
        if (haveNewest && haveOlder && olderAge >= 9000) {
            var deltaHpa = (newest - older) / 100.0;
            if (deltaHpa >= 1.0) {
                _pressTrend = TREND_RISING;
            } else if (deltaHpa <= -1.0) {
                _pressTrend = TREND_FALLING;
            } else {
                _pressTrend = TREND_STEADY;
            }
        }
    }
```

### Walk through it in six segments

| Lines | Segment | What it does |
| --- | --- | --- |
| 546–552 | Throttle and reset | The first call always runs (`_pressCheckedAt` starts at 0). After that, if fewer than 600 seconds (10 minutes) have passed since the last run, `return` leaves the stored answer alone. Otherwise it stamps the time, then resets the trend to `TREND_UNKNOWN` and the saved reading to `null`, so a failed run can never leave stale data behind. |
| 553–555 | Feature check | If this watch has no `SensorHistory` module, or the module has no `getPressureHistory`, give up quietly. The time stamp was already set, so this is retried only every 10 minutes. |
| 556–559 | Ask for history | The argument is a dictionary with two symbol keys: `:period` is a `Time.Duration` of `4 * 3600` = 14,400 seconds (four hours) and `:order` asks for the newest sample first. The result `it` is an *iterator*: each `it.next()` hands back the next sample, or `null` at the end. |
| 560–566 | Working variables | Flags and slots for the newest and an older reading, plus `guard`, a safety counter. Every local is declared with a bare `var`: this project's compiler rejected typed locals (see the Digital notes in the QA record). |
| 567–587 | The loop | Walks the samples from newest to oldest. Explained below. |
| 588–601 | The decision | Saves the newest reading for `pressureText`, then compares newest and older. |

### The loop, line by line

- `var s = it.next();` fetches the first sample before the loop starts, and `s = it.next();` at the bottom fetches the next. The loop ends when `s` is `null`, or when `guard` reaches 600. The guard is a fuse: it stops the loop after 600 samples even if the iterator misbehaves.
- `var v = s.data;` is the pressure value, which can be `null` for a missing sample, so the body only runs `if (v != null)`.
- `var t = s.when.value();` is the sample's time as whole seconds. The subtraction `newestT - t` later gives an age in seconds.
- **First valid sample:** `!haveNewest` is true, so it is stored as `newest` and its time as `newestT`.
- **Every later valid sample** goes into `older` and sets `olderAge = newestT - t`. Each new sample overwrites the last one, so when the loop ends, `older` holds the *oldest sample seen*. The `break` fires as soon as a sample is at least `3 * 3600` = 10,800 seconds (3 hours) older than the newest, which is the one we wanted.

### The decision

The samples are in pascals, and `/ 100.0` converts the difference to hectopascals (the same conversion as in part 6). The comparison needs `olderAge >= 9000` seconds (2.5 hours), so a history of at least 2.5 hours gives an answer even when no sample is a full three hours old.

| Change over the window | Result | Arrow icon drawn |
| --- | --- | --- |
| `deltaHpa >= 1.0` | `TREND_RISING` | Arrow pointing up and to the right |
| `deltaHpa <= -1.0` | `TREND_FALLING` | Arrow pointing down and to the right |
| between those values | `TREND_STEADY` | Horizontal arrow |
| Not enough history | `TREND_UNKNOWN` | A small circle, the "plain barometer dial" |

The arrows come from `drawIcon` (lines 376–392, part 4); this function only chooses the constant.

### A worked example (invented numbers, to follow the logic)

Suppose the history, newest first, starts like this:

| Sample | Time | Pressure (Pa) | Age vs newest | What the loop does |
| --- | --- | --- | --- | --- |
| 1 | 14:00 | 101,320 | 0 | `newest` = 101,320, `newestT` = 14:00 |
| 2 | 13:55 | 101,315 | 5 min | `older` = 101,315, `olderAge` = 300, keep going |
| … | … | … | … | each sample replaces `older` |
| n | 11:00 | 101,150 | 3 h = 10,800 s | `older` = 101,150, `olderAge` = 10,800, `break` |

Then `deltaHpa = (101320 - 101150) / 100.0 = 1.7`. That is at least 1.0, so the trend is `TREND_RISING`.

Two other outcomes, using the same rules:

- If the oldest sample were 101,290 Pa, the change would be 0.3 hPa: `TREND_STEADY`.
- If the history covered only 1 hour 40 minutes (`olderAge` = 6000), the check `olderAge >= 9000` fails. The trend stays `TREND_UNKNOWN` and the circle icon is drawn, but `newest` is still saved, so the number can still be shown.

### Notes

- The comment says the history "is wiped when the watch restarts". That is the project's own comment; it has not been checked against Garmin's documentation. The code does not depend on it: with no history, the trend is simply unknown.
- The throttle makes the expensive history walk run about every 10 minutes instead of every second. Between runs the two cached fields (`_pressTrend`, `_pressHistoryNewest`) are what `drawCell` and `pressureText` read.
- The 1 hPa dead band stops the arrow flickering between "up" and "steady" on tiny changes.

## The View, part 8: compass heading and last known position

Two small jobs that share a pattern: take a reading when one exists, remember it, and save it to the watch's storage so it survives a reload. You met the other half of this in `initialize` (part 1, lines 91–106), which reads the saved values back.

### updateHeading (lines 604–631)

```
    // 10: last compass reading. Garmin doesn't document how the heading
    // behaves on a watch face; developers report it holds the value from the
    // last time the watch's compass was used. Whatever real reading arrives
    // is kept (and saved) until a new one replaces it. An exact 0.0 is
    // treated as "no reading".
    private function updateHeading(nowSecs as Number, act as Activity.Info?) as Void {
        if (act != null) {
            var h = act.currentHeading;
            if (h != null && h != 0.0) {
                var deg = Astro.fmod(Math.toDegrees(h).toFloat(), 360.0);
                var rounded = (deg + 0.5).toNumber() % 360;
                if (_heading == null || rounded != _heading) {
                    _heading = rounded;
                    _headingDirty = true;
                }
            }
        }
        // Save at most once a minute to spare the watch's storage.
        if (_headingDirty && nowSecs - _headingSavedAt >= 60) {
            try {
                Application.Storage.setValue("hdg", _heading);
                _headingSavedAt = nowSecs;
                _headingDirty = false;
            } catch (e) {
                // Storage full or unavailable: keep showing the value anyway.
            }
        }
    }
```

The comment above the function is the author's own statement about how the heading behaves. It has not been verified against Garmin's documentation. The code does not rely on it: it only keeps whatever real reading arrives.

**Segment 1: take a reading (lines 610–620).**

- `act.currentHeading` is the compass heading, or `null`. The code treats an exact `0.0` as "no reading" too.
- The heading arrives in radians, so `Math.toDegrees(h)` converts it. `.toFloat()` makes sure the value is a `Float` before it goes to `Astro.fmod`, which wraps any angle into the range 0 up to (not including) 360. Because `fmod` uses `floor`, negative angles wrap correctly: -90 becomes 270.
- `(deg + 0.5).toNumber() % 360` rounds to the nearest whole degree. `.toNumber()` drops the decimals (a language rule that has not been verified), so adding 0.5 first turns "drop" into "round". The final `% 360` matters at the top end: 359.6 rounds up to 360, and `360 % 360` is 0, so the compass never shows 360.
- The new value is stored only if there was none, or if it differs (`rounded != _heading`), and then `_headingDirty` is raised: "there is something to save".

| Reading (radians) | Degrees after `fmod` | Rounded and wrapped | Shown |
| --- | --- | --- | --- |
| 0.7854 | 45.0 | 45 | `45` |
| 4.7124 | 270.0 | 270 | `270` |
| -1.5708 | 270.0 (from -90.0) | 270 | `270` |
| 6.2800 | 359.8 | 360 % 360 = 0 | `0` |

(Values computed by hand from the formulas above, with the radians rounded to four decimals.)

**Segment 2: save, but not too often (lines 621–630).**

- `_headingDirty` says there is a new value. `nowSecs - _headingSavedAt >= 60` says at least a minute has passed since the last save. Both must be true. `_headingSavedAt` starts at 0, so the very first save happens at once.
- `Application.Storage.setValue("hdg", _heading)` writes the number under the key `"hdg"`.
- The save sits inside `try { } catch (e) { }`. If storage is full or unavailable, the error is caught and the face carries on, still showing the value in memory. The comment inside the `catch` explains why it is empty.
- Each of the two time-keeping lines runs only after a successful save, so a failed save is retried on the next update.

The heading is used for display at lines 243–247 in `onUpdate`: `hdg.format("%d")` for the number, or `"---"` when nothing has been recorded.

### lastKnownLocation (lines 633–646)

```
    // Last known position, from an activity's GPS or the watch's own last fix.
    private function lastKnownLocation(act as Activity.Info?) as Position.Location? {
        if (act != null) {
            var fromActivity = act.currentLocation;
            if (fromActivity != null) {
                return fromActivity;
            }
        }
        var pinfo = Position.getInfo();
        if (pinfo != null) {
            return pinfo.position;
        }
        return null;
    }
```

The same "ladder" idea as the data readers in part 6: first the position carried by the activity data, then the watch's own last fix from `Position.getInfo()`, then `null`. The return type `Position.Location?` ends in a question mark, which means "a location, or null".

*Note on a possible editor warning.* VS Code may underline `return null;` (line 645) as "Statement is not reachable". The likely reason is that the type checker believes `Position.getInfo()` is never `null`, so the `if` always succeeds. That is an inference, not something that was verified, and it does no harm: the line is a safety net.

### updateLocation and absF (lines 648–676)

```
    private function updateLocation(act as Activity.Info?) as Void {
        var loc = lastKnownLocation(act);
        if (loc == null) {
            return;
        }
        var deg = loc.toDegrees();
        var lat = deg[0].toFloat();
        var lon = deg[1].toFloat();
        // Ignore placeholder values the watch reports when it has no fix.
        if ((lat == 0.0 && lon == 0.0) || lat > 90.0 || lat < -90.0 || lon > 180.0 || lon < -180.0) {
            return;
        }
        var oldLat = _lat;
        var oldLon = _lon;
        if (oldLat == null || oldLon == null || absF(lat - oldLat) > 0.05 || absF(lon - oldLon) > 0.05) {
            _lat = lat;
            _lon = lon;
            try {
                Application.Storage.setValue("lat", lat);
                Application.Storage.setValue("lon", lon);
            } catch (e) {
                // Not saved; still used for today.
            }
        }
    }

    private function absF(v as Float) as Float {
        return v < 0.0 ? -v : v;
    }
```

1. **Get a location.** If there is none, stop (`return`).
2. **Convert.** `loc.toDegrees()` gives an array: index 0 is the latitude and index 1 the longitude, both in degrees. `.toFloat()` turns each into a `Float`.
3. **Reject nonsense.** Exactly (0, 0), or a latitude outside -90 to 90, or a longitude outside -180 to 180, cannot be a real fix, so the function returns without changing anything. The comment says these are placeholder values the watch reports when it has no fix.
4. **Update only if it matters.** The position is replaced and saved only if there is no earlier position, or the latitude or longitude moved by more than 0.05 degrees. One degree of latitude is roughly 111 km, so 0.05 degrees is a bit over 5 km. 0.05 degrees of longitude is 0.2 minutes (12 seconds) of solar time, small next to a display in whole minutes. The effect of latitude depends on place and season, and it was not measured. Fewer changes also means fewer storage writes and fewer sun recalculations.
5. **`absF`** is a hand-made absolute value for a `Float`: `v < 0.0 ? -v : v` means "if negative, flip the sign". It is used because the code needs the size of a difference regardless of direction.

| Stored latitude | New latitude | Difference | Result |
| --- | --- | --- | --- |
| none yet | 51.50 | not applicable | Stored (first fix) |
| 51.50 | 51.52 | 0.02 | Ignored, within 0.05 |
| 51.50 | 51.60 | 0.10 | Stored and saved as `"lat"`, `"lon"` |

The saved keys `"lat"` and `"lon"` are the ones `initialize` reads back, and it checks `instanceof Float` before trusting them. That check exists because saved data can be missing or of another type.

## The View, part 9: the sunrise and sunset glue code

The sun maths itself lives in `Astro.mc` (next section). The View only has to do four things: make sure it knows where the watch is, avoid recalculating when nothing changed, call the maths, and turn the answer into text. That is the last piece of `NotAWatchFaceDigitalView.mc`.

```
    // 4 + 5: recalculated only when the date, position or 12/24 h setting changes.
    private function updateSun(today as Gregorian.Info, is24 as Boolean, act as Activity.Info?) as Void {
        updateLocation(act);
        var lat = _lat;
        var lon = _lon;
        if (lat == null || lon == null) {
            _sunRiseStr = "--:--";
            _sunSetStr = "--:--";
            return;
        }
        var y = today.year as Number;
        var m = today.month as Number;
        var d = today.day as Number;
        var key = y.toString() + "-" + m.toString() + "-" + d.toString() + "|" +
                  (lat * 100).toNumber().toString() + "|" + (lon * 100).toNumber().toString() + "|" +
                  (is24 ? "24" : "12");
        if (key.equals(_sunKey)) {
            return;
        }
        _sunKey = key;
        var doy = Astro.dayOfYear(y, m, d);
        _sunRiseStr = sunString(y, m, d, Astro.sunEventUtcHours(doy, lat, lon, true), is24);
        _sunSetStr = sunString(y, m, d, Astro.sunEventUtcHours(doy, lat, lon, false), is24);
    }

    private function sunString(y as Number, m as Number, d as Number, utcHours as Float?, is24 as Boolean) as String {
        if (utcHours == null) {
            return "--:--";
        }
        var hm = Astro.utcHoursToLocal(y, m, d, utcHours);
        return formatTime(hm[0], hm[1], is24);
    }
}
```

### Where it is called from

`onUpdate` calls it first, at line 213, before anything is drawn: `updateSun(today, settings.is24Hour, act);`, and then the pressure and heading updates on lines 214–215. `today` is the date from `Gregorian.info(nowMoment, Time.FORMAT_SHORT)` (line 206), `is24` is the watch's 12/24-hour setting, and `act` is the one activity snapshot taken for this redraw.

### updateSun, step by step

1. **Refresh the position** with `updateLocation(act)` (part 8). After this, `_lat` and `_lon` hold the best known position, or are still `null`.
2. **Copy the two fields into locals** (`lat`, `lon`) and test the locals. The same style appears in `updateLocation` (`oldLat`, `oldLon`). Why the file does it this way is a Monkey C typing detail that has not been verified, so treat it as a pattern to copy.
3. **No position yet?** Both strings become `"--:--"` and the function returns. A brand-new install with no fix shows dashes until a position arrives.
4. **Build a cache key**, one text string describing every input that changes the answer: the date, the latitude and longitude times 100 (so about 0.01 degree resolution), and "24" or "12". It looks like `2026-11-3|5150|-12|24`, where the digits are illustrative; the exact digits depend on how `toNumber` treats decimals.
5. **Compare with the last key.** `key.equals(_sunKey)` compares the text of the two strings. If they are equal, nothing relevant changed and the function returns at once, leaving the strings from last time. That is the whole point of the cache: this function runs every redraw, but the sun maths runs only when needed.
6. **Otherwise store the new key** and calculate. `Astro.dayOfYear(y, m, d)` gives the day number (1–366), and `Astro.sunEventUtcHours(doy, lat, lon, true)` returns sunrise as "hours after 00:00 UTC", with `false` for sunset. Each is passed through `sunString`.

| What changes | Does the sun get recalculated? |
| --- | --- |
| Nothing (the usual case, every second) | No: the keys match, so it returns early |
| The date rolls over at midnight | Yes: the date part of the key changed |
| You move more than about 5 km | Yes: `updateLocation` replaced `_lat` or `_lon` and the key changed |
| The 12/24-hour setting is switched | Yes: the strings must be rewritten in the other format |

Remember that `updateLocation` only accepts a new position when it differs by more than 0.05 degrees, so small drifts in the GPS value never reach the key.

### sunString

`sunString` turns "hours after 00:00 UTC" into the text on the watch. If the maths returned `null` (the sun does not rise or set that day, or the latitude is beyond 89.5 degrees), it returns `"--:--"`. Otherwise `Astro.utcHoursToLocal` returns a two-item array `[hour, minute]` in the watch's local time, and `formatTime` (part 6) applies the 12/24-hour style to produce text like `06:57` or `6:57`.

The closing brace on the last line ends the class `NotAWatchFaceDigitalView`, which opened in part 1. That completes the 710-line View file.

## Astro.mc: the sun and moon maths (all 104 lines)

`Astro.mc` is a **module**: a named bag of functions and constants with no state of its own. The View calls its functions as `Astro.dayOfYear(...)`, `Astro.sunEventUtcHours(...)` and so on. It needs no sensors and no network: put numbers in, get numbers out. That also makes it the easiest file in the project to test on a laptop, and it is where the "clever" part of the face lives.

### Lines 1–12: imports and two constants

```
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Sun and moon calculations. Pure maths: no network, no phone, no sensors.
module Astro {

    // Reference new moon: 6 January 2000, 18:14 UTC, as Unix seconds.
    const NEW_MOON_EPOCH = 947182440;
    // Average length of a lunar cycle (new moon to new moon), in days.
    const SYNODIC_DAYS = 29.530588853;
```

- The four imports bring in the standard pieces used below: `Lang` (types), `Math` (sin, cos, floor…), `Time` (moments) and `Time.Gregorian` (calendar dates).
- `NEW_MOON_EPOCH` is a known new moon expressed as Unix seconds (seconds since 1 January 1970 UTC). Converting 947182440 back to a date gives **2000-01-06 18:14:00 UTC**, which matches the comment.
- `SYNODIC_DAYS` is the average time from one new moon to the next. Real cycles vary around this average, which is why the phase is approximate.

### fmod, the floating-point remainder (lines 14–17)

```
    // Floating-point modulo that always returns a value in [0, m).
    function fmod(x as Float, m as Float) as Float {
        return x - m * Math.floor(x / m);
    }
```

The `%` operator works on whole numbers. This helper does the same job for decimals and, because it uses `floor`, **never returns a negative result**. The comment `[0, m)` means "zero up to but not including `m`".

| Call | Steps | Result |
| --- | --- | --- |
| `fmod(370.0, 360.0)` | `370 - 360 * floor(1.03)` = `370 - 360 * 1` | `10.0` |
| `fmod(-90.0, 360.0)` | `-90 - 360 * floor(-0.25)` = `-90 - 360 * (-1)` | `270.0` |

Almost every other function here ends by wrapping an angle or a time with `fmod`.

### Degree-based trigonometry (lines 19–29)

```
    function sinD(deg as Float) as Float {
        return Math.sin(Math.toRadians(deg));
    }

    function cosD(deg as Float) as Float {
        return Math.cos(Math.toRadians(deg));
    }

    function tanD(deg as Float) as Float {
        return Math.tan(Math.toRadians(deg));
    }
```

The built-in `Math.sin`, `Math.cos` and `Math.tan` expect **radians**, but the almanac formulas are written in **degrees**. These three wrappers convert first, so the formulas below can be typed as they appear in the book.

### moonPhase (lines 31–38)

```
    // Moon phase as a fraction of the cycle:
    // 0 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter.
    // Uses the average cycle length, so it can be off by up to about a day
    // (checked against an independent calculation); fine for a phase picture.
    function moonPhase(unixSeconds as Number) as Float {
        var days = (unixSeconds - NEW_MOON_EPOCH) / 86400.0;
        return fmod(days, SYNODIC_DAYS) / SYNODIC_DAYS;
    }
```

Three lines of real work:

1. `unixSeconds - NEW_MOON_EPOCH` is how long since the reference new moon, in seconds. Dividing by `86400.0` (seconds in a day) gives **days**.
2. `fmod(days, SYNODIC_DAYS)` throws away whole cycles and keeps how far into the current one we are, in days.
3. Dividing by `SYNODIC_DAYS` turns that into a **fraction from 0 up to just under 1**.

*Worked example.* For 3 November 2026 at 12:00 UTC the days since the epoch are 9797.74. After removing whole cycles and dividing, the phase is **0.783**. That is past last quarter (0.75) and before the next new moon (1.0), so the moon is a waning crescent. The picture code from part 5 turns that number into the lit shape. The comment on the function admits a possible error of up to about a day; the QA record at the end of this guide gives the measured worst case.

### dayOfYear (lines 40–46)

```
    // Day of the year (1-366) for a calendar date.
    function dayOfYear(year as Number, month as Number, day as Number) as Number {
        var n1 = (275 * month) / 9;
        var n2 = (month + 9) / 12;
        var n3 = 1 + (year - 4 * (year / 4) + 2) / 3;
        return n1 - (n2 * n3) + day - 30;
    }
```

This is a compact calendar trick that avoids a table of month lengths. It relies on whole-number division, which drops the remainder (a language rule that has not been re-verified against Garmin's pages).

- `n1` = `(275 * month) / 9` approximates the days before this month, as if every month had 30.5 days.
- `n2` is 0 for January and February, and 1 from March onwards.
- `n3` is 1 for years divisible by 4 and 2 otherwise, because `year - 4 * (year / 4)` is `year % 4`. It is a leap-year correction: the leap day is only counted from March.

| Date | n1 | n2 | n3 | Result |
| --- | --- | --- | --- | --- |
| 3 Nov 2026 | 336 | 1 | 2 | 336 - 2 + 3 - 30 = **307** |
| 29 Feb 2024 | 61 | 0 | 1 | 61 - 0 + 29 - 30 = **60** |
| 1 Mar 2024 | 91 | 1 | 1 | 91 - 1 + 1 - 30 = **61** |

Re-running this formula in Python against the real calendar for every day of 2023 to 2028 gives **no mismatches**. One limit: the test is only "divisible by 4", so it treats 2100, which is not a leap year, as one. That has no effect until 2100.

### sunEventUtcHours, the main event (lines 48–91)

This function answers: *on day `doy`, at this latitude and longitude, at what time does the sun rise (or set)?* The time comes back as hours after 00:00 UTC, or `null` when the sun does not rise or set. The comment block explains the output and the source.

```
    // Sunrise (rising = true) or sunset, as hours after 00:00 UTC on the
    // given calendar date. The result can be below 0 or above 24 for places
    // far from Greenwich; that is intended. Returns null when the sun does
    // not rise or set that day (polar day or night).
    //
    // Method: the "Sunrise/Sunset Algorithm" from the Almanac for Computers
    // (Nautical Almanac Office, US Naval Observatory, 1990). Accurate to
    // within a couple of minutes.
    function sunEventUtcHours(doy as Number, lat as Float, lon as Float, rising as Boolean) as Float? {
        if (lat > 89.5 || lat < -89.5) {
            return null;
        }
        var zenith = 90.833;   // official sunrise/sunset, includes refraction
        var lngHour = lon / 15.0;
        var t = doy + ((rising ? 6.0 : 18.0) - lngHour) / 24.0;
```

- The return type `Float?` means "a decimal number or `null`".
- **Guard:** beyond 89.5 degrees of latitude the formula is not trusted, so the function returns `null`.
- `zenith = 90.833` is the angle of the sun's centre from straight overhead at the moment of official sunrise or sunset: 90 degrees (the horizon) plus about 50 arc-minutes for atmospheric refraction and the sun's own radius.
- `lngHour = lon / 15.0` converts longitude into hours, because the Earth turns 15 degrees per hour.
- `t` is an approximate moment, as a fractional day number: the day itself plus the guess that sunrise is near 6:00 and sunset near 18:00, shifted by the longitude. The remaining steps refine this guess.

```
        // Sun's mean anomaly and true longitude
        var m = 0.9856 * t - 3.289;
        var l = fmod(m + 1.916 * sinD(m) + 0.020 * sinD(2.0 * m) + 282.634, 360.0);
```

- `m` is the **mean anomaly**: how far round its orbit the Earth is, treating the orbit as a circle. It grows by 0.9856 degrees a day.
- `l` is the sun's **true longitude** along the ecliptic. The two sine terms correct the circle into the real, slightly oval orbit, and `282.634` is a fixed offset. `fmod` wraps the answer into 0–360.

```
        // Right ascension, moved into the same quadrant as l, in hours
        var ra = fmod(Math.toDegrees(Math.atan(0.91764 * tanD(l))), 360.0);
        var lQuadrant = Math.floor(l / 90.0) * 90.0;
        var raQuadrant = Math.floor(ra / 90.0) * 90.0;
        ra = (ra + (lQuadrant - raQuadrant)) / 15.0;
```

- **Right ascension** is the sun's position measured along the equator. `atan` can only answer between -90 and +90 degrees, so the answer can land in the wrong quarter of the circle.
- The two `floor(... / 90.0) * 90.0` lines find which 90-degree quadrant `l` and `ra` sit in, and the next line shifts `ra` by the difference so both agree. Dividing by 15 turns degrees into hours.

```
        // Declination
        var sinDec = 0.39782 * sinD(l);
        var cosDec = Math.cos(Math.asin(sinDec));
```

**Declination** is how far north or south of the equator the sun is overhead: positive in northern summer, negative in winter. The constant 0.39782 is approximately the sine of the Earth's axial tilt (about 23.44 degrees, and sin 23.44 degrees is about 0.3978).

```
        // Local hour angle
        var cosH = (cosD(zenith) - sinDec * sinD(lat)) / (cosDec * cosD(lat));
        if (cosH > 1.0 || cosH < -1.0) {
            return null;
        }
        var hDeg = Math.toDegrees(Math.acos(cosH));
        if (rising) {
            hDeg = 360.0 - hDeg;
        }
```

- `cosH` is the cosine of the **hour angle**, the sun's angle from due south, at the instant it crosses the horizon line (the `zenith` angle above).
- A cosine can only lie between -1 and 1. If `cosH` is outside that range the sun never reaches that altitude on this day: polar day or polar night. The function returns `null`, and the View shows `--:--`.
- `acos` gives the angle. For **sunrise** the angle is measured on the morning side, so it becomes `360 - hDeg`. For sunset it is used as is.

```
        // Local mean time of the event, then back to UTC
        var localMean = fmod(hDeg / 15.0 + ra - 0.06571 * t - 6.622, 24.0);
        return localMean - lngHour;
    }
```

- `hDeg / 15.0` is the hour angle in hours. Adding `ra` and subtracting `0.06571 * t` and `6.622` converts it to the **local mean time** of the event, wrapped into 0–24.
- Subtracting `lngHour` converts local mean time to **UTC**. For a place east of Greenwich `lngHour` is positive, so the result can drop below 0; far west it can pass 24. That is the "intended" behaviour the comment mentions, and the next function copes with it.

The constants (0.9856, 3.289, 1.916, 0.020, 282.634, 0.91764, 0.39782, 0.06571, 6.622) come from the published almanac method named in the comment. They were not re-derived. The page that publishes the method states no usage terms, which matters if you reuse the code (see "Reusing the sun code" in the Sources section).

#### A full worked example: London on 3 November 2026

These numbers come from a Python port of the same formulas (latitude 51.5074, longitude -0.1278, `doy` = 307, sunrise). The port was run to follow the logic; it is not output from the watch.

| Step | Quantity | Value |
| --- | --- | --- |
| 1 | `lngHour` = lon / 15 | -0.0085 |
| 2 | `t` = 307 + (6 - lngHour) / 24 | 307.2504 |
| 3 | `m` | 299.537 degrees |
| 4 | `l` | 220.487 degrees |
| 5 | `ra` after the quadrant fix, in hours | 14.538 |
| 6 | `sinDec` | -0.2583 (the sun is south of the equator in November) |
| 7 | `cosH` | 0.3120, inside the range -1 to 1, so the sun rises |
| 8 | `hDeg` after `360 - acos(cosH)` | 288.18 degrees |
| 9 | `localMean` | 6.939 hours |
| 10 | Return value (UTC hours) | **6.9475**, which is 06:56:51 UTC |

**Cross-check.** The port was compared with the independent Python library `astral` for the same date at three places:

| Place | Event | Port | `astral` | Difference |
| --- | --- | --- | --- | --- |
| London | sunrise | 06:56:51 | 06:57:42 | -51 s |
| London | sunset | 16:30:31 | 16:29:37 | +54 s |
| Mumbai | sunrise | 01:09:34 | 01:09:48 | -14 s |
| Mumbai | sunset | 12:34:24 | 12:33:58 | +26 s |
| Delhi | sunrise | 01:04:12 | 01:04:33 | -21 s |
| Delhi | sunset | 12:04:59 | 12:04:27 | +32 s |

All six are under a minute. That is one date and three cities, a spot check of the maths rather than a proof, and it checks the port of the formulas, not the Monkey C file itself. The QA record later in this guide gives the project's own, wider comparison.

### utcHoursToLocal (lines 93–104)

```
    // Turns "hours after 00:00 UTC on this date" into the watch's local
    // [hour, minute]. The watch applies its own time zone and daylight saving.
    function utcHoursToLocal(year as Number, month as Number, day as Number, utcHours as Float) as Array<Number> {
        var midnightUtc = Gregorian.moment({
            :year => year, :month => month, :day => day,
            :hour => 0, :minute => 0, :second => 0
        });
        var secs = midnightUtc.value() + (utcHours * 3600.0).toNumber();
        var local = Gregorian.info(new Time.Moment(secs), Time.FORMAT_SHORT);
        return [local.hour as Number, local.min as Number];
    }
}
```

1. `Gregorian.moment({...})` builds a point in time for midnight on the given date from a dictionary of named fields.
2. `.value()` is that moment as whole seconds. Adding `utcHours * 3600.0` (hours to seconds, then `.toNumber()` to drop the decimals) lands on the sunrise instant. **Because it is plain addition, a negative or an over-24 `utcHours` works without special handling.**
3. `new Time.Moment(secs)` makes a moment from those seconds, and `Gregorian.info(..., Time.FORMAT_SHORT)` splits it into calendar fields.
4. The function returns an array of two numbers: `[local.hour, local.min]`.

The code relies on `Gregorian.moment` reading the fields as UTC and `Gregorian.info` returning the watch's own local time, which is what the author's comment says ("the watch applies its own time zone and daylight saving"). Those two behaviours were not checked in Garmin's documentation, so confirm them before relying on this elsewhere. The last `}` closes the module.

| Example | UTC hours | Result `[hour, minute]` |
| --- | --- | --- |
| London, watch on UTC | 6.9475 | `[6, 56]`: 25,011 s after midnight, seconds dropped |
| Mumbai, watch on UTC+5:30 | 1.1594 | `[6, 39]`: 01:09:34 UTC plus 5 h 30 min |

The minutes are cut off, not rounded, so a sunrise at 06:56:51 shows as `6:56`. (Values from the Python port, using the stated offsets.)

## Cheat sheet: units, formulas, fallbacks and caches

Everything below is already explained in the parts above. This page gathers it in one place so you can look something up without re-reading a section. Line numbers refer to `NotAWatchFaceDigitalView.mc` unless stated.

### Where each value comes from

The numbers in the first column are the slot numbers used in the source comments. Each reader tries its sources in order and ends with a dash placeholder, so a missing sensor does not stop the face from drawing.

| Slot | Shows | Tries, in order | Placeholder |
| --- | --- | --- | --- |
| 1 | Date | `Gregorian.info` with `DAY_NAMES` and `MONTH_NAMES` (weekday dropped if too wide) | none |
| 2 | Your text | `LABEL_TEXT` from `Settings.mc` (shortened to fit) | none |
| 3 | Time | `formatTime` using the 12/24-hour setting | none |
| 4 and 5 | Sunrise, sunset | `updateSun`, which uses `Astro.mc` and the saved position | `--:--` |
| 6 | Heart rate | `currentHeartRate`, then the newest history sample | `--` |
| 7 | Steps | `ActivityMonitor.getInfo().steps` | `--` |
| 8 | Distance | `ActivityMonitor.getInfo().distance` | `--` |
| 9 | Altitude | the activity altitude, then elevation history | `--` |
| 10 | Compass heading | the live heading, else the last remembered value | `---` |
| 11 | Pressure and trend arrow | sea-level pressure, then ambient pressure, then newest history value | `--` |

The moon picture is drawn separately inside the round subscreen by `drawMoon`.

### Unit conversions used in the code

| From | To | Operation | Where |
| --- | --- | --- | --- |
| Centimetres | Kilometres | divide by 100000.0 | `distanceText` |
| Centimetres | Miles | divide by 160934.4 | `distanceText` |
| Metres | Feet | multiply by 3.28084 | `altitudeString` |
| Pascals | Hectopascals | divide by 100.0 | `hpaString`, `updatePressure` |
| Radians | Degrees | `Math.toDegrees(h)` | `updateHeading` |
| Degrees | Hours (of longitude or angle) | divide by 15.0 | `Astro.mc` |
| Hours | Seconds | multiply by 3600.0 | `Astro.utcHoursToLocal` |
| Seconds | Days | divide by 86400.0 | `Astro.moonPhase` |

### Throttles and caches

Most of the speed and battery thinking in this face is the same trick: remember an answer, and only redo the work when its inputs change or enough time has passed.

| Work | Redone when | Remembered in |
| --- | --- | --- |
| Sunrise and sunset | the cache key changes: date, position (about 0.01 degree) or 12/24-hour setting | `_sunKey`, `_sunRiseStr`, `_sunSetStr` |
| Pressure trend | at least 600 seconds since the last run | `_pressCheckedAt`, `_pressTrend`, `_pressHistoryNewest` |
| Saving the heading | the value changed and at least 60 seconds since the last save | `_headingDirty`, `_headingSavedAt` |
| Position | the new fix differs from the stored one by more than 0.05 degrees | `_lat`, `_lon` (and saved to storage) |
| Layout and fonts | in `onLayout`, which the project comments describe as running once | the `_...X`, `_...Y` and `_...Font` fields |

### The formulas, in one line each

| Idea | Formula or rule | Part |
| --- | --- | --- |
| 12-hour clock | `h12 = hour % 12`, and 0 becomes 12 | 6 |
| Wrapping into a range | `fmod(x, m) = x - m * floor(x / m)` | Astro |
| Moon phase | `days = (unixSeconds - 947182440) / 86400.0`, `phase = fmod(days, 29.530588853) / 29.530588853` | Astro |
| Moon picture | `r` = 62 percent of the subscreen radius; `c = cos(2 * pi * phase)`; for each row, `half = sqrt(r*r - yy*yy)`; waxing (`phase < 0.5`) lights from `half * c` to `half`; waning lights from `-half` to `-half * c` | 5 |
| Day of year | `(275*month)/9 - ((month+9)/12) * n3 + day - 30`, with `n3` = 1 in leap years and 2 otherwise | Astro |
| Sunrise or sunset | `t`, `m`, `l`, `ra`, `sinDec`, `cosH`, `hDeg`, `localMean`, then subtract `lngHour` (the ten steps of the worked example) | Astro |
| Heading rounding | `rounded = (deg + 0.5).toNumber() % 360` | 8 |
| Pressure trend | `deltaHpa = (newest - older) / 100.0`; rising at 1.0 or more, falling at -1.0 or less, otherwise steady | 7 |
| Distance display | below 100: one decimal; otherwise a whole number | 6 |
| Font choice | try the largest first; keep the first that fits the width test and the height budget | 2 and 4 |

### How the fonts get chosen

From `onLayout` (lines 166–181): the time font is tried from the largest candidate to the smallest (`FONT_NUMBER_HOT`, `FONT_NUMBER_MEDIUM`, `FONT_NUMBER_MILD`, `FONT_LARGE`, `FONT_MEDIUM`, `FONT_SMALL`) and the row font from `FONT_SMALL` down to `FONT_XTINY`. A combination is accepted when the text `"00:00"` fits within the width minus 10 pixels and the total stacked height is at or under `bottomLimit`, which is the screen height minus 12 pixels (line 163). The first combination that passes wins.

From `rowFont` (lines 314–331): for each text, `need = 12 + text width + 6 (only for a heading with its degree mark)`. The candidate is rejected when any `need` is larger than the column width, and the function falls back to `FONT_XTINY`.

### Placeholders at a glance

| Text | Meaning |
| --- | --- |
| `--` | the value exists on this watch but no reading is available |
| `---` | the compass has never produced a reading (and nothing was saved) |
| `--:--` | no position yet, or the sun does not rise or set that day |
| circle in the pressure icon | not enough history yet for an arrow |

### Monkey C reminders

The first group is how this project's own code behaves. The second group are language rules stated from general knowledge of the language; Garmin's Monkey C pages could not be loaded to re-check them, so test anything important in the simulator.

- **From this code:** locals are declared with a bare `var`; the compiler rejected six typed local declarations in an earlier Digital version (recorded in the QA notes). Parameters and return types do carry types (`as Number`, `as Float?`).
- **From this code:** `Type?` means "or null"; `x has :name` tests that an object or module offers a feature; `value instanceof Number` tests a type at run time; `try { } catch (e) { }` guards storage writes.
- **Language rules (not re-verified):** `/` on two whole numbers drops the remainder; symbols such as `:period` are written with a leading colon and used as dictionary keys with `=>`; `as` is a type annotation or cast and does not convert a value.

## Build, test and install: the whole loop

Coding is half the job. The other half is the loop you will repeat dozens of times: **edit, build, test in the simulator, copy to the watch, select the face**. This section follows the project's `INSTALL.md` and the commands used on the author's Mac. Where the guide cites Garmin's developer forum, that is community experience and not official Garmin guidance, and it is marked that way.

### 1. Tools you install once

| Tool | Why |
| --- | --- |
| Visual Studio Code | The editor |
| Garmin's **Monkey C** extension (published by Garmin) | Syntax colours, build and run commands |
| Garmin's **Connect IQ SDK Manager** | Downloads the SDK (the compiler and simulator) and the device file |
| The **Instinct 2** device file | Provides the build target `instinct2`, the watch's 176 x 176 two-colour screen |
| Java 17 or newer | The compiler is a Java program; the extension must find a `java` command |

After installing, run **Monkey C: Verify Installation** from the command palette (Cmd+Shift+P on a Mac, Ctrl+Shift+P on Windows). `INSTALL.md` has three ways to fix a "Java path not set" message on a Mac. Their common idea is to point macOS at a Java that is already inside another installed app, or to install a small Temurin JRE.

### 2. The developer key

Every file you build is **signed** with a private key you create once. Rebuilding with a different key later is a signature mismatch: the guide reports, from Garmin's forum, "Signature check failed" errors and faces being removed. So:

- Create it with **Monkey C: Generate a Developer Key**, or with the two `openssl` commands in `INSTALL.md`.
- Keep it **outside both project folders** and back it up.
- **Never commit it to Git or share it.** Anyone holding the key can sign files as you.

### 3. Build

Two routes give the same result: a `.prg` file, the program the watch runs.

1. **Editor route:** open the folder that contains `manifest.xml`, run **Monkey C: Build for Device**, choose `instinct2`, an output folder and your key.
2. **Terminal route**, run inside the project folder. This is the shape of the compiler call used on this project; the SDK folder name ends in a build identifier, so look in your SDK folder for the exact path:

```
java -jar "<SDK folder>/bin/monkeybrains.jar" -f monkey.jungle -d instinct2 -y "<your developer key>" -o NotAWatchFaceDigital.prg
```

The flags: `-f` names the jungle file, `-d` the device, `-y` the signing key and `-o` the output file. The SDK used for this project was version 9.3.0. If the build stops, the error text names the file and the line number. **Copy it whole before changing anything.** That is how the six typed-local errors in Digital 1.0.2 were found and fixed.

There is also a `.iq` file, produced by an export for the Connect IQ Store. The watch wants the `.prg`; the store wants the `.iq`. Never put the other kind on the watch, and never copy a build from the simulator's own `bin` folder.

### 4. Test in the simulator before the watch

Run **Monkey C: Run**, choose `instinct2`, and use the simulator's **Simulation** menu to feed in heart rate, altitude, heading and so on. Keep the debug console open: a crash shows in red. The project's checklist for the Digital face:

- Nothing overlaps, and your label is fully visible.
- The six bottom fields show values, or `--` where there is no data.
- The bottom-left and bottom-right values are not clipped by the screen's cut corners.
- No red errors in the debug console.

The QA record says the layout checks so far came from a model with stand-in fonts, not from Garmin's simulator, which is why this step matters.

### 5. Copy to the watch

The watch must be connected by its cable, and Garmin Express closed (the guide reports, from the forum, that the two cannot share the connection). On the author's Mac, the watch in data mode appears as a normal drive named `GARMIN`. Other Macs may use a different connection mode and need a helper tool such as OpenMTP, which the guide mentions.

This script copies the face and then proves the copy is identical:

```
WATCH="/Volumes/GARMIN/GARMIN/APPS"
[ -d "$WATCH" ] || { echo "Watch not found"; exit 1; }
cp -X NotAWatchFaceDigital.prg "$WATCH/"
rm -f "$WATCH/._NotAWatchFaceDigital.prg"
shasum NotAWatchFaceDigital.prg "$WATCH/NotAWatchFaceDigital.prg"
diskutil eject /Volumes/GARMIN
```

- Line 2 stops if the watch is not mounted, so nothing is written to the wrong place.
- `cp -X` copies without macOS's extended attributes, which would otherwise create a stray `._` helper file on the watch. Line 4 removes any that still appear, by exact name.
- `shasum` prints a fingerprint of each file. **If the two fingerprints are identical, the copy is perfect.**
- `diskutil eject` unmounts the watch safely. Unplug only after it finishes.
- Only your own `.prg` is added. Nothing else in `APPS` is moved, renamed or deleted.

The guide notes that the file may vanish from `APPS` after you unplug, because the watch takes it into its internal storage (a forum report, not Garmin guidance). That is normal.

### 6. Select, update or undo

- **Select:** on the watch, hold MENU, choose **Watch Face**, scroll to the face and select it.
- **Update:** rebuild with the same key and copy again. The app `id` in `manifest.xml` is unchanged, so the new file replaces the old one. If you want to tell the versions apart, change `version` in the manifest (this face is currently `1.0.3`).
- **Undo:** hold MENU, choose **Watch Face**, pick any Garmin face. The guide says this returns the watch to how it was.
- **Remove completely:** switch to another face first, then uninstall it from the Connect IQ app on your phone or from Garmin Express. Deleting the file from `APPS` does not remove it, because the watch has already moved it.

### 7. Changing your own text: the one-line edit

The text under the date comes from the 8-line `Settings.mc` (see the Settings section earlier).

1. Open `source/Settings.mc`.
2. Change only the text between the quotes in `const LABEL_TEXT = "...";`. Use plain letters, numbers and basic symbols.
3. Save, build, test in the simulator, copy to the watch.

Anything wider than the space left of the round subscreen is cut off. In `onLayout` (part 2) the face first drops from `FONT_TINY` to `FONT_XTINY`, and if the text is still too wide it removes characters from the end until it fits. The guide says the space holds about ten characters; that has not been measured.

Other preferences need **no rebuild**, because the face reads them from the watch: 12 or 24-hour time (sunrise and sunset follow it too), kilometres or miles, and metres or feet.

### 8. When something goes wrong

| You see | Likely cause (from the project guide) | What to do |
| --- | --- | --- |
| Face missing from the Watch Face list | Wrong device, Garmin Express open during the copy, or a key problem | Rebuild for `instinct2` with your saved key, close Garmin Express, copy again |
| Error icon instead of the face | The face crashed on the watch | Switch to another face, run it in the simulator, read the red text in the console |
| Sunrise and sunset show `--:--` | The watch has no position yet; a watch face cannot switch the GPS on itself | Do a short outdoor GPS activity; the face saves the position |
| Pressure arrow is a small circle | Under 2.5 hours of barometer history | Wait a few hours |
| Compass shows `---` | No heading reading yet | Open the watch's own compass, then return to the face |
| Compass never fills in | Garmin does not document this behaviour on watch faces | Swap field 10 for another value in the View file and rebuild |

The last two rows match the cautions in part 8: the compass behaviour is the part of this face that depends most on something Garmin does not document.

## The QA record: how this face was checked

A watch face is hard to test: it needs sensors, a tiny screen and a compiler that only runs on your machine. The project handled that with a written **QA report** (`QA-REPORT.md`, dated 30 October 2026). Reading it is a lesson in its own right, so this section summarises the Digital parts of it, then adds the checks made while this guide was written, and ends with what could not be checked.

### What the report says about status

The report calls the release "ready for simulator verification". Digital 1.0.2 failed Garmin's compiler with six errors, all one rule (typed local variables), and 1.0.3 fixed them. The report records that 1.0.3 was rebuilt on 1 November 2026 and copied to the watch, and that the compiler output was not recorded. Simulator results are not recorded either, so the simulator checklist in `INSTALL.md` is still open.

### Requirements traceability

Every wish is given an ID, tied to the code that implements it, and given a status. If a requirement has no code, or code has no requirement, the table shows it.

| ID | Requirement | Implemented in |
| --- | --- | --- |
| D1 | Slot 1: day and date | `onUpdate` |
| D2 | Slot 2: text only | `Settings.mc` |
| D3 | Slot 3: moon phase in the subscreen | `drawMoon`, `Astro.moonPhase` |
| D4-5 | Sunrise and sunset under the time | `updateSun`, `drawSunLine` |
| D6-8 | Heart rate, steps, distance | Row A |
| D9-11 | Altitude, last compass reading, pressure trend | Row B |
| D12 | No battery percentage; corner brackets; large time | The View |
| D13 | Project named `NotAWatchFaceDigital` | Folder, app name, entry class |
| W1 | Built for the Instinct 2 Solar Tactical | Manifest product `instinct2` |

The report marks each of these "Pass".

### The test summary, with the idea behind each test

| Test | What was done | Result in the report | Idea to steal |
| --- | --- | --- | --- |
| Static checks | Every called function, member variable and constant is defined; brackets balance; no local variable carries a declared type; all XML parses | Pass | Cheap checks that run in seconds and catch typos before the compiler does |
| Sun maths | Sunrise and sunset compared with the independent library `astral` 3.2 in 64 cases: 8 cities from the equator to 64 degrees north, 4 dates including both solstices | Worst difference 2.8 minutes | Test your maths against someone else's implementation |
| Time zones | Sunrise and sunset land on the right local day in 6 zones, UTC-10 to UTC+13, with and without daylight saving | Pass | Test the edges where the date line and midnight bite |
| Moon maths | Phase compared weekly for one year against the same library | Worst difference 0.81 days | State your accuracy honestly |
| Digital layout | 8 scenarios times 3 times: normal, wide values, missing data, 12-hour, long label, empty label, widest date, negative altitude. Checked for overlaps, margins, clearance from the subscreen, and each value inside its column | Pass | Try the ugly inputs, not only the typical one |
| Test strength | 3 deliberate faults injected (label overflow, columns at the screen edge, numerals pulled in needlessly); each was caught | Pass | Break your code on purpose to prove the tests can fail |
| Garmin compiler | Digital 1.0.2 built for `instinct2` | 6 errors, "Invalid explicit typing of a local variable"; fixed in 1.0.3 | The real compiler is the final judge |
| Garmin compiler | Digital 1.0.3 rebuilt for `instinct2` on 1 November 2026 | Built and copied to the watch; compiler output not recorded | Keep the compiler output with the report |

The report totals 16,486 layout checks with no failures. Its own **limits** paragraph is worth copying into your projects: the layout model uses stand-in fonts of similar size, its subscreen position was taken from a working Instinct 2 face, and it is not Garmin's simulator, so the simulator checklist remains necessary.

### Defects found and fixed (Digital)

| # | Defect | Fix | Release |
| --- | --- | --- | --- |
| 2 | A long value dropped one cell to a smaller font, so a row could mix text sizes | One font per row (`rowFont`, part 4) | 1.0.1 |
| 3 | Bottom-corner values and brackets too close to the screen's cut corners | Columns moved in, bottom margin raised, brackets inset | 1.0.1 |
| 4 | Bottom brackets' upright arms crowded the bottom row | Short corner ticks below the row | 1.0.1 |
| 5 | The date line had no width guard next to the subscreen | The weekday is dropped if the date would touch the subscreen (`onUpdate`, lines 228–231) | 1.0.1 |
| 6 | Sensor data was read five times per redraw | Read once per redraw and shared (`var act = Activity.getActivityInfo();`, line 211) | 1.0.1 |
| 7 | The manifest used the older `minSdkVersion` attribute | `minApiLevel` | 1.0.1 |
| 9 | Launcher icons were 40 x 40; the compiler reports the Instinct 2 expects 62 x 62 | Icons redrawn at 62 x 62 | 1.0.2 |
| 10 | Six local variables were declared with a type, which the compiler rejects: "Local variable types are inferred" | Rewritten with early returns and plain locals; the static check now fails on any typed local | 1.0.3 |

Number 6 is a nice pattern to remember: take **one snapshot** of changing data at the top of the redraw and pass it around, so every field shows the same instant and the sensors are asked once.

### Known limitations (from the report)

| Item | Impact | Plan |
| --- | --- | --- |
| Simulator results not recorded | Layout in Garmin's simulator is unconfirmed; the layout checks use a model with stand-in fonts | Run the checklist in `INSTALL.md` and record the results |
| Screen's cut corners | Bottom-corner values or brackets could be clipped | Check in the simulator |
| Compass on a watch face | Garmin does not document it; the field may stay `---` | If it never fills in, swap field 10 |
| Always-on ticking seconds | Not included; needs testing against Garmin's power limit | Possible later |
| Moon phase | Within about 1 day; northern-hemisphere orientation | By design |
| Pressure trend | Needs 2.5 hours of history after a restart; altitude changes affect it | By design |

### What was checked while this guide was written

- **Every code block** in this guide was compared, line by line, with the source files in this repository. A block that is a command or a folder tree is not source code and is excluded.
- **`Settings.mc` is 8 lines**, counted from the file itself.
- **`Astro.dayOfYear`** was re-run in Python for every day of 2023 to 2028 and matched the calendar every time (the script is in the Exercises).
- **`Astro.sunEventUtcHours`** was ported to Python and compared with `astral` for three cities on 3 November 2026: all six differences were under a minute (see the Astro section).
- **`NEW_MOON_EPOCH`** converts back to 2000-01-06 18:14:00 UTC, as its comment says.

### What could not be checked

- **Monkey C language rules** (integer division, `has`, `instanceof`, `as`, typed locals): Garmin's language pages would not load while the guide was written. They are marked "language rule" where used.
- **Garmin API behaviours** such as `Gregorian.moment` treating its fields as UTC, the sensor history fields and the compass heading: described as the code and its comments describe them, not confirmed in Garmin's documentation here.
- **How the face looks and behaves on the watch or in the simulator.** The face was not run in either as part of writing this guide.
- **Battery use** of the face: nothing in the QA report measures it.

## Exercises

Try each one before you open the answer under it. Exercises 1 to 4 are "read and predict", 5 to 8 change the code, and 9 to 11 are bigger projects. Always build and run in the simulator before you copy anything to the watch.

### Read and predict

**1. Heading rounding.** Using `updateHeading` (part 8), what number is stored for each reading below? Assume `.toNumber()` drops the decimals, as the code's design requires.

| Reading (radians) | Stored value |
| --- | --- |
| 0.0 | ? |
| 4.7124 | ? |
| 6.2832 | ? |

*Answer:* **0.0** is not stored at all, because `h != 0.0` fails. **4.7124** is about 270.0006 degrees, plus 0.5 gives 270.5006, which drops to **270**. **6.2832** is about 360.0008 degrees; `fmod` brings it to 0.0008, plus 0.5 drops to 0, so the stored value is **0**.

**2. Pressure arrow.** Using `updatePressure` (part 7), which trend results for each change in hPa over the window, assuming enough history exists: -1.0, -0.99, 0.99, 1.0, 2.5?

*Answer:* falling, steady, steady, rising, rising. The rules are `>= 1.0` for rising and `<= -1.0` for falling.

**3. The sun cache.** Using `updateSun` (part 9) and `updateLocation` (part 8), which of these makes the sun times recalculate? (a) one second passes; (b) you walk 100 metres; (c) you travel 10 km; (d) you switch the watch to 12-hour time; (e) midnight passes.

*Answer:* (a) no, the key is unchanged. (b) no, because a move under 0.05 degrees is ignored by `updateLocation`. (c) yes in most directions, because 10 km is about 0.09 degrees of latitude, which is more than 0.05. (d) yes, because "12" or "24" is part of the key. (e) yes, because the date is part of the key.

**4. Your own text.** Change `LABEL_TEXT` in `Settings.mc` to a 20-character string, build and run it in the simulator. What do you see? Then explain what `onLayout` did, using the font drop and the shortening loop from part 2.

### Change the code

**5. A six-hour pressure window.** Make the trend compare the newest reading with one about six hours old. Which numbers in `updatePressure` must change together, and what else needs updating?

*Hint:* the four-hour request is too short for a six-hour comparison, the `3 * 3600` stop test, and the `9000` minimum. Comments must also match.

*Answer:* make the requested period longer than six hours (for example `7 * 3600`), change `3 * 3600` to `6 * 3600`, and change the minimum from `9000` (2.5 hours) to a similar proportion of six hours, such as `19800` (5.5 hours). Update the comments, and the troubleshooting text that says "2.5 hours".

**6. A southern-hemisphere moon.** In the southern hemisphere the lit part of a waxing moon is on the left. Change `drawMoon` (part 5) so the picture is mirrored.

*Answer:* the simplest change is to flip the test on line 418 from `phase < 0.5` to `phase >= 0.5`. The two branches swap roles, so a waxing moon is lit from `-half` to `-half * c` on the left. At full moon `c` is -1 and both versions fill the whole row, so nothing breaks. Check new moon and full moon in the simulator.

**7. Show AM and PM on sunrise and sunset.** In 12-hour mode the times have no suffix. Add a short `a` or `p` after the sunrise and sunset only.

*Hint:* `formatTime` is also used for the main clock, so change `sunString` instead. The sunrise and sunset line is centred using measured widths in `drawSunLine`, so check that the longer text still fits.

**8. Check `dayOfYear` yourself.** Run this Python script, which uses the same three lines of arithmetic as `Astro.dayOfYear`, and compare it with the real calendar:

```
import datetime

def doy(y, m, d):
    n1 = (275 * m) // 9
    n2 = (m + 9) // 12
    n3 = 1 + (y - 4 * (y // 4) + 2) // 3
    return n1 - n2 * n3 + d - 30

bad = []
day = datetime.date(2023, 1, 1)
while day.year <= 2028:
    if doy(day.year, day.month, day.day) != day.timetuple().tm_yday:
        bad.append(day)
    day += datetime.timedelta(days=1)
print("mismatches:", bad)
print("2100-03-01:", doy(2100, 3, 1), "calendar:", datetime.date(2100, 3, 1).timetuple().tm_yday)
```

*Answer (when it was run):* `mismatches: []`, and for 1 March 2100 the formula gives 61 while the calendar says 60. The formula treats 2100 as a leap year. Can you change `n3` so it would handle that? (Python's `//` is whole-number division, like `/` between two Numbers in Monkey C, a language rule that was not re-verified.)

### Bigger projects

**9. Polar edge cases.** Port `sunEventUtcHours` to Python (the worked example in the Astro section lists every step) and test Tromso, Norway (latitude 69.65, longitude 18.96) on 21 December and 21 June 2026.

*Answer (from the Python port):* `cosH` is about **1.123** on 21 December, above 1, so the sun never rises and the function returns `null` (the face shows `--:--`). On 21 June it is about **-1.215**, below -1, so the sun never sets: also `null`. London on the same days gives 0.520 and -0.571, both inside the range, so there is a sunrise.

**10. Replace a field.** Swap the compass (slot 10) for another reading the watch offers. Write a reader function with the ladder-and-placeholder pattern from part 6, add an icon id and drawing branch (part 4), pass it to `drawCell` in `onUpdate`, and check the width test in `rowFont`. Look up the exact field names in Garmin's API reference, since no new ones were verified here. Test with the value missing, to see the placeholder.

**11. Reproduce the moon QA number.** The QA report says the moon phase differs from `astral` by at most 0.81 days when compared weekly for a year. Port `moonPhase` to Python, compare it with the library's phase for every seventh day of a year, and see whether you get a similar worst case. Note that comparing a phase *fraction* needs care at the wrap-around between 1.0 and 0.0.

## Sources

These pages were opened and read while writing this guide.

**Garmin documentation**

- [WatchFace API reference](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html): the descriptions of `onEnterSleep`, `onExitSleep`, `onPartialUpdate` and how often `onUpdate` runs.
- [Dc (drawing surface) API reference](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html): `drawText` justification flags, `fillPolygon` (64-point limit), `drawRectangle` (upper corner), `setPenWidth`, `getTextWidthInPixels`, `getFontHeight`, `clear`, `setColor`.
- [WatchUi API reference](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi.html): `getSubscreen` (returns a bounding box or `null`) and `requestUpdate`.
- [Connect IQ SDK page](https://developer.garmin.com/connect-iq/sdk/): the SDK Manager and the licence acceptance on download.
- [Connect IQ Developer Agreement](https://developer.garmin.com/downloads/connect-iq/sdks/agreement.html) (updated 6 August 2024): the terms for the SDK, including what may be said about Garmin's name and trademarks.
- [Garmin trademark notices](https://www8.garmin.com/manuals/webhelp/GUID-31D23DBB-57C2-4DF7-A0C9-8D1A00AB4BE7/EN-US/GUID-5CE73CC0-50D2-4473-8A04-7C740CCC4C88.html): Garmin, Instinct and Connect IQ are listed as trademarks of Garmin Ltd. or its subsidiaries.

**The sun method and its cross-check**

- [Sunrise/Sunset Algorithm](https://edwilliams.org/sunrise_sunset_algorithm.htm), attributed on that page to the Almanac for Computers, 1990, published by the Nautical Almanac Office, United States Naval Observatory. This is the method that `sunEventUtcHours` follows.
- [astral](https://github.com/sffjunkie/astral), a Python library for sun and moon calculations, whose repository states the Apache-2.0 licence. It was used only to cross-check the maths, and nothing from it is in the face.

**Reusing the sun code.** The Almanac page shows no copyright or usage terms. If you reuse `Astro.mc` in your own project, keep the credit to the method that its comment already gives.

**Not retrievable when this guide was written:** Garmin's Monkey C language pages and its manifest and build-configuration pages loaded without their body text. Statements marked *(language rule)*, the `monkey.jungle` behaviour and the manifest attribute descriptions come from this project's files, compiler messages and tests, not from those pages.

**Project files used:** `manifest.xml`, `monkey.jungle`, the resource files, `NotAWatchFaceDigitalApp.mc`, `NotAWatchFaceDigitalView.mc`, `Settings.mc`, `Astro.mc`, `README.md`, `INSTALL.md` and `QA-REPORT.md`, all from the NotAWatchFaceDigital project folder (version 1.0.3).
