# TOUCH SKY · 2.0 release notes · What's New

**1.5.8 → 2.0 · 322 updates**

From network-only to radio — from "seeing" to "reaching". Every step of the 2.0 journey.

**APRSLocus 2.0 goes live on Sep 25 at 22:00** — grab the latest build from GitHub Releases.

Dear fellow travelers of APRSLocus,

After 1.5.8 we wrote **322 updates**. Not a number, but a road from "a dot in the network" to "an answer in the sky". Here are all the footprints.

**1 · UI 2.0**: a map-first layout — the map stays full-screen and everything else lives in a draggable sheet, switchable back to 1.0 in Display settings; a floating bottom capsule nav (sliding indicator) plus a top-right capsule (weather / connection / locate); a 44px grab handle with full-page dragging; landscape unified across phone / tablet / desktop as a left rail + map; the top search bar removed, back returns to the map, weather and one-tap connect restored; 16 pages get a first-visit tip card.

**2 · Materials & themes**: new frosted glass (Acrylic) and mica materials plus a "full glass" tier; theme colors / icons / text are editable, with background images and JSON export (images included); more tokens, density and font controls, per-tab accents; backup & restore exports settings and data as one JSON.

**3 · Map & immersive map**: many sources (AMap / satellite / vector without an API key / Carto / OSM / OpenTopo / Esri); a new immersive map page (navigation style, nearby stations on the left); station filters apply to the map; offline map downloads by region; clustering removed; track replay (tap a day to replay it).

**4 · Stations & identification**: the aprs.org device database identifies vendor / model / class; 37 symbol tables and 3571 icons built in; a station action menu (favorite / copy callsign / delete) and APRS.tv lookup; APRSlocus platform identification (no longer just "a phone app"); a rebuilt plotting algorithm so stale, duplicate, bad and fuzzy positions no longer fool you.

**5 · Messaging & translation**: a unified chat and group list with ACK; group-chat refactor (create / invite / members / leave, no-ack broadcast); translation providers grew from 4 to 7, defaulting to auto and to a free keyless endpoint; two-way translation, side-by-side view, translate-before-send, automatic language detection and memory.

**6 · Links & RF**: new Bluetooth TNC (full KISS — the real fix for "receives but will not transmit") and sound-card TNC (AFSK 1200 — a phone plus one audio cable); new PKWDWPL (Kenwood waypoints, receive-only) and iGate; several sources can receive at once with the transmit source picked separately; a built-in link self-test; fixes for "TNC and PKWDWPL splitting one device" and "on-air audio not decodable".

**7 · Positioning & beaconing**: native iOS and macOS location; coarse network fixes no longer auto-beacon; stationary debounce for your own GPS; smart beaconing by turn (telling a real turn from a GPS glitch) and by distance; finer track sampling with beacon dots; configurable track and packet caps.

**8 · Weather · propagation · advice**: a weather panel (now + high/low + feels-like + humidity / pressure / dew point / wind / visibility / cloud); ham advice ranked safety > caution > opportunity > tip, covering the gray line, rain fade, icing SWR and ducting; HF/ionospheric propagation with day/night per band and a separate 6m forecast.

**9 · Home-screen widgets (Android)**: weather + ham tips (4 adaptive sizes), an HF propagation widget and a system-status widget; real icons and a graphic logo; scaling and dark mode; a design preview tool.

**10 · Data · export · backup**: ADIF export (custom frequency, selectable options); export path and filename fixes; a packet console (raw / parsed, manual inject, type filters); a stats view inside the station panel.

**11 · Device integrations**: Garmin app share links (gar.mn) and LiveTrack; BLE heart-rate straps (0x180D) with HR carried in the beacon; an "other data sources" entry on the device page.

**12 · Languages & localization**: six UI languages (Simplified / Traditional Chinese / English / Japanese / Indonesian / Spanish); multiple rounds of hard-coded Chinese cleanup; the honor wall and sponsors localized.

**13 · Community · honors · announcements**: the honor wall shows how to earn each badge, including "Developer", "FIRST FIX · highest honor" and "early member"; the sponsors list filled in; the in-app announcement banner comes straight from the website's Markdown.

**14 · Platforms · performance · stability**: iOS / macOS / desktop support and landscape polish; a fix for the "slower the longer it runs" APRS-IS rebuild + socket leak; frosted-glass and dynamic-background performance; plenty of regression tests and static checks.

Plus countless fixes: the About card spacing, the base-map panel not opening, the layer panel not responding, the chat input hidden below, "view on map" not returning, the weather panel not closing on an outside click… Together they make the 322 updates from 1.5.8 to 2.0.

> FIRST FIX is where we started; TOUCH SKY is a salute. 2.0 is the next departure.  
> The sky is vast — let's keep going together.

> Radio waves never end — thanks for traveling with us! 73!  
> The APRSLocus Team  
> September 25, 2026

- [Download latest](https://github.com/dariondong/APRSLocus/releases)
- [View full changelog](https://github.com/dariondong/APRSLocus/blob/main/CHANGELOG.md)
- [Feedback & Suggestions](https://github.com/dariondong/APRSLocus/issues)
