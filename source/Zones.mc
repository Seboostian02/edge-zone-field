using Toybox.UserProfile;
using Toybox.Activity;
using Toybox.Application as App;
using Toybox.Graphics as Gfx;
using Toybox.Lang;

// Zone colors, threshold loading and time-in-zone helpers.
// Power model = 7 zones (Garmin %FTP scheme), HR model = 5 zones.
module Zones {

    // Power zone fill colors (Z1 .. Z7), matching the reference layout.
    const POWER_COLORS = [
        0xADE8F4, // Z1 light cyan
        0x0078D7, // Z2 blue
        0x00E000, // Z3 green
        0xFFFF00, // Z4 yellow
        0xFFA500, // Z5 orange
        0xFF00FF, // Z6 magenta
        0xFF0000  // Z7 red
    ];

    // Text color that reads well on top of each power color.
    const POWER_TEXT = [
        Gfx.COLOR_BLACK, Gfx.COLOR_WHITE, Gfx.COLOR_BLACK, Gfx.COLOR_BLACK,
        Gfx.COLOR_BLACK, Gfx.COLOR_WHITE, Gfx.COLOR_WHITE
    ];

    // HR zone fill colors (Z1 .. Z5), Garmin defaults.
    const HR_COLORS = [
        0x9E9E9E, // Z1 gray
        0x0078D7, // Z2 blue
        0x00E000, // Z3 green
        0xFFA500, // Z4 orange
        0xFF0000  // Z5 red
    ];

    const HR_TEXT = [
        Gfx.COLOR_BLACK, Gfx.COLOR_WHITE, Gfx.COLOR_BLACK, Gfx.COLOR_BLACK, Gfx.COLOR_WHITE
    ];

    // Light tints used to fill each row by time share (black text stays readable).
    const POWER_TINT = [
        0xD8F4FB, 0xCCECFF, 0xC8F5C8, 0xFFFFCC, 0xFFE6C2, 0xFFD6FF, 0xFFD6D6
    ];

    const HR_TINT = [
        0xDCDCDC, 0xCCECFF, 0xC8F5C8, 0xFFE6C2, 0xFFD6D6
    ];

    // Standard Garmin %FTP lower bounds for the 7 power zones, plus a top ceiling.
    const FTP_PCT = [0.0, 0.55, 0.75, 0.90, 1.05, 1.20, 1.50, 4.00];

    // Returns 8 watt boundaries: [z1lo, z1hi=z2lo, ... , z7hi].
    function loadPowerBounds() {
        var bounds = null;

        if (UserProfile has :getPowerZones) {
            var z = UserProfile.getPowerZones(Activity.SPORT_CYCLING);
            if (z != null) {
                if (z.size() == 8) {
                    bounds = z;
                } else if (z.size() == 7) {
                    bounds = [0, z[0], z[1], z[2], z[3], z[4], z[5], z[6]];
                }
            }
        }

        if (bounds == null) {
            bounds = ftpToBounds(loadFtp());
        }
        return bounds;
    }

    function loadFtp() {
        var ftp = null;
        if (UserProfile has :getFunctionalThresholdPower) {
            ftp = UserProfile.getFunctionalThresholdPower(Activity.SPORT_CYCLING);
        }
        if (ftp == null || ftp <= 0) {
            ftp = getFtpProp();
        }
        return ftp;
    }

    function getFtpProp() {
        var v = null;
        if (App has :Properties) {
            v = App.Properties.getValue("ftp");
        }
        if (v == null) {
            v = 200;
        }
        return v;
    }

    function ftpToBounds(ftp) {
        var b = new [8];
        for (var i = 0; i < 8; i += 1) {
            b[i] = (FTP_PCT[i] * ftp).toNumber();
        }
        return b;
    }

    // Returns 6 bpm boundaries: [minZ1, maxZ1, maxZ2, maxZ3, maxZ4, maxZ5].
    function loadHrBounds() {
        var z = null;
        if (UserProfile has :getHeartRateZones2) {
            z = UserProfile.getHeartRateZones2(Activity.SPORT_CYCLING);
        }
        if (z == null) {
            z = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
        }
        if (z != null && z.size() == 6) {
            return z;
        }
        // Last-resort defaults if the profile has no HR zones configured.
        return [93, 120, 140, 160, 175, 190];
    }

    // bounds = [min, max1, max2, ... maxN]. Returns 0-based zone index 0..n-1.
    function zoneIndex(bounds, value, n) {
        for (var k = 1; k <= n; k += 1) {
            if (value <= bounds[k]) {
                return k - 1;
            }
        }
        return n - 1;
    }

    // "M:SS" under an hour, otherwise "H:MM:SS".
    function formatTime(sec) {
        var h = sec / 3600;
        var m = (sec % 3600) / 60;
        var s = sec % 60;
        if (h > 0) {
            return Lang.format("$1$:$2$:$3$", [h, m.format("%02d"), s.format("%02d")]);
        }
        return Lang.format("$1$:$2$", [m, s.format("%02d")]);
    }
}
