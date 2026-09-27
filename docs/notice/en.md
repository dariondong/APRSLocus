# 📡 v2.0.5 released — fixes 2.0.4's PHG (unreadable by third parties)

**v2.0.5 is out.** It fixes **a problem in 2.0.4**: once power / antenna height / gain were filled in, third parties could **not** read the `PHGphgd` field — so maps such as aprs.fi showed no coverage and the feature did nothing.

If you have **2.0.4** installed, please upgrade to **2.0.5**.

---

## 1. What was wrong in 2.0.4

The packet 2.0.4 sent looked like this (note the spaces between the extensions):

```
BG7LZQ-2>APALOC,TCPIP*,qAC,T2FZ:!2155.17N/11052.40Eb000/000 PHG2130 /A=000033 Bat:22%
```

Parsed with the reference implementation (aprslib), `phg` is **missing entirely** and `PHG2130` ends up as ordinary comment text.

Two independent traps caused it, and fixing only one is not enough:

1. **Data extensions must not be space-separated.** APRS101 defines PHG, `/A=` and the course/speed field (CsT) as **fixed-length data extensions** that must be glued to the symbol with no separators between them. Real stations look like `!3155.21N/12016.69ErPHG1460/A=000071`.
2. **CsT and PHG compete for the same "start of comment" slot.** Parsers match the `ddd/sss` course/speed form first and, **once it hits, only look for a DF report and never search for PHG**. So even glued together, PHG stays unreadable while `000/000` comes first.

## 2. How 2.0.5 fixes it

**The extension block is kept glued together, and the first slot goes to PHG** — when PHG is present, course/speed (CsT) is no longer sent with the position packet. Afterwards:

```
BG7LZQ-2>APALOC,TCPIP*,qAC,T2FZ:!2155.17N/11052.40EbPHG2130/A=000033 Bat:22%
← lat/lon+symbol glued to PHG, then /A=; spaces appear only between the block and the comment
```

**One trade-off to be aware of**: a **mobile** station that also fills in PHG shows no speed/bearing on aprs.fi — both need that single "start of comment" slot and cannot coexist. PHG describes a fixed antenna installation, which is not the same kind of station as a mobile one. **Stations without PHG are unaffected.**

The beacon packet's third-party compatibility test now runs in CI: this class of problem compiles fine and passes static analysis, and only a third-party parser can tell that something is unreadable — so a test is the only guard.

---

## 3. About 2.0.3: still an invalid release

**2.0.3 is still best avoided.** It came from a change that **raised the version number from 2.0.2 to 2.0.3 outside the normal release process**, and a release was built from it.

APRSLocus **sends its version number over the air** (it appears in the identity and online frames on APRS-IS and on RF). If two different packages both claim to be **2.0.3**, platforms such as aprs.fi can no longer tell **which one is beaconing** — and if something goes wrong, nobody can trace it. That is why the release was withdrawn from GitHub and from this site.

If you have 2.0.3 installed, please **upgrade to 2.0.5**.

---

## 4. One rule: only the maintainer raises the version number, and only when releasing

Contributions are always welcome — issues, bug reports and pull requests. The one shared rule is simply: **do not touch the version number**; it is raised by the maintainer when a release is prepared.

---

**73!**

**The APRSLocus team**
27 September 2026
