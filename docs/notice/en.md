# ?? 2.0.14 - an "APRSLOCUS" dashboard on the box

**2.0.14 is out.** This release pushes the **phone live status** to the box: heart rate,
speed, course, the **auto-report countdown** (with a progress bar), mileage (trip /
total), battery, steps, GPS accuracy, APRS-IS state and unread messages - so while the
phone sits in a bag, the bar-mounted box shows it all at a glance. Heart rate takes the
lead when available (speed takes over otherwise), and nearby stations moved to their own
**NEARBY** page (8 rows).

The protocol also changed to `TEL k=v ...`, which survives new fields: the app can add
keys without touching the firmware (unknown keys are skipped, empty values are not sent,
and the box shows `--` instead of a fake 0).


**2.0.14 also fixes two things**: `IS rx-only` on the box now states the cause and the fix in the open (home `set pass`, the server own words on the SYS page, and the app event log; set `pass` to the passcode of the **base callsign**), and countdowns now tick **locally every second** with status pushed every **5 s**.
---

> Below is the box support introduced in **2.0.13**; it is still valid.


## 1. What the box reports back

Once connected, the app shows what the **box itself** reports:

- callsign / SSID, link mode (wifi / bt / both), beacon interval, APRS-IS server, GPS baud;
- frames sent (TX), beacons (BEACON), messages received (RXMSG), acknowledgements (ACK),
  errors (ERR), and the **text of the latest event**;
- every `EVT …` line and command reply the box sends lands in the log with one-tap copy -
  that is the only evidence when something is wrong.

## 2. What the phone can do for the box

- **Change the config**: all 23 keys (names match the box documentation), tap one to edit.
  The app **re-reads after each change**, so the screen shows the **real value in the
  box**, not what you just typed;
- **Feed a position**: send the phone current coordinates (`POS lat lon [alt] [spd] [crs]`),
  optionally automatically every 30 seconds. Handy when the box has no GPS of its own;
- **Box actions**: beacon now / status packet / reconnect APRS-IS / clear stations /
  format self-test / **reboot the box** (link mode and Bluetooth are boot settings that
  need a restart - no need to pull the power any more).

## 3. New: phone status to the box (the box PHONE page)

This release also pushes what the **phone** sees to the box: its speed, course, altitude,
whether it has a fix, whether APRS-IS is up, unread messages, and the **nearby station
list** (by distance, up to 8).

The box gained a **PHONE** page that shows all of it; the home screen bottom line also
shows `PH 12km/h`, and the header has a `P` badge - it is **bright** only while the
phone is pushing (it dims after 120 s, so stale data never pretends to be live).

Why this matters: in Bluetooth-only mode the box has **no APRS-IS of its own**, so
"who is nearby" used to be empty on it; even in wifi mode the phone filter radius and
position can differ. Seeing both sides is the point.

## 4. Two deliberate rules

- the box is **not a data source**: it talks to APRS-IS by itself, so receiving its
  packets here again would only duplicate them. It appears as a managed device only;
- **nothing is transmitted automatically**: beacons and status packets must be tapped
  (same rule as "RF transmission is always explicit"). Only local position feeding and
  status pushing are automatic, and they never go on air.

## 5. Do I need to flash firmware

Yes - if you own a box. The app half (protocol + UI) is finished in this release; the
box half is a **separate firmware project** and needs a reflash (it gained the PHONE
page and a UI refresh). Without a box this release changes nothing for you.

---

**Updating has not changed**: in-app "check for updates" still picks the right package
for your CPU and **downloads it in-app**.

**73!**

**The APRSLocus team**
1 October 2026
