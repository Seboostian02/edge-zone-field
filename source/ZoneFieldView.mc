using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Activity;
using Toybox.Lang;

class ZoneFieldView extends Ui.DataField {

    hidden var mPower3s;
    hidden var mHr;
    hidden var mPwrVal;
    hidden var mHrVal;
    hidden var mPwrHasData;

    hidden var mPwrBuf;
    hidden var mPwrBufIdx;

    hidden var mPwrZoneIdx;
    hidden var mHrZoneIdx;

    hidden var mPwrTime;
    hidden var mHrTime;

    hidden var mPwrBounds;
    hidden var mHrBounds;
    hidden var mPwrMax;
    hidden var mHrMax;

    function initialize() {
        DataField.initialize();
        mPower3s = 0;
        mHr = 0;
        mPwrVal = 0;
        mHrVal = 0;
        mPwrHasData = false;
        mPwrBuf = [0, 0, 0];
        mPwrBufIdx = 0;
        mPwrZoneIdx = 0;
        mHrZoneIdx = 0;
        mPwrTime = [0, 0, 0, 0, 0, 0, 0];
        mHrTime = [0, 0, 0, 0, 0];
        loadZones();
    }

    hidden function loadZones() {
        mPwrBounds = Zones.loadPowerBounds();
        mHrBounds = Zones.loadHrBounds();
        mPwrMax = mPwrBounds[7];
        mHrMax = mHrBounds[5];
    }

    function compute(info) {
        var p = info.currentPower;
        mPwrHasData = (p != null);
        if (p == null) { p = 0; }
        mPwrVal = p;
        mPwrBuf[mPwrBufIdx] = p;
        mPwrBufIdx = (mPwrBufIdx + 1) % 3;
        mPower3s = (mPwrBuf[0] + mPwrBuf[1] + mPwrBuf[2]) / 3;

        var hr = info.currentHeartRate;
        var hrValid = (hr != null && hr > 0);
        if (hr == null) { hr = 0; }
        mHrVal = hr;
        mHr = hr;

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

        var barW = 8;
        var bottomH = (h * 0.20).toNumber();
        var topH = h - bottomH;
        var midX = w / 2;
        var leftX = barW;
        var rightEdge = w - barW;

        drawColumn(dc, leftX, 0, midX - leftX, topH, fg,
            7, mPwrBounds, mPwrTime, mPwrZoneIdx, Zones.POWER_COLORS, "W");
        drawColumn(dc, midX, 0, rightEdge - midX, topH, fg,
            5, mHrBounds, mHrTime, mHrZoneIdx, Zones.HR_COLORS, "");

        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(midX, 0, midX, topH);

        drawSideBar(dc, 0, 0, barW, topH, mPwrVal, mPwrMax, Zones.POWER_COLORS[mPwrZoneIdx]);
        drawSideBar(dc, rightEdge, 0, barW, topH, mHrVal, mHrMax, Zones.HR_COLORS[mHrZoneIdx]);

        drawBottom(dc, topH, w, bottomH, midX);
    }

    // One zone column: rows stacked highest-zone-on-top.
    hidden function drawColumn(dc, x, y, colW, colH, fg, n, bounds, times, curIdx, colors, unit) {
        var rowH = colH / n;
        for (var r = 0; r < n; r += 1) {
            var zi = (n - 1) - r;
            var ry = y + r * rowH;
            drawZoneRow(dc, x, ry, colW, rowH, fg,
                Lang.format("Z$1$", [zi + 1]),
                rangeStr(bounds, zi, n, unit),
                Zones.formatTime(times[zi]),
                colors[zi], (zi == curIdx));
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

    hidden function drawZoneRow(dc, x, y, rowW, rowH, fg, label, range, timeStr, color, isCurrent) {
        var swW = 7;
        dc.setColor(color, color);
        dc.fillRectangle(x + 1, y + 1, swW, rowH - 2);

        var tx = x + swW + 5;
        dc.setColor(fg, Gfx.COLOR_TRANSPARENT);
        dc.drawText(tx, y + 1, Gfx.FONT_XTINY, label, Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(x + rowW - 2, y + 1, Gfx.FONT_XTINY, timeStr, Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(tx, y + rowH / 2, Gfx.FONT_XTINY, range, Gfx.TEXT_JUSTIFY_LEFT);

        if (isCurrent) {
            dc.setPenWidth(3);
            dc.setColor(fg, Gfx.COLOR_TRANSPARENT);
            dc.drawRectangle(x, y, rowW, rowH);
            dc.setPenWidth(1);
        }
    }

    // Vertical bar that fills from the bottom up, colored by the current zone.
    hidden function drawSideBar(dc, x, y, barW, barH, value, maxScale, color) {
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, barW, barH);

        var frac = 0.0;
        if (maxScale > 0) { frac = value.toFloat() / maxScale; }
        if (frac < 0.0) { frac = 0.0; }
        if (frac > 1.0) { frac = 1.0; }

        var fillH = (barH * frac).toNumber();
        var fillY = y + barH - fillH;
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(x, fillY, barW, fillH);

        if (fillH > 5) {
            var cx = x + barW / 2;
            dc.fillPolygon([[x, fillY], [x + barW, fillY], [cx, fillY - 5]]);
        }
    }

    hidden function drawBottom(dc, y, w, bandH, midX) {
        drawBottomCell(dc, 0, y, midX, bandH,
            Zones.POWER_COLORS[mPwrZoneIdx], Zones.POWER_TEXT[mPwrZoneIdx],
            "3s POWER (W)", mPwrHasData ? mPower3s.toString() : "0");
        drawBottomCell(dc, midX, y, w - midX, bandH,
            Zones.HR_COLORS[mHrZoneIdx], Zones.HR_TEXT[mHrZoneIdx],
            "HEART RATE (bpm)", (mHrVal > 0) ? mHrVal.toString() : "0");
    }

    hidden function drawBottomCell(dc, x, y, cw, ch, color, textColor, label, value) {
        dc.setColor(color, color);
        dc.fillRectangle(x, y, cw, ch);
        dc.setColor(textColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(x + 4, y + 1, Gfx.FONT_XTINY, label, Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(x + cw / 2, y + ch / 2 + 6, Gfx.FONT_NUMBER_MEDIUM, value,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }
}
