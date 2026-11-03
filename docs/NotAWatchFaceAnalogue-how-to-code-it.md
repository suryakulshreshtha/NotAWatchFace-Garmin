# NotAWatchFaceAnalogue: how to code it

A line-by-line guide to writing the NotAWatchFaceAnalogue watch face for the Garmin Instinct 2 Solar Tactical, from the empty project folder to the finished 387-line View.

## Start here

You will build a three-hand analogue watch face that measures the screen it runs on, and this guide shows every file and every code segment in the order you would write them.

**The finished face (version 1.0.2) shows:**

- An hour hand and a minute hand drawn as filled swords.
- A thin seconds needle with a hollow arrow tip, drawn only while the watch is awake.
- Arabic numerals 1 to 12 and a 60-tick minute track. Numerals that would sit under the round subscreen are skipped.
- A day window below the 12 and a date window above the 6.
- The current time in digital form inside the round subscreen, following the watch's 12/24-hour setting.
- No permissions: no network, no phone, no sensors.

**Target watch:** Garmin Instinct 2 Solar Tactical, Connect IQ device id `instinct2`. The screen is 176 × 176 pixels, two colours (black and white), with a round subscreen in the top-right corner.

**Who this is for:** students who know variables, `if`, loops and functions. You do not need any Garmin experience.

**How each segment is laid out:**

1. A heading with the file name and the line numbers.
2. The code, exactly as it is in the project. Copy it as it stands.
3. *What it does*, then *Why*, and sometimes *Try it*.

**What is and isn't verified.** Facts about Garmin's programming interfaces (`getSubscreen`, the drawing calls, the wake and sleep methods) were checked against Garmin's published API reference; the pages are listed under Sources. Statements marked *(language rule)* describe how Monkey C behaves, taken from this project's compiler messages and tests. Garmin's Monkey C language pages would not load when this guide was written, so confirm those rules in Garmin's documentation.

## Project map

The whole face is six small files plus one 387-line View, and you write them in the order shown below.

```
NotAWatchFaceAnalogue/
  manifest.xml
  monkey.jungle
  resources/
    drawables/
      drawables.xml
      launcher_icon.png        (62 x 62 pixels)
    strings/
      strings.xml
  source/
    NotAWatchFaceAnalogueApp.mc
    NotAWatchFaceAnalogueView.mc
  README.md   INSTALL.md   QA-REPORT.md
  bin/                         (created by the build; not source code)
```

| Order | File | Lines | Job |
| --- | --- | --- | --- |
| 1 | `manifest.xml` | 27 | The face's identity card: id, name, target watch, permissions |
| 2 | `monkey.jungle` | 1 | The build recipe: which manifest to use |
| 3 | `resources/strings/strings.xml` | 3 | The app name text |
| 3 | `resources/drawables/drawables.xml` | 3 | Declares the launcher icon |
| 3 | `resources/drawables/launcher_icon.png` | 62 × 62 px | The icon shown in the watch-face list |
| 4 | `source/NotAWatchFaceAnalogueApp.mc` | 21 | The entry point the watch starts first |
| 5 | `source/NotAWatchFaceAnalogueView.mc` | 387 | All the drawing: the face itself |
|  | `README.md`, `INSTALL.md`, `QA-REPORT.md` | 47, 343, 79 | Documentation, install guide and test record |

**How the pieces connect when the watch runs the face:**

1. The manifest names the entry class, `NotAWatchFaceAnalogueApp`.
2. The watch creates that class and calls its `getInitialView()` method.
3. That method returns the View, `NotAWatchFaceAnalogueView`.
4. The system calls the View's `onLayout` so it can measure the screen, then `onUpdate` whenever the face must be redrawn.
5. The View's `onShow`, `onExitSleep` and `onEnterSleep` tell it when the watch wakes and sleeps.

## Before you code

You need four things installed once: an editor, Garmin's SDK, Java for the compiler, and a developer key that signs your builds.

