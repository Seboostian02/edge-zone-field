# Zone Power+HR (Garmin Edge data field)

A Connect IQ data field for the Garmin Edge 540 that shows power zones (7 zones) and
heart rate zones (5 zones) at the same time, with the time spent in each zone, plus a
bottom band with 3s average power (left) and current heart rate (right). Colors and a
growing side bar reflect the current zone in real time.

## Layout

```
+--+-------------------------+-------------------------+--+
|P |  Z7  451-921W     1:23  |  Z5  171-185   0:12     |H |   <- power zones left (7)
|w |  Z6  361-450W     0:16  |  Z4  159-170   2:01     |R |      HR zones right (5)
|r |  ...                    |  ...                    |  |
|b |  Z1  0-165W       0:05  |  Z1  93-119    0:30     |b |   <- vertical bars that
+--+-------------------------+-------------------------+--+      grow with the value
|     3s POWER (W)  248      |   HEART RATE (bpm)  152  |       <- bottom band, cell
+----------------------------+--------------------------+          background = current zone
```

- Left column: 7 power zones (Z7 top .. Z1 bottom), color swatch, range in W, cumulative
  time. The current zone has a thick outline.
- Right column: same, 5 heart rate zones, range in bpm.
- Bottom band: 3s power (left) and current heart rate (right); each cell background is the
  color of the current zone.
- Edge bars (left = power, right = HR) fill from the bottom up, proportional to the current
  value relative to the ceiling of the top zone.

## Where the zones come from

1. Power zones are read from the profile via `UserProfile.getPowerZones(SPORT_CYCLING)`.
2. If unavailable, they are computed from FTP (`getFunctionalThresholdPower`) using the
   standard Garmin percentages: 0 / 55 / 75 / 90 / 105 / 120 / 150 % FTP.
3. If FTP is not configured either, the `ftp` property is used (default 200 W), which can
   be set from the field's Connect IQ settings (Garmin Connect / Express).

Heart rate zones come from `getHeartRateZones2(SPORT_CYCLING)` (5 zones). Set them on the
device under User Profile for correct values.

## Build

You need the Connect IQ SDK (via the SDK Manager) or the VS Code "Monkey C" extension.

1. Generate a developer key (once):
   ```
   openssl genrsa -out developer_key.pem 4096
   openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key -nocrypt
   ```
2. Compile for the Edge 540:
   ```
   monkeyc -d edge540 -f monkey.jungle -o bin/EdgeZoneField.prg -y developer_key
   ```
   If `monkeyc` complains that an API needs a higher level, raise `minApiLevel` in
   `manifest.xml`.

## Test in the simulator

```
connectiq                                   # start the simulator
monkeydo bin/EdgeZoneField.prg edge540
```
In the simulator, set FTP and the zones under User Profile, then use
Simulation > Activity Data (or a FIT file) to feed power and heart rate.

## Install on the Edge 540

1. Connect the Edge over USB.
2. Copy `bin/EdgeZoneField.prg` into the `GARMIN/Apps/` folder on the device.
3. Disconnect. On the Edge: add a data screen with the "single field" layout and pick the
   Connect IQ field "Zone Power+HR" so it fills the whole screen.

## Limitations

- A data field redraws once per second. The bars and colors update in 1 second steps;
  there is no smooth sub-second animation (a platform limitation).
- Built and structured for the Edge 540 (246x322). For the rest of the range, uncomment
  the products in `manifest.xml` and recompile with `-d <device>`.

## Structure

```
manifest.xml          type "datafield", product edge540
monkey.jungle         build
source/ZoneFieldApp.mc    AppBase
source/ZoneFieldView.mc   DataField: compute() + onUpdate() + drawing
source/Zones.mc           zone thresholds, colors, time-in-zone, formatting
resources/                strings, icon, settings (FTP fallback)
```
