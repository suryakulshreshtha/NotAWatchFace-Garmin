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

const DAY_NAMES = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

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

    // ------------------------------------------------------------------
    // Layout: runs once, works out every size from the actual screen
    // ------------------------------------------------------------------
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

        var side = mainW < h ? mainW : h;
        _cx = mainW / 2;
        _cy = h / 2;
        _radius = side / 2 - 1;

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

    // ------------------------------------------------------------------
    // Drawing
    // ------------------------------------------------------------------
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