| Tool | What it is for | Used here |
| --- | --- | --- |
| Visual Studio Code with Garmin's *Monkey C* extension | Editing, build and simulator buttons | The editor for every file in this guide |
| Connect IQ SDK (installed with Garmin's SDK Manager) | The compiler, the device definitions and the simulator | SDK 9.3.0 |
| Java | The compiler is a Java program | Needed by `monkeybrains.jar` |
| Developer key | Signs every build; the store only accepts updates signed with the same key | One key for both faces |

`INSTALL.md` in the project walks through each of these step by step, including the Java options on a Mac and how to create the key.

**Treat the developer key like a password.** Keep a backup copy. Never copy it into a project that you share, and never put it in a public repository. In VS Code, point the extension at it with the setting `monkeyC.developerKeyPath`.

**What the compiler is asked to do.** VS Code runs this for you, but it helps to see it once. The same command builds either face when it is run from that face's project folder:

```
java -jar "<sdk folder>/bin/monkeybrains.jar" \
  -f monkey.jungle \
  -d instinct2 \
  -y <path to your developer key> \
  -o NotAWatchFaceAnalogue.prg
```

| Option | Meaning |
| --- | --- |
| `-f monkey.jungle` | The build recipe (one line, explained below) |
| `-d instinct2` | Build for this device; the compiler reads its screen size and features |
| `-y <key>` | The full path to your developer key |
| `-o <file>` | Where to write the finished `.prg` program |

The `.prg` file is what the watch runs. If the build fails, the compiler names the file and line, so read the message before changing anything.

## Manifest and resources

Four small files hold no drawing logic at all, but the watch and the store read them before they ever run your code.

### manifest.xml (27 lines)

```xml
<?xml version="1.0"?>
<iq:manifest xmlns:iq="http://www.garmin.com/xml/connectiq" version="3">
    <iq:application
        entry="NotAWatchFaceAnalogueApp"
        id="69e585c488764df89c573f56d5b5a691"
        launcherIcon="@Drawables.LauncherIcon"
        minApiLevel="3.2.7"
        name="@Strings.AppName"
        type="watchface"
        version="1.0.2">

        <iq:products>
            <!-- Instinct 2 / Instinct 2 Solar / Instinct 2 Solar Tactical Edition
                 176 x 176, 2-colour memory-in-pixel screen, round subscreen top-right -->
            <iq:product id="instinct2"/>
        </iq:products>

        <!-- No permissions: this face only reads the watch clock and date. -->
        <iq:permissions/>

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
| 5 `id` | The face's identity: 32 hexadecimal digits. Keep it the same across updates, because an update is recognised by this id. A brand-new app needs a new one. |
| 6 `launcherIcon` | A pointer (the `@`) to the bitmap with id `LauncherIcon` in `drawables.xml`. |
| 7 `minApiLevel` | The oldest Connect IQ API level the face accepts: `3.2.7`. |
| 8 `name` | A pointer to the string with id `AppName` in `strings.xml`. |
| 9 `type` | `watchface` makes it appear in the watch-face list instead of the app list. |
| 10 `version` | Your own release number, `1.0.2`. |
| 12–16 | The watches you build for. `instinct2` is the only product. The comment says it covers the Instinct 2, 2 Solar and 2 Solar Tactical Edition. |
| 18–19 | Permissions. The empty `<iq:permissions/>` means the face asks for nothing: no sensors, no location, no network. |
| 21–23 | Languages: English only. |
| 25 | Barrels are reusable code libraries. This project uses none. |

**Try it:** change `version` to `1.0.3`, rebuild. The number is yours to choose; keep your release notes in step with it.

### monkey.jungle (1 line)

```
project.manifest = manifest.xml
```

This single line tells the compiler which manifest belongs to the project. The project builds with only this line, and its `source/` and `resources/` folders are picked up without being listed. That is observed behaviour here, not something quoted from Garmin's documentation.

### resources/strings/strings.xml (3 lines)

```xml
<strings>
    <string id="AppName">NotAWatchFaceAnalogue</string>
</strings>
```

One piece of text with the id `AppName`. The manifest points at it with `@Strings.AppName`, so the name in the watch-face list comes from here.

### resources/drawables/drawables.xml (3 lines)

```xml
<drawables>
    <bitmap id="LauncherIcon" filename="launcher_icon.png"/>
</drawables>
```

It declares one picture with the id `LauncherIcon`, stored in `launcher_icon.png`. The picture is **62 × 62 pixels**. The first icon was 40 × 40, and the compiler warned that the Instinct 2 expects 62 × 62 and scaled it, so the icon was redrawn in version 1.0.2.

The View in this face never loads a resource, so none of this file's content appears in the drawing code.

## The App class

The App class is 21 lines whose only real job is to hand the watch your View.

### source/NotAWatchFaceAnalogueApp.mc (all 21 lines)

```
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point. The watch creates this class first and asks it for the view.
class NotAWatchFaceAnalogueApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        return [new NotAWatchFaceAnalogueView()];
    }
}
```

| Lines | What it does | Why |
| --- | --- | --- |
| 1–3 | `import Toybox.X;` makes a module of Garmin's library, called *Toybox*, available by name. | `Application` provides `AppBase`, `Lang` provides the basic types, `WatchUi` provides the View you return. |
| 5 | A comment. Everything after `//` is ignored by the compiler. | Say what the file is for in one sentence. |
| 6 | `class NotAWatchFaceAnalogueApp extends Application.AppBase` creates your class and makes it inherit everything `AppBase` already knows how to do. | The name must match `entry="NotAWatchFaceAnalogueApp"` in the manifest. |
| 8–10 | `initialize()` is the constructor, the code that runs when the object is created. It calls the parent's `initialize()`. | The parent class has set-up work to do before yours. |
| 12–16 | `onStart` and `onStop` are hooks the system calls when the app starts and stops. Both are empty here. | A watch face has nothing to set up or tear down. They are left in place as the usual skeleton. |
| 18–20 | `getInitialView()` returns an array whose first item is a new `NotAWatchFaceAnalogueView`. | This is the hand-over: the system shows the View you return, and everything else happens inside it. |

**Try it:** to see the chain work, change the class name in both the file and the manifest's `entry`. The two names must always match, so change both together.

## The View, part 1: imports, constants and state

The View is where the watch face lives, and its first 55 lines declare everything it will use before any drawing happens.

### Imports and the header comment (lines 1–22 of NotAWatchFaceAnalogueView.mc)

```
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// NotAWatchFaceAnalogue
//
// A three-hand analogue face for the Garmin Instinct 2 Solar Tactical
// (176 x 176, black-and-white memory-in-pixel screen).
//
//   - hour and minute hands (filled swords)
//   - seconds needle: thin stem with a hollow arrow tip, shown while the
//     watch is awake (about 10 seconds after a wrist raise), hidden when idle
//   - Arabic numerals 1-12 and a 60-tick minute track
//   - day window below 12, date window above 6
//   - current time in digital form inside the round subscreen
//
// All sizes are worked out from the screen in onLayout(), so nothing here
// is tied to exact pixel positions.
```

| Import | What the face takes from it |
| --- | --- |
| `Toybox.Graphics` | Colours such as `Graphics.COLOR_WHITE`, the font names, and the `Graphics.FontType` type |
| `Toybox.Lang` | The basic types: `Number`, `Float`, `Boolean`, `String`, `Array` |
| `Toybox.Math` | `sin`, `cos` and `toRadians` for the dial maths |
| `Toybox.System` | The clock (`getClockTime`) and the watch's settings (`getDeviceSettings`) |
| `Toybox.Time` | `Time.now()` and `Time.FORMAT_SHORT` |
| `Toybox.Time.Gregorian` | Turning a moment into day, month and weekday numbers |
| `Toybox.WatchUi` | The `WatchFace` base class, the subscreen lookup and `requestUpdate` |

The header comment is a design summary. Its last two lines state the design rule for the whole file: **no hard-coded pixel positions**. Sizes are measured from the screen, which is why `onLayout` is the longest function.

### The day names (line 24)

```
const DAY_NAMES = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
```

`const` declares a value that never changes. It sits outside the class, so any code in the file can read it. The list starts with Sunday because the date information numbers the weekdays 1 = Sunday to 7 = Saturday, as the comment at line 243 records. Later, `(dow + 6) % 7` turns that 1–7 number into the list position 0–6: weekday 1 gives 7 % 7 = 0 ("SUN") and weekday 7 gives 13 % 7 = 6 ("SAT").

