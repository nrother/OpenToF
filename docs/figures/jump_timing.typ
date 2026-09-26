// Timing of one trampoline jump N: takeoff, landing, time of flight (ToF), time on bed (ToB).
// Source of docs/figures/jump_timing.svg / .png. Rebuild (from the repo root):
//   typst compile docs/figures/jump_timing.typ docs/figures/jump_timing.svg
//   typst compile --ppi 200 docs/figures/jump_timing.typ docs/figures/jump_timing.png
#import "@preview/cetz:0.4.2"

#set page(width: auto, height: auto, margin: 12pt, fill: white)
#set text(font: ("Segoe UI", "Arial"), size: 10pt)

#let tof = rgb("#1A7EFD") // OpenToF blue
#let tob = rgb("#E8830C")
#let tot = rgb("#555555")
#let muted = rgb("#8A8A8A")

#cetz.canvas(length: 1cm, {
  import cetz.draw: *

  // Event times (x, not to scale: a real ToB is ~0.2-0.3 s, a ToF ~1-2 s).
  let l0 = 1.2 // landing N-1
  let t1 = 3.6 // takeoff N
  let l1 = 10.4 // landing N
  let t2 = 12.8 // takeoff N+1
  let x-end = 14.2
  let apex = 3.6

  // ---- background bands -------------------------------------------------
  rect((l0, -0.9), (t1, apex + 0.6), fill: tob.lighten(88%), stroke: none)
  rect((t1, -0.9), (l1, apex + 0.6), fill: tof.lighten(90%), stroke: none)
  rect((l1, -0.9), (t2, apex + 0.6), fill: tob.lighten(93%), stroke: none)

  // ---- trampoline bed and the jumper's height ---------------------------
  line((-0.2, 0), (x-end + 0.2, 0), stroke: 2.2pt + rgb("#333333"))
  content((-0.2, 0), anchor: "east", padding: 4pt, text(fill: muted)[bed])

  let parabola(a, b, from, to) = {
    // height of a flight from a to b, sampled between from and to
    let pts = ()
    for i in range(0, 41) {
      let x = from + (to - from) * i / 40
      let u = (x - a) / (b - a)
      pts.push((x, 4 * apex * u * (1 - u)))
    }
    pts
  }
  let dip(a, b) = {
    // bed pushed down while the jumper is on it
    let pts = ()
    for i in range(0, 21) {
      let x = a + (b - a) * i / 20
      pts.push((x, -0.75 * calc.sin(calc.pi * i / 20)))
    }
    pts
  }
  let path = parabola(l0 - 6.8, l0, 0, l0) + dip(l0, t1) + parabola(t1, l1, t1, l1) + dip(l1, t2) + parabola(t2, t2 + 6.8, t2, x-end)
  line(..path, stroke: 1.6pt + black)

  // ---- events -----------------------------------------------------------
  let event(x, label, col, sub) = {
    line((x, -3.9), (x, apex + 0.6), stroke: (paint: col, dash: "dashed", thickness: 0.8pt))
    circle((x, 0), radius: 0.12, fill: col, stroke: white + 1pt)
    content((x, apex + 0.6), anchor: "south", padding: 3pt, text(fill: col, weight: "bold", label))
    content((x, apex + 0.6), anchor: "south", padding: (bottom: 16pt), text(size: 8pt, fill: muted, sub))
  }
  event(l0, [Landing N−1], tob, [jump\_id N−1])
  event(t1, [Takeoff N], tof, [jump\_id N])
  event(l1, [Landing N], tof, [jump\_id N])
  event(t2, [Takeoff N+1], muted, [jump\_id N+1])

  content(((t1 + l1) / 2, apex + 0.15), text(fill: tof)[in the air])
  content(((l0 + t1) / 2, 0.45), text(fill: tob, size: 9pt)[on the bed])

  // ---- durations --------------------------------------------------------
  let span(a, b, y, col, body, weight: "bold") = {
    line((a, y), (b, y), mark: (start: "|", end: "|"), stroke: 1.1pt + col)
    content(((a + b) / 2, y), anchor: "north", padding: 4pt, text(fill: col, weight: weight, body))
  }
  span(l0, t1, -1.3, tob, [ToB#sub[N]])
  span(t1, l1, -1.3, tof, [ToF#sub[N]])
  span(l1, t2, -1.3, muted, [ToB#sub[N+1]], weight: "regular")
  span(l0, l1, -2.45, tot, [Total#sub[N] = ToB#sub[N] + ToF#sub[N]])

  // ---- what the sensor reports (BLE events, protocol 1) ------------------
  let lane = -3.55
  line((0, lane), (x-end, lane), stroke: 0.6pt + muted)
  content((0, lane + 0.12), anchor: "south-west", text(size: 8pt, fill: muted)[sensor reports (time →)])
  let report(x, event-x, col, label) = {
    // a report sent at x, carrying the backdated event time event-x
    circle((x, lane), radius: 0.08, fill: col, stroke: none)
    content((x, lane), anchor: "north", padding: 3pt, text(size: 7.5pt, fill: col, label))
    if x != event-x {
      bezier((x, lane), (event-x, lane), (x - 0.2, lane + 0.6), (event-x + 0.2, lane + 0.6),
        stroke: (paint: col, dash: "dotted", thickness: 0.7pt), mark: (end: ">", size: 0.14))
    }
  }
  report(t1 + 0.45, t1, tof, [prov.])
  report(t1 + 1.6, t1, tof, [final])
  report(l1 + 0.45, l1, tof, [prov.])
  report(l1 + 1.5, l1, tof, [final])
})

#v(4pt)
#block(width: 15.5cm, inset: (x: 2pt))[
  #set text(size: 9pt)
  #grid(
    columns: (auto, 1fr),
    column-gutter: 10pt,
    row-gutter: 5pt,
    text(fill: tof, weight: "bold")[ToF#sub[N]], [time of flight = t(Landing N) − t(Takeoff N)],
    text(fill: tob, weight: "bold")[ToB#sub[N]], [time on bed *before* jump N = t(Takeoff N) − t(Landing N−1); unknown for the first jump after connecting],
    text(fill: tot, weight: "bold")[Total#sub[N]], [ToB#sub[N] + ToF#sub[N] (one full bed-to-bed cycle)],
    text(weight: "bold")[Height#sub[N]], [(beta) g · ToF#sub[N]#super[2] / 8],
    text(fill: muted)[reports], [the sensor sends each takeoff/landing as a fast *provisional* estimate and a refined *final* one (≤~200~ms later); both carry the event's own time (device clock, ms), so the report delay never changes the times above.],
  )
  #text(size: 8pt, fill: muted)[Not to scale: a real ToB is about 0.2–0.3 s, a ToF about 1–2 s.]
]
