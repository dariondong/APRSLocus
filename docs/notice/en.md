# 📦 v2.0.11 · Android package: 81.6 MB → about 30 MB

**v2.0.11 is out.** It adds **no features**. It does two things: the Android build is now **split per CPU architecture** (about a third of the old size), and the update page can **list the packages** — because from this release on there are three of them.

**Bottom line: if you are not sure which one to pick, you do not have to.** The in-app "Check for updates" still downloads the 64-bit package, exactly as before.

---

## 1. Why it used to be that big

The build used to be a **universal APK**: one file carrying the machine code for **three CPUs** (arm64-v8a / armeabi-v7a / x86_64). Your phone only ever used one of them — the other two were **dead weight**.

Measured on the v2.0.10 package (81.6 MB):

- the three sets of native libraries totalled **76.6 MB (94%)** — each one holding your app's compiled code (14–17 MB) plus the Flutter engine (8–12 MB);
- everything else added up to roughly 4 MB (images, icons, symbol tables, text…).

So the fix is not to remove features, it is to stop making every user carry three copies.

## 2. There are three packages in the release now

Each is about **30 MB**:

- **`APRSLocus_2.0.11.apk`** — **64-bit**, for **almost every phone** (anything from 2015 on). **This is what the in-app update downloads**, so upgrading works exactly as before.
- **`APRSLocus_2.0.11_armeabi-v7a.apk`** — **32-bit**, for older devices. **Only needed on phones that are 32-bit only** (those cannot install the 64-bit build; Android reports an ABI mismatch).
- **`APRSLocus_2.0.11_x86_64.apk`** — only for **emulators / Chromebooks**; real phones normally do not need it.

> No need to choose: the in-app "Check for updates" picks the right one for your phone automatically. All three are the same code, compiled once per CPU.

## 3. The update page picks for you and downloads in-app

On Android the "Check for updates" page **picks the package matching your phone's CPU by itself** and **downloads it inside the app** (no browser hop), then tells you which file it is fetching (name · architecture · size). A 32-bit device gets the 32-bit build automatically — no more "installed, but Android says it is incompatible".

If you need another architecture (an emulator, say), grab it yourself from the [Releases](https://github.com/dariondong/APRSLocus/releases) page.

One display fix came along: while downloading, the page used to show **two progress bars** for the same download (it looked like two tasks). Now there is one.

---

**Nothing about the app's features or settings changed** — your links, beacon and theme stay as they are. If something looks wrong after upgrading, please report it at [GitHub Issues](https://github.com/dariondong/APRSLocus/issues).

**73!**

**The APRSLocus team**
1 October 2026
