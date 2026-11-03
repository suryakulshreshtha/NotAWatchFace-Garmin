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

    // Floating-point modulo that always returns a value in [0, m).
    function fmod(x as Float, m as Float) as Float {
        return x - m * Math.floor(x / m);
    }

    function sinD(deg as Float) as Float {
        return Math.sin(Math.toRadians(deg));
    }

    function cosD(deg as Float) as Float {
        return Math.cos(Math.toRadians(deg));
    }

    function tanD(deg as Float) as Float {
        return Math.tan(Math.toRadians(deg));
    }

    // Moon phase as a fraction of the cycle:
    // 0 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter.
    // Uses the average cycle length, so it can be off by up to about a day
    // (checked against an independent calculation); fine for a phase picture.
    function moonPhase(unixSeconds as Number) as Float {
        var days = (unixSeconds - NEW_MOON_EPOCH) / 86400.0;
        return fmod(days, SYNODIC_DAYS) / SYNODIC_DAYS;
    }

    // Day of the year (1-366) for a calendar date.
    function dayOfYear(year as Number, month as Number, day as Number) as Number {
        var n1 = (275 * month) / 9;
        var n2 = (month + 9) / 12;
        var n3 = 1 + (year - 4 * (year / 4) + 2) / 3;
        return n1 - (n2 * n3) + day - 30;
    }

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

        // Sun's mean anomaly and true longitude
        var m = 0.9856 * t - 3.289;
        var l = fmod(m + 1.916 * sinD(m) + 0.020 * sinD(2.0 * m) + 282.634, 360.0);

        // Right ascension, moved into the same quadrant as l, in hours
        var ra = fmod(Math.toDegrees(Math.atan(0.91764 * tanD(l))), 360.0);
        var lQuadrant = Math.floor(l / 90.0) * 90.0;
        var raQuadrant = Math.floor(ra / 90.0) * 90.0;
        ra = (ra + (lQuadrant - raQuadrant)) / 15.0;

        // Declination
        var sinDec = 0.39782 * sinD(l);
        var cosDec = Math.cos(Math.asin(sinDec));

        // Local hour angle
        var cosH = (cosD(zenith) - sinDec * sinD(lat)) / (cosDec * cosD(lat));
        if (cosH > 1.0 || cosH < -1.0) {
            return null;
        }
        var hDeg = Math.toDegrees(Math.acos(cosH));
        if (rising) {
            hDeg = 360.0 - hDeg;
        }

        // Local mean time of the event, then back to UTC
        var localMean = fmod(hDeg / 15.0 + ra - 0.06571 * t - 6.622, 24.0);
        return localMean - lngHour;
    }

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