### The class and its state (lines 26–55)

```
class NotAWatchFaceAnalogueView extends WatchUi.WatchFace {

    // Dial geometry (set in onLayout)
    private var _cx as Number = 88;
    private var _cy as Number = 88;
    private var _radius as Number = 87;
    private var _numeralRadius as Number = 60;
    private var _numeralFont as Graphics.FontType = Graphics.FONT_TINY;
    private var _hideNumeral as Array<Boolean> = [false, false, false, false, false, false,
                                                  false, false, false, false, false, false];

    // Day and date windows
    private var _windowFont as Graphics.FontType = Graphics.FONT_XTINY;
    private var _dayBoxW as Number = 30;
    private var _dateBoxW as Number = 20;
    private var _boxH as Number = 16;

    // Round subscreen ("bubble") in the top-right corner
    private var _hasSub as Boolean = false;
    private var _subX as Number = 0;
    private var _subY as Number = 0;
    private var _subR as Number = 0;
    private var _bubbleFont as Graphics.FontType = Graphics.FONT_TINY;

    // True for ~10 s after a wrist raise; the seconds needle is only drawn then
    private var _isAwake as Boolean = true;

    function initialize() {
        WatchFace.initialize();
    }
```

**Anatomy of one field:** `private var _cx as Number = 88;`

- `private`: only this class can touch it.
- `var`: a variable that can change.
- `_cx`: the name. The leading underscore is a naming habit that says "this belongs to the object".
- `as Number`: a type annotation, a promise about what it holds.
- `= 88`: the starting value.

| Lines | Group | Fields and meaning |
| --- | --- | --- |
| 29–35 | Dial geometry | `_cx`, `_cy` the dial centre; `_radius` the dial radius; `_numeralRadius` how far from the centre the numerals sit; `_numeralFont`; `_hideNumeral`, twelve true/false flags saying which numerals to skip |
| 38–41 | Day and date windows | The font, the two box widths and the shared box height |
| 44–48 | Subscreen ("bubble") | Whether one exists, its centre `_subX`, `_subY`, its radius `_subR`, and the font for the time inside it |
| 51 | Wake state | `_isAwake`, true while the seconds needle should be drawn |

**Why defaults?** Every field has a value before `onLayout` runs, and the numbers are sensible for a 176-pixel screen (88 is half of 176). `onLayout` then overwrites them with measured values.

Lines 53–55 are the constructor. `WatchFace.initialize();` calls the parent class's constructor, the same pattern as in the App class.

## The View, part 2: onLayout

`onLayout` is the measuring step: it asks the screen how big it is and works out every size the drawing code will use. A banner comment on lines 57–59 reads "Layout: runs once, works out every size from the actual screen". The function spans lines 60–151 and has five jobs.

### Job 1: find the screen and the subscreen (lines 60–85)

```
    function onLayout(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var mainW = w;

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
                    // On some Instinct models the subscreen adds a few pixels
                    // of width; centre the dial on the square main area.
                    if (w > h) {
                        mainW = h;
                    }
                }
            }
        }
```

**What it does.**

- `dc` is the *device context*, the drawing surface. It also answers questions about the screen: `getWidth()` and `getHeight()` give 176 and 176 on the Instinct 2.
- `WatchUi has :getSubscreen` asks "does this system offer a function called `getSubscreen`?" The `:name` form is a *symbol*. This is a feature check, so the same code can run on watches or software versions without the feature *(language rule)*.
- `WatchUi.getSubscreen()` returns a bounding box (x, y, width, height) or `null`. Garmin's reference says it returns `null` when there is no subscreen, or when a virtual one exists but is not used for normal views. Every `!= null` test is there for that reason.
- `(sw < sh ? sw : sh) / 2` picks the smaller of width and height and halves it: the bubble's radius. `sx + sw / 2` and `sy + sh / 2` give its centre.
- If the screen is wider than tall (`w > h`), the dial is centred on a square of side `h`, and `mainW` records that.

**Worked example.** The layout model used in QA assumes the subscreen box is x = 113, y = 0, width 62, height 62. The QA report says those numbers come from a working Instinct 2 face; they have not been confirmed on this watch here. With them: radius = 62 / 2 = 31, centre = (113 + 31, 0 + 31) = (144, 31).

### Job 2: the dial centre and radius (lines 87–90)

```
        var side = mainW < h ? mainW : h;
        _cx = mainW / 2;
        _cy = h / 2;
        _radius = side / 2 - 1;
```

The dial is a circle inside the square main area. `side` is the shorter side, the centre is half of each dimension, and the radius is half the side minus 1 pixel so the outer ticks stay on the screen. On a 176-pixel square that gives centre (88, 88) and radius 87.

### Job 3: place the numerals (lines 92–116)

```
        // Numerals: as far out as possible, just inside the long ticks,
        // pulled in only as much as needed to clear the subscreen.
        _numeralFont = (_radius >= 80) ? Graphics.FONT_TINY : Graphics.FONT_XTINY;
        var numH = dc.getFontHeight(_numeralFont);
        var numW = dc.getTextWidthInPixels("12", _numeralFont);
        var half = (numH > numW ? numH : numW) / 2;
        var rnMax = _radius - 9 - half;
        var minRn = (_radius * 0.6).toNumber();
        var rn = rnMax;
        if (_hasSub) {
            var tryRn = rnMax;
            while (tryRn >= minRn && anyNumeralHitsSub(dc, tryRn, numH)) {
                tryRn -= 1;
            }
            // Only pull the numerals in if that actually clears the subscreen.
            // Otherwise keep them full size and skip the ones under it.
            if (tryRn >= minRn) {
                rn = tryRn;
            }
        }
        _numeralRadius = rn;
        for (var n = 1; n <= 12; n += 1) {
            // Anything still under the subscreen is skipped (the bubble covers it).
            _hideNumeral[n - 1] = _hasSub && numeralHitsSub(dc, n, rn, numH);
        }
```

**What it does, step by step.**

