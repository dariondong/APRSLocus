# v1.6.156 is out: smart beaconing can now trigger on turns

This release is all about **tracks and beaconing**:

- **A third smart-beacon trigger**: besides *timer* and *distance*, it can now
  **beacon when the heading changes enough**. On mountain roads you are slow, so
  the distance threshold takes ages to reach — yet those hairpins are exactly
  where the track matters most. Now a point is added whenever you turn past the
  configured angle. The angle is **per tier** (10–180°, 0 = off).

- **Live track sampling refined to 1 second**: it used to be one point every ten
  seconds, which drew corners as diagonals. The points **actually sent to the
  server** are now marked with small orange diamonds, so count and spacing are
  visible at a glance.

- **The station comment field now looks editable**: that row used to be blank,
  so nobody knew it could be tapped.

See the [release notes](https://github.com/dariondong/APRSLocus/releases) for
details and the [user manual](https://aprslocus.theez.top/en/manual/) for how-to.
