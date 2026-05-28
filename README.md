# Zone Power+HR (Garmin Edge data field)

Data field Connect IQ pentru Garmin Edge 540 care arata simultan zonele de putere
(7 zone) si zonele de puls (5 zone), cu timpul petrecut in fiecare zona, plus o banda
jos cu putere medie pe 3s (stanga) si puls curent (dreapta). Culorile si o bara
laterala care creste reflecta zona curenta in timp real.

## Layout

```
+--+-------------------------+-------------------------+--+
|P |  Z7  451-921W     1:23  |  Z5  171-185   0:12     |H |   <- putere stanga (7)
|w |  Z6  361-450W     0:16  |  Z4  159-170   2:01     |R |      puls dreapta (5)
|r |  ...                    |  ...                    |  |
|b |  Z1  0-165W       0:05  |  Z1  93-119    0:30     |b |   <- bare verticale
+--+-------------------------+-------------------------+--+      care cresc cu valoarea
|     3s POWER (W)  248      |   HEART RATE (bpm)  152  |       <- banda jos, fundal
+----------------------------+--------------------------+          colorat = zona curenta
```

- Coloana stanga: 7 zone de putere (Z7 sus .. Z1 jos), patratel colorat, interval in W,
  timp cumulat. Zona curenta are chenar gros.
- Coloana dreapta: la fel, 5 zone de puls, interval in bpm.
- Banda jos: 3s power (stanga) si puls curent (dreapta); fundalul fiecarei celule e
  culoarea zonei curente.
- Barele de pe margini (stanga = putere, dreapta = puls) se umplu de jos in sus
  proportional cu valoarea curenta, raportat la plafonul zonei maxime.

## De unde vin zonele

1. Zonele de putere se citesc din profil cu `UserProfile.getPowerZones(SPORT_CYCLING)`.
2. Daca nu exista, se calculeaza din FTP (`getFunctionalThresholdPower`) cu procentele
   standard Garmin: 0 / 55 / 75 / 90 / 105 / 120 / 150 % FTP.
3. Daca nici FTP nu e configurat, se foloseste proprietatea `ftp` (default 200 W),
   setabila din setarile Connect IQ ale field-ului (Garmin Connect / Express).

Zonele de puls vin din `getHeartRateZones2(SPORT_CYCLING)` (5 zone). Seteaza-le pe device
in Profil utilizator pentru valori corecte.

## Build

Ai nevoie de Connect IQ SDK (prin SDK Manager) sau extensia VS Code "Monkey C".

1. Genereaza o cheie de developer (o singura data):
   ```
   openssl genrsa -out developer_key.pem 4096
   openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key -nocrypt
   ```
2. Compileaza pentru Edge 540:
   ```
   monkeyc -d edge540 -f monkey.jungle -o bin/EdgeZoneField.prg -y developer_key
   ```
   Daca `monkeyc` se plange ca un API are nevoie de un nivel mai mare, ridica
   `minApiLevel` in `manifest.xml`.

## Test in simulator

```
connectiq                                   # porneste simulatorul
monkeydo bin/EdgeZoneField.prg edge540
```
In simulator, seteaza FTP-ul si zonele in User Profile, apoi foloseste
Simulation > Activity Data (sau un fisier FIT) ca sa trimiti putere si puls.

## Instalare pe Edge 540

1. Conecteaza Edge-ul prin USB.
2. Copiaza `bin/EdgeZoneField.prg` in folderul `GARMIN/Apps/` de pe device.
3. Deconecteaza. Pe Edge: adauga un ecran de date cu layout "single field" si alege
   field-ul Connect IQ "Zone Power+HR" ca sa ocupe tot ecranul.

## Limitari

- Un data field se redeseneaza o data pe secunda. Barele si culorile se actualizeaza
  in pasi de 1 secunda; nu exista animatie fluida sub-secunda (limitare de platforma).
- Testat ca structura pentru Edge 540 (246x322). Pentru restul gamei, decomenteaza
  produsele din `manifest.xml` si recompileaza cu `-d <device>`.

## Structura

```
manifest.xml          tip "datafield", produs edge540
monkey.jungle         build
source/ZoneFieldApp.mc    AppBase
source/ZoneFieldView.mc   DataField: compute() + onUpdate() + desen
source/Zones.mc           praguri zone, culori, timp-in-zona, format
resources/                strings, icon, setari (FTP fallback)
```
