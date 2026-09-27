# ⚠️ Important · v2.0.3 withdrawn — please roll back to 2.0.2

**v2.0.3 was an invalid release: it came from a version-number change made outside the normal release process. We have withdrawn it, and we recommend that anyone on 2.0.3 rolls back to 2.0.2.**

---

## 1. What happened

**v2.0.3 has been withdrawn.**

It originated from a **non-compliant version-number change**: outside the normal release process, the project version was raised from **2.0.2** to **2.0.3**, and a release was built from it.

That breaks a hard rule of this project: **the version number may only be raised by the maintainer, when a release is actually being prepared.** No feature contribution should ever touch it. So v2.0.3 is an **invalid release**, and we have:

- deleted the v2.0.3 **Release** and its **tag** on GitHub;
- pointed the website and download entry **back to 2.0.2**;
- **rolled the related changes back** out of the main branch.

---

## 2. Recommendation: roll back to 2.0.2

If you have installed or are running 2.0.3, **please roll back to 2.0.2**.

- **Android**: download and install **APRSLocus_2.0.2.apk**. If you hit a signing-key conflict and cannot install over the top, **back up** first (callsign, station comments, custom themes and other important settings), then uninstall 2.0.3 and install again.
- **Windows**: download and run **APRSLocus_Setup_2.0.2.exe**.
- **iOS**: download **APRSLocus_2.0.2_unsigned.ipa** and sign it yourself.

[▶ Download 2.0.2](https://github.com/dariondong/APRSLocus/releases/tag/v2.0.2)

> It is a good idea to make a backup before rolling back (Settings → Backup & Restore) — useful both for changing phones and for downgrading.

---

## 3. Why the version number matters so much

APRSLocus **sends its version number over the air** — it appears in the identity and online frames on APRS-IS and on RF (for example, APRSlocus CONNECT v2.0.2).

If two different packages both claim to be **2.0.3**, platforms such as aprs.fi can no longer tell **which one is beaconing** — and if something goes wrong, nobody can trace it. The version number is this project's identity on the air: it must stay unique, and only the maintainer may raise it when preparing a release.

---

## 4. What happens next

- The related feature changes **are not lost**: once the **version-number change is removed**, they will be resubmitted, reviewed and merged through the normal process, and shipped in the next **official release**.
- Genuine thanks to everyone who contributes, tests and reports issues. New features, bug reports and pull requests are all very welcome; the one rule we all share is simply — **do not touch the version number**.

If you have any questions about rolling back, or about the versioning rule, please ask in the QQ group or open a GitHub Issue.

**73!**

**The APRSLocus team**
27 September 2026