1. Choose the font from the radius: `FONT_TINY` if the radius is 80 or more, otherwise the smaller `FONT_XTINY`.
2. Measure the biggest numeral: its height (`numH`) and the width of "12" (`numW`). `half` is half of the larger, the numeral's half-size.
3. `rnMax = _radius - 9 - half` is the farthest the numeral centres can sit. The long ticks start at `_radius - 7` (line 222), so 9 leaves a 2-pixel gap, and subtracting `half` keeps the whole numeral inside.
4. `minRn` is 60% of the radius, the closest to the centre the numerals may be pulled. `.toNumber()` turns the decimal result into a whole number.
5. If there is a subscreen, the `while` loop moves the numeral ring inward one pixel at a time while `anyNumeralHitsSub` says some numeral still touches the bubble.
6. **The key decision (lines 106–110).** The new radius is used only if the loop finished at or above `minRn`. If pulling in never clears the bubble, the numerals stay at full size and the ones under the bubble are hidden instead. The earlier version shrank them to the minimum and still collided; this rule fixed that (QA defect 1).
7. The last loop sets one hide-flag per numeral. `_hasSub && numeralHitsSub(...)` uses short-circuit logic: with no subscreen, the second test never runs.

### Job 4: fixed-size day and date windows (lines 118–136)

```
        // Day/date windows: fixed widths so the boxes don't jump around.
        _windowFont = Graphics.FONT_XTINY;
        var maxDayW = 0;
        for (var i = 0; i < DAY_NAMES.size(); i += 1) {
            var tw = dc.getTextWidthInPixels(DAY_NAMES[i], _windowFont);
            if (tw > maxDayW) {
                maxDayW = tw;
            }
        }
        _dayBoxW = maxDayW + 6;
        var maxDateW = 0;
        for (var d = 1; d <= 31; d += 1) {
            var tw2 = dc.getTextWidthInPixels(d.toString(), _windowFont);
            if (tw2 > maxDateW) {
                maxDateW = tw2;
            }
        }
        _dateBoxW = maxDateW + 6;
        _boxH = dc.getFontHeight(_windowFont) + 2;
```

This is a *find the maximum* loop, used twice. It measures every weekday name and every date from 1 to 31 in the window font and keeps the widest. Each box is the widest text plus 6 pixels (3 on each side). The height is the font height plus 2. Because the width comes from the widest possible text, the boxes never change size as the date changes.

### Job 5: choose the subscreen time font (lines 138–151)

```
        // Bubble font: the largest system font whose "00:00" fits the circle.
        if (_hasSub) {
            var fonts = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY];
            var maxW = (_subR * 2 * 0.84).toNumber();
            var maxH = (_subR * 2 * 0.75).toNumber();
            _bubbleFont = Graphics.FONT_XTINY;
            for (var f = 0; f < fonts.size(); f += 1) {
                if (dc.getTextWidthInPixels("00:00", fonts[f]) <= maxW && dc.getFontHeight(fonts[f]) <= maxH) {
                    _bubbleFont = fonts[f];
                    break;
                }
            }
        }
    }
```

The fonts are listed biggest first. The text must fit within 84% of the circle's width and 75% of its height. `"00:00"` is the test string, a stand-in for any time of that shape. The first font that fits wins and `break` stops the loop. The smallest font is the fallback when none fits. Line 151 closes `onLayout`.

## The View, part 3: wake, sleep and onUpdate

The face has two states, awake and asleep, and `onUpdate` draws the whole picture each time the system asks for it. A banner comment on lines 169–171 marks where the drawing code begins.

### Wake and sleep (lines 153–167)

```
    function onShow() as Void {
        _isAwake = true;
    }

    // Wrist raised: the system now redraws every second for a short time.
    function onExitSleep() as Void {
        _isAwake = true;
        WatchUi.requestUpdate();
    }

    // Back to low power: the system redraws once a minute, so hide the needle.
    function onEnterSleep() as Void {
        _isAwake = false;
        WatchUi.requestUpdate();
    }
```

**What Garmin's reference says** (the WatchFace API page):

- `onEnterSleep`: "The device is entering low power mode", and you should "terminate any active timers and prepare for once-per-minute updates".
- `onExitSleep`: "The device is exiting low power mode".
- `onUpdate`: in high-power mode the face is redrawn every second; in low-power mode the system calls it at the top of every minute.

**Why the seconds needle follows `_isAwake`.** In low power the screen is drawn once a minute, so a seconds needle would just stand still at a stale position. The face therefore draws the needle only while awake. `WatchUi.requestUpdate()` asks the system to call `onUpdate` so the needle appears or disappears straight away.

**About the "10 seconds".** The code comments and the README say the needle shows for about 10 seconds after a wrist raise. No timer in the code produces that number: the watch decides when to go back to sleep. The 10-second figure has not been verified.

### onUpdate: the whole picture, back to front (lines 172–213)

```
    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawMinuteTrack(dc);
        drawNumerals(dc);

        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        drawDayDate(dc, today);

        var clock = System.getClockTime();
        var hour12 = clock.hour % 12;
        var minute = clock.min;
        var second = clock.sec;

        var hourAngle = (hour12 + minute / 60.0) * 30.0;
        var minuteAngle = (minute + second / 60.0) * 6.0;

        var hourHalf = _radius / 16;
        if (hourHalf < 3) {
            hourHalf = 3;
        }
        var minuteHalf = _radius / 20;
        if (minuteHalf < 3) {
            minuteHalf = 3;
        }
        drawSword(dc, hourAngle, (_numeralRadius * 0.62).toNumber(), 8, hourHalf, false);
        drawSword(dc, minuteAngle, _radius - 10, 10, minuteHalf, true);

        if (_isAwake) {
            drawSecondsNeedle(dc, second * 6.0);
        }

        // Centre cap
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 4);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 1);

        // Drawn last so hands pass "under" the bubble and the time stays readable.
        drawBubble(dc, clock);
    }
```

**The draw order is the design.** Whatever is drawn later covers whatever was drawn earlier, like layers of paint:

