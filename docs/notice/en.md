# ?? Terms of Use updated to V1.1 - one minute please

**The Terms of Use have been updated to V1.1 (1 October 2026).** This is not a cosmetic edit:
we wrote down **what the software actually does**. Several things were already happening in
code but were not described in the agreement. Per section 8, the revised agreement is
published in the app and on GitHub, and **continued use means acceptance**. Full text:
Settings -> About -> Terms of Use (or the website).

---

## Six new clauses

1. **3.5 Gateway forwarding is your responsibility**: forwarding APRS-IS packets onto RF
   (gateway / iGate) means you **transmit on amateur bands on behalf of others** - callsign,
   frequency, power and mode must all be lawful and compliant;
2. **3.6 Minors**: use it with the consent and guidance of a guardian, who bears the
   consequences; in particular, do not transmit on radio frequencies without the required
   qualifications;
3. **3.7 What you send**: APRS is a public, international network - content must be truthful,
   accurate and lawful, and must respect the laws, religions and cultural customs of different
   countries and regions;
4. **5.3 Which third parties see what**: weather sends your location, message translation
   sends the text to be translated, update checks query GitHub for a version, Garmin
   LiveTrack opens the link you add, and map tiles come from several providers - **none of
   this happens unless you use that feature**;
5. **7.6 Life Guard etc. are not medical devices**: crash/fall detection and heart-rate
   alarms are auxiliary reminders based on phone sensors and location; they may miss events,
   raise false alarms or be delayed, and they are **not an emergency service**. In an
   emergency, call your local emergency number directly;
6. **9.4 About tips and donations**: donations are entirely voluntary, do not buy any
   feature, priority support or service commitment, and are non-refundable. Minors should ask
   a guardian first.

## Also new: a restriction list

Starting with this version, the app reads a **restriction list** from the official site on
launch and every 6 hours, to restrict users who seriously violate the Terms of Use (section
8.2) - a matching callsign or install ID can no longer use the app. Two safety rules: if the
list **cannot be fetched, nobody is blocked** (one network hiccup must not lock everyone
out); and the matched install ID is kept on the device only and is **never uploaded** (the app
just downloads the list to compare). If you believe this is a mistake, the block screen shows
which entry and reason matched - contact us as described there.

## Fixed in the same release

- **Fixed the crash when Bluetooth fails to connect**: the blocking Bluetooth connect was
  running on the main thread, so the system declared the app unresponsive and killed it.
  Connecting now happens on a worker thread and reports failures honestly;
- **Phone battery no longer freezes**: it used to be read only when a location fix arrived,
  so a stationary phone showed a stale percentage;
- **Sport ranking**: rows used to show placeholder text ("Today - ...", "No steps"); they now
  show **rank + distance + how long ago + steps**. Tapping a station opens the same bottom
  sheet used everywhere else, and the board counts **today only** (steps from three days ago
  no longer outrank today\'s) and includes you, marked as such.

---

**Nothing is required from you**: continued use means you accept the revised agreement. If you
do not agree, please stop using this software.

**73!**

**The APRSLocus team**
1 October 2026
