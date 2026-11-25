# KeyGlow wire protocol

The host sends HID **LED output reports** (report ID 1 over Bluetooth). Each report is one **frame**:

| Bit | LED     | Use                                                    |
|-----|---------|--------------------------------------------------------|
| 0   | Num     | data bit d0                                            |
| 1   | Caps    | untouched: always the host's real Caps Lock state      |
| 2   | Scroll  | data bit d1                                            |
| 3   | Compose | data bit d2                                            |
| 4   | Kana    | clock: toggles on every frame                          |

- **Byte** = 3 frames, most significant bit first: `[b7 b6 b5] [b4 b3 b2] [b1 b0 –]`.
- **Packet** = `A5 seq cmd a b c chk`, where `chk = seq ^ cmd ^ a ^ b ^ c`. It's followed by one padding frame, so the clock ends where it started (22 frames in total).
- The host sends each packet **twice**, about 400 ms apart. The firmware ignores the repeat by its `seq`.
- A gap of more than 150 ms between frames resets the decoder. After 1 s of idle, the firmware also forgets the last `seq`.

| cmd | Meaning   | Args                                   |
|-----|-----------|----------------------------------------|
| 1   | Effect    | a = effect index (see `effects[]` in `keyglow.c`) |
| 2   | Color     | a = hue, b = saturation, c = brightness (0–255) |
| 3   | Speed     | a = speed (0–255)                      |
| 4   | Power     | a = 0 off, 1 on                        |
| 5   | Signal view | a = 0 hide, 1 show                   |
| 6   | Ping      | flashes the whole board white          |
| 7   | Battery   | plays the Fn+B battery bar (on battery only, not while charging) |

Keychron's Bluetooth code drains its event queue in a loop, so QMK's normal `led_update_user` would only see the last frame of a burst. The patch calls `bluetooth_hid_indicator_user()` on every LED event instead.
