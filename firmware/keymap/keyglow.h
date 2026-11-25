/* KeyGlow: lighting commands over the HID lock-light report.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 */
/* KeyGlow: receive lighting commands from the Mac through the lock-light (LED) report.
 *
 * Wire format (one HID LED output report = one "frame"):
 *   bit4 Kana    = clock, toggles every frame so each frame is a change
 *   bit1 Caps    = untouched: always the host's real Caps Lock state
 *   bit0 Num, bit2 Scroll, bit3 Compose = 3 data bits (d0, d1, d2)
 * Each byte = 3 frames, MSB first: [b7 b6 b5] [b4 b3 b2] [b1 b0 -].
 * Packet = A5 seq cmd a b c checksum   (checksum = XOR of seq..c)
 * A gap of KG_IDLE_MS between frames resets the decoder.
 */
#pragma once
#include QMK_KEYBOARD_H /* brings in NEW_SAFE_RANGE from k3_pro.h */

#ifndef NEW_SAFE_RANGE
#    define NEW_SAFE_RANGE SAFE_RANGE
#endif

enum keyglow_keycodes {
    KG_VIEW = NEW_SAFE_RANGE, /* Fn+V: show the raw signal bits on keys 1-5 */
};

#define KG_IDLE_MS 150
#define KG_MAGIC 0xA5

enum keyglow_cmd {
    KG_CMD_EFFECT = 1, /* a = effect id (see effect table) */
    KG_CMD_HSV    = 2, /* a = hue, b = saturation, c = brightness */
    KG_CMD_SPEED  = 3, /* a = speed */
    KG_CMD_POWER  = 4, /* a = 0 off, 1 on */
    KG_CMD_VIEW   = 5, /* a = 0 hide, 1 show signal view */
    KG_CMD_PING   = 6, /* flashes the whole board white once */
};

void keyglow_frame(uint8_t leds);