| Order | Lines | Layer | Why here |
| --- | --- | --- | --- |
| 1 | 173–174 | Clear the screen to black | Start from a clean slate every time |
| 2 | 176 | Minute track (60 ticks) | The background of the dial |
| 3 | 177 | Numerals | Sit just inside the long ticks |
| 4 | 179–180 | Day and date windows | Read the calendar, draw two boxes |
| 5 | 198 | Hour hand | Shorter hand first |
| 6 | 199 | Minute hand | Drawn over the hour hand |
| 7 | 201–203 | Seconds needle, only if awake | On top of both hands |
| 8 | 205–209 | Centre cap | Hides where the hands meet |
| 9 | 212 | Subscreen time | Last, so nothing is drawn over it |

**The clock angles.**

- `clock.hour % 12` folds a 24-hour value into 0–11.
- `hourAngle = (hour12 + minute / 60.0) * 30.0`: the dial has 360 degrees and 12 hours, so each hour is 30 degrees. Adding `minute / 60.0` moves the hand smoothly between hours.
- `minuteAngle = (minute + second / 60.0) * 6.0`: 360 degrees over 60 minutes is 6 degrees per minute, and the seconds make the hand creep.
- The seconds needle uses `second * 6.0`.
- **Why `60.0` and not `60`?** With a decimal on one side the division keeps its fraction *(language rule)*. Dividing whole numbers would drop it, and the hands would jump instead of glide.

| Time | hourAngle | minuteAngle |
| --- | --- | --- |
| 3:30:00 | (3 + 0.5) × 30 = 105° | (30 + 0) × 6 = 180° |
| 12:15:30 | (0 + 0.25) × 30 = 7.5° | (15 + 0.5) × 6 = 93° |

**Hand widths.** `_radius / 16` and `_radius / 20` are whole-number divisions *(language rule)*: with a radius of 87 they give 5 and 4. The `if` lines enforce a minimum half-width of 3 pixels on small screens.

**Hand lengths.** The hour hand reaches 62% of the way to the numerals. The minute hand reaches `_radius - 10`, just short of the ticks. The numbers 8 and 10 are how far each hand's tail sticks out behind the centre. The last argument says whether to outline the hand: only the minute hand is outlined, so it stays visible where it crosses the hour hand.

## The View, part 4: the dial

Four short functions draw the static parts of the face, and they all rest on one trick: turning a clock angle into screen pixels.

**The trick.** Measure the angle `a` clockwise from 12 o'clock. A point at distance `r` from the centre is then:

```
x = cx + sin(a) * r
y = cy - cos(a) * r
```

The `y` has a minus because screen y grows downward. Check: `a = 0` gives `(cx, cy - r)`, the top (12 o'clock). `a = 90` degrees gives `(cx + r, cy)`, the right (3 o'clock). `Math.sin` and `Math.cos` work in radians, so degrees go through `Math.toRadians` first.

**The drawing surface remembers its settings.** After `dc.setColor(...)` or `dc.setPenWidth(...)`, every later call uses that colour or pen width until you change it. That is why the functions below set the colour first and put the pen width back to 1 at the end.

### drawMinuteTrack (lines 215–227)

```
    private function drawMinuteTrack(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 60; i += 1) {
            var a = Math.toRadians(i * 6.0);
            var s = Math.sin(a);
            var c = Math.cos(a);
            var isHourTick = (i % 5 == 0);
            var inner = isHourTick ? _radius - 7 : _radius - 3;
            dc.setPenWidth(isHourTick ? 2 : 1);
            dc.drawLine(_cx + s * inner, _cy - c * inner, _cx + s * _radius, _cy - c * _radius);
        }
        dc.setPenWidth(1);
    }
```

- One loop pass per minute mark: `i` runs 0 to 59, and each mark is `i * 6.0` degrees (360 ÷ 60).
- `i % 5 == 0` is true for 0, 5, 10 … 55: the 12 hour marks. `%` is the remainder after division.
- The condition `? :` form picks a value: hour marks start at `_radius - 7` and use a 2-pixel pen; minute marks start at `_radius - 3` and use a 1-pixel pen. Every mark ends at `_radius`.
- `drawLine` draws from the inner point to the outer point.

### drawNumerals (lines 229–240)

```
    private function drawNumerals(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var n = 1; n <= 12; n += 1) {
            if (!_hideNumeral[n - 1]) {
                var a = Math.toRadians(n * 30.0);
                var x = _cx + Math.sin(a) * _numeralRadius;
                var y = _cy - Math.cos(a) * _numeralRadius;
                dc.drawText(x, y, _numeralFont, n.toString(),
                            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }
    }
```

- Each numeral `n` sits at `n * 30` degrees (360 ÷ 12) on the numeral ring.
- `_hideNumeral[n - 1]` reads the flag for this numeral. Lists count from 0, so numeral 1 lives at position 0. `!` means "not".
- `drawText(x, y, font, text, justification)` draws the text. The two flags are combined with `|`, which Garmin's reference describes as a bit mask of one horizontal and one vertical justification. With centre and vertical-centre, `(x, y)` is the middle of the text, which is what you want when placing text on a circle.
- `n.toString()` turns the number into text.

### drawDayDate and drawWindow (lines 242–255)

```
    private function drawDayDate(dc as Dc, today as Gregorian.Info) as Void {
        var dow = today.day_of_week as Number;   // 1 = Sunday ... 7 = Saturday
        var day = today.day as Number;
        var offset = _numeralRadius / 2;
        drawWindow(dc, _cx, _cy - offset, _dayBoxW, DAY_NAMES[(dow + 6) % 7]);   // below 12
        drawWindow(dc, _cx, _cy + offset, _dateBoxW, day.toString());           // above 6
    }

    private function drawWindow(dc as Dc, x as Number, y as Number, boxW as Number, text as String) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(x - boxW / 2, y - _boxH / 2, boxW, _boxH);
        dc.drawText(x, y, _windowFont, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
```

- `today.day_of_week as Number` reads the weekday from the date information and tells the compiler it is a `Number`. The comment records the numbering: 1 = Sunday.
- `offset` is half the numeral ring's radius. The day box goes that far **above** the centre (`_cy - offset`), which is just below the 12. The date box goes the same distance **below** the centre, just above the 6.
- `drawWindow` is one function used twice. It draws the box outline, then the text in the middle.
- **Know what each call's `(x, y)` means.** `drawRectangle` wants the box's upper-left corner, per Garmin's reference, so the code subtracts half the width and half the height from the centre. `drawText` with centre flags wants the middle of the text, so it gets the centre directly.
- The weekday index `(dow + 6) % 7` was explained in part 1.

