using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Activity;
using Toybox.Lang;

class ZoneFieldView extends Ui.DataField {

    hidden var mPower3s;
    hidden var mHr;
    hidden var mElapsed;
    hidden var mPwrHasData;

    hidden var mPwrBuf;
    hidden var mPwrBufIdx;

    hidden var mPwrZoneIdx;
    hidden var mHrZoneIdx;

    hidden var mPwrTime;
    hidden var mHrTime;

    hidden var mPwrBounds;
    hidden var mHrBounds;

    function initialize() {
        DataField.initialize();
        mPower3s = 0;
        mHr = 0;
        mElapsed = 0;
        mPwrHasData = false;
        mPwrBuf = [0, 0, 0];
        mPwrBufIdx = 0;
        mPwrZoneIdx = 0;
        mHrZoneIdx = 0;
        mPwrTime = [0, 0, 0, 0, 0, 0, 0];
        mHrTime = [0, 0, 0, 0, 0];
        mPwrBounds = Zones.loadPowerBounds();
        mHrBounds = Zones.loadHrBounds();
    }

    function compute(info) {
        var p = info.currentPower;
        mPwrHasData = (p != null);
        if (p == null) { p = 0; }
        mPwrBuf[mPwrBufIdx] = p;
        mPwrBufIdx = (mPwrBufIdx + 1) % 3;
        mPower3s = (mPwrBuf[0] + mPwrBuf[1] + mPwrBuf[2]) / 3;

        var hr = info.currentHeartRate;
        var hrValid = (hr != null && hr > 0);
        if (hr == null) { hr = 0; }
        mHr = hr;

        var et = null;
        if (info has :elapsedTime) { et = info.elapsedTime; }
        if (et == null && (info has :timerTime)) { et = info.timerTime; }
        if (et == null) { et = 0; }
        mElapsed = et / 1000;

        mPwrZoneIdx = Zones.zoneIndex(mPwrBounds, mPower3s, 7);
        mHrZoneIdx = Zones.zoneIndex(mHrBounds, mHr, 5);

        var running = true;
        if (info has :timerState) {
            running = (info.timerState == Activity.TIMER_STATE_ON);
        }
        if (running) {
            if (mPwrHasData) { mPwrTime[mPwrZoneIdx] += 1; }
            if (hrValid)     { mHrTime[mHrZoneIdx] += 1; }
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var bg = getBackgroundColor();
        var fg = (bg == Gfx.COLOR_BLACK) ? Gfx.COLOR_WHITE : Gfx.COLOR_BLACK;

        dc.setColor(Gfx.COLOR_TRANSPARENT, bg);
        dc.clear();

        var bottomH = (h * 0.15).toNumber();
        var topH = h - bottomH;
        var midX = w / 2;

        drawColumn(dc, 0, 0, midX, topH, fg,
            7, mPwrBounds, mPwrTime, mPwrZoneIdx, Zones.POWER_COLORS, Zones.POWER_TINT, "W", false);
        drawColumn(dc, midX, 0, w - midX, topH, fg,
            5, mHrBounds, mHrTime, mHrZoneIdx, Zones.HR_COLORS, Zones.HR_TINT, "", true);

        drawBottom(dc, topH, w, bottomH);
    }

    // One zone column: rows stacked highest-zone-on-top.
    // Rows are tiled from exact fractions so the last row ends precisely at the
    // column bottom (keeps both columns aligned to the same baseline).
    // rightSide mirrors the swatch + arrow to the device's right edge.
    hidden function drawColumn(dc, x, y, colW, colH, fg, n, bounds, times, curIdx, colors, tints, unit, rightSide) {
        var total = 0;
        for (var i = 0; i < n; i += 1) { total += times[i]; }
        for (var r = 0; r < n; r += 1) {
            var zi = (n - 1) - r;
            var rowTop = y + (r * colH) / n;
            var rowBot = y + ((r + 1) * colH) / n;
            var frac = (total > 0) ? times[zi].toFloat() / total : 0.0;
            drawZoneRow(dc, x, rowTop, colW, rowBot - rowTop, fg,
                Lang.format("Z$1$", [zi + 1]),
                rangeStr(bounds, zi, n, unit),
                Zones.formatTime(times[zi]),
                colors[zi], tints[zi], frac, (zi == curIdx), rightSide);
        }
    }

    hidden function rangeStr(bounds, zi, n, unit) {
        var lo = bounds[zi];
        var hi;
        if (zi == n - 1) {
            hi = bounds[n];
        } else {
            hi = bounds[zi + 1] - 1;
        }
        return Lang.format("$1$-$2$$3$", [lo, hi, unit]);
    }

    hidden function drawZoneRow(dc, x, y, rowW, rowH, fg, label, range, timeStr, color, tint, frac, isCurrent, rightSide) {
        var swW = 6;
        var cy = y + rowH / 2;
        var swatchX; var contentLeft; var contentRight;
        if (rightSide) {
            swatchX = x + rowW - swW;
            contentLeft = x + 3;
            contentRight = x + rowW - swW - 11;
        } else {
            swatchX = x;
            contentLeft = x + swW + 11;
            contentRight = x + rowW - 3;
        }

        // fill the row by time share: power left->right, HR right->left.
        if (frac > 0.0) {
            var fillW = (rowW * frac).toNumber();
            if (fillW < 2) { fillW = 2; }
            dc.setColor(tint, tint);
            if (rightSide) {
                dc.fillRectangle(x + rowW - fillW, y + 1, fillW, rowH - 2);
            } else {
                dc.fillRectangle(x, y + 1, fillW, rowH - 2);
            }
        }

        dc.setColor(color, color);
        dc.fillRectangle(swatchX, y + 1, swW, rowH - 2);

        dc.setColor(fg, Gfx.COLOR_TRANSPARENT);
        var topC = y + (rowH * 40) / 100;
        var botC = y + (rowH * 76) / 100;
        var midC = y + (rowH * 58) / 100;
        // left: zone label (top) + range (bottom); right: big time, centered against that block.
        dc.drawText(contentLeft, topC, Gfx.FONT_XTINY, label,
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(contentLeft, botC, Gfx.FONT_XTINY, range,
            Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(contentRight, midC, Gfx.FONT_SMALL, timeStr,
            Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);

        if (isCurrent) {
            if (rightSide) {
                var gxr = x + rowW - swW - 2;
                dc.fillPolygon([[gxr, cy - 5], [gxr, cy + 5], [gxr - 8, cy]]);
            } else {
                var gxl = x + swW + 2;
                dc.fillPolygon([[gxl, cy - 5], [gxl, cy + 5], [gxl + 8, cy]]);
            }
            dc.setPenWidth(3);
            dc.drawRectangle(x, y, rowW, rowH);
            dc.setPenWidth(1);
        }
    }

    hidden function drawBottom(dc, y, w, bandH) {
        var q = w / 4;
        drawBottomCell(dc, 0, y, q, bandH,
            Zones.POWER_COLORS[mPwrZoneIdx], Zones.POWER_TEXT[mPwrZoneIdx],
            "3s W", mPwrHasData ? mPower3s.toString() : "0", Gfx.FONT_NUMBER_MILD);
        drawBottomCell(dc, q, y, w - 2 * q, bandH,
            Gfx.COLOR_DK_GRAY, Gfx.COLOR_WHITE,
            "TIME", Zones.formatTime(mElapsed), Gfx.FONT_NUMBER_MILD);
        drawBottomCell(dc, w - q, y, q, bandH,
            Zones.HR_COLORS[mHrZoneIdx], Zones.HR_TEXT[mHrZoneIdx],
            "HR bpm", (mHr > 0) ? mHr.toString() : "0", Gfx.FONT_NUMBER_MILD);
    }

    hidden function drawBottomCell(dc, x, y, cw, ch, color, textColor, label, value, valFont) {
        dc.setColor(color, color);
        dc.fillRectangle(x, y, cw, ch);
        dc.setColor(textColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + 3, y + 1, Gfx.FONT_XTINY, label, Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(x + cw / 2, y + ch / 2 + 4, valFont, value,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }
}
