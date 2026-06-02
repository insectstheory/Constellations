# Constellations
A generative MIDI sequencer for Monome Norns based on a geometric point system. Inspired by the dynamics of the night sky, Constellations explores movement to trigger external synths.
# constellations

A generative MIDI sequencer for norns. A set of points drifts continuously across the screen, each one bouncing off the edges. Whenever two points come close enough to connect, a line appears between them and a MIDI note fires — its pitch determined by the horizontal position of the pair, its velocity by their vertical position and distance. As the geometry shifts, the music shifts with it: dense clusters produce rapid polyphonic bursts, sparse configurations let single notes ring out in silence.

There are no loops, no fixed patterns, no quantization. The score writes itself.

---

## controls

### encoders

| encoder | function | range |
|---------|----------|-------|
| E1 | global speed — how fast all points move | 0.05 – 3.0 |
| E2 | number of points | 2 – 30 |
| E3 | maximum connection distance — how close two points must be to trigger a note | 5 – 80 px |

### keys

| key | action |
| K2 | randomize all point positions + MIDI panic (all notes off) |

## parameters menu

Open with K1, navigate to **PARAMETERS > EDIT**.

### MIDI

| parameter | description | range / options |
| MIDI device | selects the output device | 1 – 4 |
| MIDI channel | output channel; set to 0 for multi-channel mode | 0 – 16 |

In multi-channel mode (channel = 0), notes are distributed across channels 1–4 based on the indices of the two points that triggered them. This allows layering different synth voices on a single MIDI interface.

### SCALE

| parameter | description | options |
| scale | the scale used to map horizontal position to pitch | chromatic, major, minor, pentatonic, blues, whole tone, phrygian, lydian, dorian |
| root note | the root note of the scale | C1 – C4 (MIDI 24 – 72), default C3 |

Pitch is derived from the midpoint X position of each connected pair, mapped across four octaves of the selected scale. Notes are clamped to the valid MIDI range (0–127).

### VISUAL

| parameter | description | default |
|-----------|-------------|---------|
| node flash on trigger | when enabled, the two nodes that generate a note briefly expand into a circle for ~3 frames (~100 ms) | off |

---

## how notes are generated

Each frame, every unique pair of points is checked. If their distance falls below the current threshold:

- **pitch** — mapped from the midpoint X of the pair across four octaves of the selected scale and root note
- **velocity** — derived from the midpoint Y (higher on screen = louder), then scaled down proportionally to distance (closer = louder)
- **gate** — automatically calculated from current speed: slower movement produces longer notes, faster movement produces shorter ones (range ~500 ms down to ~40 ms)
- **channel** — either the fixed channel set in params, or distributed across 1–4 in multi mode

A note fires once when the connection opens and is held until the gate expires or the points drift apart, whichever comes first. No note is ever sent twice for the same active connection.

---

## tips

- Start with few points (4–6) and a wide distance threshold to hear individual connections clearly before adding density.
- Pentatonic and blues scales tend to sound consonant at high point counts; chromatic rewards slower speeds and fewer points.
- In multi-channel mode, routing channels 1–4 to different synth timbres (pad, pluck, bass, lead) gives the geometry an ensemble feel.
- K2 mid-performance is a clean reset: all notes cut immediately, new positions randomized, sequencer resumes at the next frame.