## The View, part 5: hands, needle and subscreen time

The hands are the best geometry lesson in the project: a direction vector, a perpendicular, and five points that become a sword.

### drawSword (lines 257–289)

```
    // Hour/minute hand: a filled sword shape. The minute hand gets a thin
    // black edge so it stays distinct where it crosses the hour hand.
    private function drawSword(dc as Dc, angleDeg as Float, length as Number, tail as Number,
                               halfWidth as Number, outline as Boolean) as Void {
        var a = Math.toRadians(angleDeg);
        var dx = Math.sin(a);
        var dy = -Math.cos(a);
        var px = -dy;   // perpendicular to the hand
        var py = dx;
        var mid = length * 0.55;
        var tailHalf = halfWidth - 1;

        var pts = [
            [_cx - dx * tail + px * tailHalf, _cy - dy * tail + py * tailHalf],
            [_cx + dx * mid + px * halfWidth, _cy + dy * mid + py * halfWidth],
            [_cx + dx * length, _cy + dy * length],
            [_cx + dx * mid - px * halfWidth, _cy + dy * mid - py * halfWidth],
            [_cx - dx * tail - px * tailHalf, _cy - dy * tail - py * tailHalf]
        ];

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);

        if (outline) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            for (var i = 0; i < pts.size(); i += 1) {
                var p1 = pts[i];
                var p2 = pts[(i + 1) % pts.size()];
                dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
            }
        }
    }
```

**Step 1: a direction and a sideways.**

- `(dx, dy) = (sin a, -cos a)` is a one-pixel step along the hand, from the earlier angle-to-pixels trick.
- `(px, py) = (-dy, dx)` is that step turned by 90 degrees: a one-pixel step across the hand. Pointing straight up, `(dx, dy) = (0, -1)` and `(px, py) = (1, 0)`, so the sideways step points right on the screen.

**Step 2: five points make the blade.** Each point starts at the centre `(_cx, _cy)` and moves along the hand and across it:

| Point | Along the hand | Across the hand | Where it is |
| --- | --- | --- | --- |
| 1 | `-tail` (backwards) | `+tailHalf` | Back end, one side |
| 2 | `+mid` (55% of the length) | `+halfWidth` | Widest point, one side |
| 3 | `+length` | none | The tip |
| 4 | `+mid` | `-halfWidth` | Widest point, other side |
| 5 | `-tail` | `-tailHalf` | Back end, other side |

The tail is one pixel narrower than the blade (`tailHalf = halfWidth - 1`), so the hand tapers.

**Step 3: fill.** `fillPolygon(pts)` fills the shape with the current colour, white. Garmin's reference gives a limit of 64 points; this uses five. The points go around the shape in order, so the edges join correctly.

**Step 4: the minute-hand outline.** With `outline` true, the loop draws a thin black line between each pair of neighbouring points. `(i + 1) % pts.size()` wraps the last point back to the first. `p1[0]` and `p1[1]` are the x and y of a point. The black edge keeps the minute hand distinct where it crosses the white hour hand.

### drawSecondsNeedle (lines 291–321)

```
    // Seconds needle: thin stem with a hollow arrow tip.
    private function drawSecondsNeedle(dc as Dc, angleDeg as Float) as Void {
        var a = Math.toRadians(angleDeg);
        var dx = Math.sin(a);
        var dy = -Math.cos(a);
        var px = -dy;
        var py = dx;

        var tip = _radius - 2;
        var headLen = 9;
        var headHalf = 4;
        var base = tip - headLen;
        var tail = (_radius * 0.15).toNumber();

        // Stem
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(_cx - dx * tail, _cy - dy * tail, _cx + dx * base, _cy + dy * base);
        dc.setPenWidth(1);

        // Hollow arrow head: black inside, white edge
        var t = [_cx + dx * tip, _cy + dy * tip];
        var b1 = [_cx + dx * base + px * headHalf, _cy + dy * base + py * headHalf];
        var b2 = [_cx + dx * base - px * headHalf, _cy + dy * base - py * headHalf];
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([t, b1, b2]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(t[0], t[1], b1[0], b1[1]);
        dc.drawLine(b1[0], b1[1], b2[0], b2[1]);
        dc.drawLine(b2[0], b2[1], t[0], t[1]);
    }
```

- The same direction and sideways steps are computed again from the seconds angle.
- The needle is a 2-pixel stem from a short tail behind the centre (15% of the radius) to the arrowhead's base, plus a triangle.
- **How to draw a hollow shape with only a filled-polygon tool:** fill the triangle black (erasing the stem and tick marks inside it), then draw its three edges in white.
- Line 309 puts the pen width back to 1 straight after the stem, so the arrowhead edges are thin.

### drawBubble and formatTime (lines 323–345)

```
    // Digital time inside the round subscreen.
    private function drawBubble(dc as Dc, clock as System.ClockTime) as Void {
        if (!_hasSub) {
            return;
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillCircle(_subX, _subY, _subR);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_subX, _subY, _bubbleFont, formatTime(clock.hour, clock.min),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Follows the watch's own 12/24-hour setting.
    private function formatTime(hour as Number, minute as Number) as String {
        if (System.getDeviceSettings().is24Hour) {
            return hour.format("%02d") + ":" + minute.format("%02d");
        }
        var h12 = hour % 12;
        if (h12 == 0) {
            h12 = 12;
        }
        return h12.toString() + ":" + minute.format("%02d");
    }
```

- `drawBubble` returns early if there is no subscreen, then fills the whole circle black. That wipes out any hand or numeral underneath, and the time is written on the clean disc.
- `formatTime` reads the watch's own 12/24-hour setting, so the face never disagrees with the rest of the watch.
- `hour.format("%02d")` turns a number into text padded to two digits with a leading zero.
- In 12-hour mode `hour % 12` gives 0 for midnight and noon, so 0 is replaced by 12. The hour has no leading zero.

