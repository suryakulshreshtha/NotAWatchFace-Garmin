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

    // ------------------------------------------------------------------
    // Layout: runs once, works out every size from the actual screen
    // ------------------------------------------------------------------
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

    // ------------------------------------------------------------------
    // Drawing
    // ------------------------------------------------------------------
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
