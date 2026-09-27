# 📡 v2.0.4 released — the withdrawn features are back

**v2.0.4 has been released.** The changes withdrawn earlier — because the **version number had been raised outside the normal release process** — are back: the position-packet data extensions (the `/A=` altitude and the PHG power / antenna height / gain fields) and standalone status packets, together with how they are shown. With the version-number change removed, they went through the normal process again and ship in this official release.

If you are still on 2.0.3, please upgrade to **2.0.4** (2.0.3 is still an invalid release — see below).

---

## 1. What is in this release

- **Position packet data extension (PHG)**: Settings → Radio → Station comment → "Advanced" takes power (W) / antenna height (ft) / gain (dB). Filling in any one of them appends the fixed 7-byte `PHGphgd`; the encoding follows APRS101 (power uses only the largest step that does not exceed the real value — over-reporting claims coverage you do not have), and the settings page echoes back what will actually be sent. In the packet the extension sits where the spec puts it: `PHG` comes **immediately after the symbol**.
- **Altitude (`/A=`)**: you can enter an altitude by hand; **leaving it empty follows the fix** (the default is unchanged).
- **Standalone status packets**: a status text can be entered, sharing one "Transmit" button with the position packet; an empty text sends the built-in `APRSlocus CONNECT` online frame. Received status text shows up on station details and in the map info window.
- **Fixes**: the Transmit button checks the link first, PHG without a fix is reported honestly, status packets use their own connection text, the "next report in …" countdown ticks every second, the device page's link self-test no longer repeats its title, and the phone-battery switch stays on the beacon page.

See the changelog for the full list.

[▶ Download 2.0.4](https://github.com/dariondong/APRSLocus/releases/tag/v2.0.4)

> A backup before upgrading is a good idea (Settings → Backup & Restore). On Android, if a signing-key conflict prevents installing over the top, back up first, uninstall the old build and install again.

---

## 2. About 2.0.3: still best avoided

**2.0.3 is still an invalid release.** It came from a change that **raised the version number from 2.0.2 to 2.0.3 outside the normal release process**, and a release was built from it.

APRSLocus **sends its version number over the air** (it appears in the identity and online frames on APRS-IS and on RF). If two different packages both claim to be **2.0.3**, platforms such as aprs.fi can no longer tell **which one is beaconing** — and if something goes wrong, nobody can trace it. That is why the release was withdrawn from GitHub and from this site.

If you have 2.0.3 installed, please **upgrade to 2.0.4**.

---

## 3. One rule: only the maintainer raises the version number, and only when releasing

Contributions are always welcome — issues, bug reports and pull requests. The one shared rule is simply: **do not touch the version number**; it is raised by the maintainer when a release is prepared.

---

**73!**

**The APRSLocus team**
27 September 2026
