# 🆘 v2.0.9 · Life guard: crash & fall detection (beta)

**v2.0.9 is out.** It extends **Life guard** beyond the abnormal-heart-rate alarm with **crash and fall detection**: the phone notices one sharp impact and then no movement from you, and it raises an alert plus a system notification.

**This is a beta feature. Treat it as "may help, will sometimes false-alarm".** The criteria and the caveats are below — please read them before leaving it switched on.

---

## 1. How it decides that something happened

Two stages, and **both** must hold:

**① Impact** — the acceleration with gravity removed spikes above **3.2 g**. Crashes and falls both produce such a spike; sustained acceleration such as hard braking does not (gravity is separated out of the reading first).

**② Then stillness** — for **12 seconds** after the impact there is almost no movement.

Why the second stage is required: with the spike alone, **speed bumps, a phone dropped on a desk, or a good shake** all qualify, and an alert that fires several times a day gets ignored. The trade-off, stated plainly: **a minor impact — one where you can still move — will not alert.** This is about "I cannot move", not "a collision occurred".

Two more guards: nothing is judged in the first **20 seconds** after the app starts (picking the phone up and putting it down also creates spikes), and two alerts are at least **3 minutes** apart (one crash produces a burst of spikes).

## 2. Caveats — please read them all

- **It does false-alarm.** A speed bump followed by a 12-second stop at a red light satisfies both stages. The first button in the alert is "I am fine"; tap it and nothing else is affected.
- **It is a heuristic, not engineering-grade crash detection.** Fixed thresholds, no direction of travel, no GPS fusion, no cross-checking of any kind.
- **It only alerts; it does not act for you.** Calling emergency services and asking nearby stations for help both require **you to press the button** — the app never dials by itself and never sends a distress message on its own.
- **"Ask nearby stations" is not 110 / 120.** It sends one message to each of the **5** nearest APRSLocus stations within 100 km: `SOS CRASH HR=… position` (`SOS HR=…` for a heart-rate alarm), and it asks for confirmation first. Those operators **may not be online or looking at their phones**, and if no station is known nearby the request cannot be sent (the app says so).
- **It depends on phone hardware and on the app running.** An accelerometer is required (if there is none, the page says "this device cannot detect impact"); the accelerometer needs no extra permission. **Once the system ends the app's process there will be no alert** — this is not a background-resident service.
- **It is on by default** and can be turned off in **Settings → Life guard**. It does **not** require tracking to be on: it keeps watching even with no position updates (deliberately so — people turn GPS off to save battery when riding).
- **Please do not treat it as your only safety measure.** Ride and drive as carefully as you always would, and in a real emergency call **110 / 120** (or your local emergency number) directly.

## 3. The heart-rate alarm is unchanged

The original **abnormal heart-rate alarm** still works the same way: an **external heart-rate device must be connected and pushing data** (a Bluetooth chest strap or Garmin LiveTrack), and a reading must reach or cross the upper / lower limit you set. **A stale reading does not alert.** The limits and the emergency number are on the same page and take effect the moment you change them.

## 4. Three fixes in this release

- **Steps always showed "permission needed" even after it was granted.** A reading of -1 has three different causes: no step sensor, no activity-recognition permission, or **no hardware event yet** (without permission the system simply does not dispatch events, and reports no error). They were conflated, so "granted but has not walked yet" was displayed as "permission needed". There are now four states: unsupported / needs permission / **waiting for data** / ok.
- **Switches on the Life guard page did nothing** (state was written back, but the page did not follow it).
- **The "Save" button of the speed-tier editor was covered by the navigation bar** — the sheet now reserves both the keyboard and the system navigation bar.

---

**Please report what you see while it is in beta.** If it fires when it should not (or stays silent when it should not), send the **phone model and what was happening** (speed bump, hard braking, phone dropped…) to [GitHub Issues](https://github.com/dariondong/APRSLocus/issues) — thresholds like these can only be tuned against real situations.

**73!**

**The APRSLocus team**
29 September 2026