| Clock | 24-hour setting | 12-hour setting |
| --- | --- | --- |
| 00:05 | `00:05` | `12:05` |
| 13:07 | `13:07` | `1:07` |

## The View, part 6: the collision helpers

The last three functions answer one question for `onLayout`: does this numeral touch the subscreen circle?

### Lines 347–387

```
    // ------------------------------------------------------------------
    // Subscreen collision helpers (used only in onLayout)
    // ------------------------------------------------------------------
    private function anyNumeralHitsSub(dc as Dc, rn as Number, numH as Number) as Boolean {
        for (var n = 1; n <= 12; n += 1) {
            if (numeralHitsSub(dc, n, rn, numH)) {
                return true;
            }
        }
        return false;
    }

    private function numeralHitsSub(dc as Dc, n as Number, rn as Number, numH as Number) as Boolean {
        var a = Math.toRadians(n * 30.0);
        var x = _cx + Math.sin(a) * rn;
        var y = _cy - Math.cos(a) * rn;
        var tw = dc.getTextWidthInPixels(n.toString(), _numeralFont);
        // Font heights include line spacing; 80% is closer to the glyph itself.
        var gh = numH * 0.8;
        return rectHitsCircle(x - tw / 2.0, y - gh / 2.0, tw, gh, _subX, _subY, _subR + 2);
    }

    private function rectHitsCircle(rx as Numeric, ry as Numeric, rw as Numeric, rh as Numeric,
                                    cx as Numeric, cy as Numeric, r as Numeric) as Boolean {
        var nx = cx;
        if (cx < rx) {
            nx = rx;
        } else if (cx > rx + rw) {
            nx = rx + rw;
        }
        var ny = cy;
        if (cy < ry) {
            ny = ry;
        } else if (cy > ry + rh) {
            ny = ry + rh;
        }
        var ddx = cx - nx;
        var ddy = cy - ny;
        return ddx * ddx + ddy * ddy < r * r;
    }
}
```

**anyNumeralHitsSub** tests numerals 1 to 12 one at a time and returns `true` at the first hit. `return` inside a loop leaves the whole function immediately.

**numeralHitsSub** builds a rectangle around one numeral and asks whether it touches the circle.

- The numeral's centre uses the same angle-to-pixels trick as the drawing code, at radius `rn`.
- The rectangle is as wide as the text (`tw`) and 80% as tall as the font. The comment explains why: font heights include line spacing, and the visible glyph is shorter.
- The circle is the subscreen's circle plus 2 pixels (`_subR + 2`), a safety margin.

**rectHitsCircle** is the classic rectangle-versus-circle test.

1. Find the point of the rectangle that is closest to the circle's centre. Take the centre's x, and if it lies left of the rectangle use the left edge, or if it lies right of the rectangle use the right edge. Do the same for y. This is called *clamping*.
2. Measure the gap (`ddx`, `ddy`) from the centre to that closest point.
3. They touch if the squared distance is less than the squared radius: `ddx * ddx + ddy * ddy < r * r`. Comparing squares avoids a square root.

**Worked example.** Rectangle with corner (10, 10), width 20, height 10; circle centre (40, 15).

| Radius | Closest point | Gap | Squared distance | Squared radius | Touching? |
| --- | --- | --- | --- | --- | --- |
| 8 | (30, 15) | (10, 0) | 100 | 64 | No |
| 11 | (30, 15) | (10, 0) | 100 | 121 | Yes |

`Numeric` as a parameter type means "a `Number` or a `Float`" *(language rule)*: the function is called with whole numbers (the subscreen's centre) and decimals (the text rectangle) in the same call.

## Maths cheat sheet

The main calculations in the face come down to nine small formulas, listed here with the line where each is used.

| Need | Formula | Lines |
| --- | --- | --- |
| Degrees to radians | `Math.toRadians(deg)`, because `sin` and `cos` take radians | 218, 233, 261, 293, 360 |
| A point on a circle at clock angle `a` | `x = cx + sin(a) * r`, `y = cy - cos(a) * r` | 224, 234–235, 361–362 |
| Hour-hand angle | `(hour12 + minute / 60.0) * 30.0` (360 ÷ 12 = 30° per hour) | 187 |
| Minute-hand angle | `(minute + second / 60.0) * 6.0` (360 ÷ 60 = 6° per minute) | 188 |
| Seconds-needle angle | `second * 6.0` | 202 |
| A step across a hand | `(px, py) = (-dy, dx)` for a direction `(dx, dy)` | 264–265, 296–297 |
| Weekday list position | `(dow + 6) % 7` turns 1 = Sunday into 0 | 246 |
| Corner of a box from its centre | `corner = centre - size / 2` | 253 |
| Rectangle touches circle | Clamp the centre to the rectangle, then compare squared distance with `r * r` | 369–386 |

**Reading the table.** The first two rows are the engine. Rows 3 to 5 feed angles into it. The sixth row turns a line into a blade with width. The last three are bookkeeping: lists, boxes and collision checks.

## Build, test and install

The safe order is build, test in the simulator, then copy to the watch, and each step has one rule that saves you from a bad install.

1. **Build.** Run the compiler command from the "Before you code" section, or use the Monkey C extension's build command in VS Code. The result is a `.prg` file.
2. **Test in the simulator first.** The extension's *Run Without Debugging* command builds into the project's `bin/` folder and starts Garmin's simulator. Work through the checklist in `INSTALL.md`: hands move, numerals clear the subscreen, boxes show the right day and date, the time follows the 12/24-hour setting.
3. **Never copy the simulator's `bin/` build to the watch.** Copy the `.prg` you built for the real device (`-d instinct2`).
4. **Copy over USB.** Put the watch in USB data mode so it appears as a drive called GARMIN, then copy the `.prg` into `GARMIN/APPS` on that drive.
5. **Check the copy, eject, then select the face.** On the watch, open the menu and choose Watch Face.

**The copy commands on a Mac** (replace the paths with your own):

```
cp -X <your build>/NotAWatchFaceAnalogue.prg /Volumes/GARMIN/GARMIN/APPS/
rm -f /Volumes/GARMIN/GARMIN/APPS/._NotAWatchFaceAnalogue.prg
shasum <your build>/NotAWatchFaceAnalogue.prg /Volumes/GARMIN/GARMIN/APPS/NotAWatchFaceAnalogue.prg
diskutil eject /Volumes/GARMIN
```

| Command | Why |
| --- | --- |
| `cp -X` | Copy without the extra metadata a Mac attaches to files |
| `rm -f …/._NotAWatchFaceAnalogue.prg` | The Mac may leave a hidden side file starting with `._`; delete it so the watch folder holds only your program |
| `shasum` on both files | Two identical checksums prove the copy is byte-for-byte the same |
| `diskutil eject` | Let the Mac finish writing before you unplug |

**The `.iq` file is for the store, not the watch.** An export with the `-e` option produces a `.iq` package for uploading to Garmin's store. The watch loads `.prg` files from `GARMIN/APPS`.

**Updating the store listing.** An update needs the same developer key and the same app `id` as the first upload. That is why the `id` in the manifest and the key file are worth guarding.

## What went wrong and how it was fixed

The project's own QA record lists three defects that touched this face, and each one teaches a different habit.

| # | Defect | Fix | Release | Habit it teaches |
| --- | --- | --- | --- | --- |
| 1 | Numerals shrank to their minimum size, yet 1 and 2 were still under the subscreen | Numerals stay full size unless shrinking actually clears the subscreen | 1.0.1 | Test the edge case, not just the normal case |
| 7 | The manifest used the older `minSdkVersion` attribute | Switched to `minApiLevel`, as current Garmin tooling writes it | 1.0.1 | Match what the current tools produce |
| 9 | The launcher icon was 40 × 40; the compiler reported the Instinct 2 expects 62 × 62 and scaled it (a warning) | Icon redrawn at 62 × 62 | 1.0.2 | Read compiler warnings, not only errors |

The sister face, NotAWatchFaceDigital, taught one more compiler lesson: Garmin's compiler rejected six local variables written as `var x as Type` with the message "Invalid explicit typing of a local variable". Fields and parameters may carry a type; local variables are inferred. That is why the View above declares `var w = dc.getWidth();` with no `as`.

**How the layout was tested without a watch.** The project's QA scripts hold a Python model of the drawing code. For the analogue face it ran every minute of the dial at three second positions and checked:

- the hands stay on the screen and inside the dial;
- numerals are clear of the subscreen, or deliberately skipped;
- the day and date windows are clear of the 12 and the 6;
- the subscreen time fits its circle.

A companion script checks the source statically: undefined names, unbalanced brackets, API names outside a verified list, and typed locals.

**Test the tests.** Three deliberate faults were injected into the layout model (a label overflow, columns at the screen edge, numerals pulled in needlessly). Each was caught, which shows the tests can fail when they should.

**Compiler result for this face.** Version 1.0.1 compiled on the target Mac with 0 errors and 1 warning (the icon). Version 1.0.2 fixed the warning.

**The limit of the model.** It uses stand-in fonts of similar size and an assumed subscreen position, so it is not Garmin's renderer. The simulator and the real watch have the last word, and the simulator checklist in `INSTALL.md` exists for that reason.

## Exercises

Each exercise changes one idea in the face, so test every one in the simulator before you try it on a watch.

| # | Exercise | Hint |
| --- | --- | --- |
| 1 | Predict, then check: what happens to the numeral ring if the font threshold on line 94 changes from 80 to 90? | Work out which font a radius of 87 selects, then re-read Job 3 of `onLayout`. |
| 2 | Add a month window (for example "NOV") somewhere that does not touch the day or date boxes. | `drawWindow` already does the work. You need a list of month names, a position, and a width found the same way as in Job 4. |
| 3 | Make the minute hand jump once per minute instead of gliding. | On line 188, remove `second / 60.0` and the plus sign before it, then compare both versions in the simulator. Think about how often `onUpdate` runs in low power, and how that affects a gliding hand. |
| 4 | Change the sword shape: move the widest point from 55% to 35% of the length. | Only one number in `drawSword` changes. Draw the five points on paper first. |
| 5 | Hide the day and date windows when the watch is asleep. | You already have `_isAwake`. Add one `if` in `onUpdate`. |
| 6 | Draw only the numerals 12, 3, 6 and 9. | `drawNumerals` loops over 1 to 12. Use the remainder operator `%`. |
| 7 | Port the face to a second watch model. | Add another `<iq:product>` to the manifest. Measured layout helps, but read every compiler message and check each model's screen shape and subscreen. |
| 8 | Write a small test for `rectHitsCircle` in any language. | Use the worked example from part 6 as your first two test cases. |

**Stretch question.** The face recomputes all sizes only in `onLayout`. What would break if you moved the numeral-ring calculation into `onUpdate`? Think about how many times per minute each one runs.

## Sources

These Garmin pages were opened and read while writing this guide.

- [WatchFace API reference](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html): the descriptions of `onEnterSleep`, `onExitSleep`, `onPartialUpdate` and how often `onUpdate` runs.
- [Dc (drawing surface) API reference](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html): `drawText` justification flags, `fillPolygon` (64-point limit), `drawRectangle` (upper corner), `setPenWidth`, `getTextWidthInPixels`, `getFontHeight`, `clear`, `setColor`.
- [WatchUi API reference](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi.html): `getSubscreen` (returns a bounding box or `null`) and `requestUpdate`.
- [Connect IQ SDK page](https://developer.garmin.com/connect-iq/sdk/): the SDK Manager and the licence acceptance on download.

**Not retrievable when this guide was written:** Garmin's Monkey C language pages and its manifest and build-configuration pages loaded without their body text. Statements marked *(language rule)*, the `monkey.jungle` behaviour and the manifest attribute descriptions come from this project's files, compiler messages and tests, not from those pages.

**Project files used:** `manifest.xml`, `monkey.jungle`, the resource files, `NotAWatchFaceAnalogueApp.mc`, `NotAWatchFaceAnalogueView.mc`, `README.md`, `INSTALL.md` and `QA-REPORT.md`, all from the NotAWatchFaceAnalogue project folder (version 1.0.2).
