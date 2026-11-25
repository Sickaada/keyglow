/* KeyGlow: lighting commands over the HID lock-light report.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 */
#include "keyglow.h"
#include "transport.h"
#include "battery.h"
#include "bat_level_animation.h"
#include "lpm.h"

/* Effect ids shared with the Mac app. Order must match KeyGlow.swift. */
static const uint8_t effects[] = {
    RGB_MATRIX_SOLID_COLOR,
    RGB_MATRIX_BREATHING,
    RGB_MATRIX_BAND_SPIRAL_VAL,
    RGB_MATRIX_CYCLE_ALL,
    RGB_MATRIX_CYCLE_LEFT_RIGHT,
    RGB_MATRIX_CYCLE_UP_DOWN,
    RGB_MATRIX_RAINBOW_MOVING_CHEVRON,
    RGB_MATRIX_CYCLE_OUT_IN,
    RGB_MATRIX_CYCLE_OUT_IN_DUAL,
    RGB_MATRIX_CYCLE_PINWHEEL,
    RGB_MATRIX_CYCLE_SPIRAL,
    RGB_MATRIX_DUAL_BEACON,
    RGB_MATRIX_RAINBOW_BEACON,
    RGB_MATRIX_JELLYBEAN_RAINDROPS,
    RGB_MATRIX_PIXEL_RAIN,
    RGB_MATRIX_TYPING_HEATMAP,
    RGB_MATRIX_DIGITAL_RAIN,
    RGB_MATRIX_SOLID_REACTIVE_SIMPLE,
    RGB_MATRIX_SOLID_REACTIVE_MULTIWIDE,
    RGB_MATRIX_SOLID_REACTIVE_MULTINEXUS,
    RGB_MATRIX_SPLASH,
    RGB_MATRIX_SOLID_SPLASH,
};

/* Decoder state */
static uint8_t  last_clock  = 0;
static uint32_t last_frame  = 0;
static uint8_t  frame_in_byte = 0; /* 0,1,2 */
static uint8_t  cur_byte    = 0;
static uint8_t  buf[7];
static uint8_t  len         = 0;
static bool     dropping    = false; /* bad packet: ignore until idle gap */
static int16_t  last_seq    = -1;

/* Signal view */
static bool     view        = false;
static uint8_t  raw_leds    = 0;
static uint32_t ping_start  = 0;
static bool     ping_on     = false;

static void reset_decoder(void) {
    frame_in_byte = 0;
    cur_byte      = 0;
    len           = 0;
    dropping      = false;
}

static void run(uint8_t cmd, uint8_t a, uint8_t b, uint8_t c) {
    /* QMK ignores mode/colour changes and skips indicators while lights are off. */
    if (cmd != KG_CMD_POWER && cmd != KG_CMD_SPEED && cmd != KG_CMD_BATTERY && !rgb_matrix_is_enabled()) rgb_matrix_enable();
    switch (cmd) {
        case KG_CMD_EFFECT:
            if (a < sizeof(effects)) rgb_matrix_mode(effects[a]);
            break;
        case KG_CMD_HSV:
            rgb_matrix_sethsv(a, b, c);
            break;
        case KG_CMD_SPEED:
            rgb_matrix_set_speed(a);
            break;
        case KG_CMD_POWER:
            if (a) rgb_matrix_enable(); else rgb_matrix_disable();
            break;
        case KG_CMD_VIEW:
            view = a != 0;
            break;
        case KG_CMD_PING:
            ping_on    = true;
            ping_start = timer_read32();
            break;
        case KG_CMD_BATTERY:
            /* Same guard as Fn+B: the reading is only meaningful on battery, off the cable. */
            if (get_transport() == TRANSPORT_BLUETOOTH && !usb_power_connected())
                bat_level_animiation_start(battery_get_percentage());
            break;
    }
}

static void got_byte(uint8_t v) {
    if (len == 0 && v != KG_MAGIC) { dropping = true; return; }
    buf[len++] = v;
    if (len < sizeof(buf)) return;

    uint8_t sum = buf[1] ^ buf[2] ^ buf[3] ^ buf[4] ^ buf[5];
    if (sum == buf[6] && buf[1] != last_seq) {
        last_seq = buf[1];
        run(buf[2], buf[3], buf[4], buf[5]);
    }
    len = 0; /* same seq again = the deliberate repeat; ignored */
}

void keyglow_frame(uint8_t leds) {
    raw_leds = leds;

    uint8_t clock = (leds >> 4) & 1;
    if (clock == last_clock) return; /* not one of our frames (e.g. Caps Lock change) */
    last_clock = clock;

    uint32_t idle = timer_elapsed32(last_frame);
    if (idle > KG_IDLE_MS) reset_decoder();
    if (idle > 1000) last_seq = -1; /* a fresh session may reuse an old seq */
    last_frame = timer_read32();
    if (dropping) return;

    uint8_t d = (leds & 1) | ((leds >> 1) & 2) | ((leds >> 1) & 4); /* Num, Scroll, Compose */
    switch (frame_in_byte) {
        case 0: cur_byte = d << 5; frame_in_byte = 1; break;
        case 1: cur_byte |= d << 2; frame_in_byte = 2; break;
        default:
            cur_byte |= d & 3;
            frame_in_byte = 0;
            got_byte(cur_byte);
            break;
    }
}

/* Bluetooth: called for every LED report straight from the event queue (patched bluetooth.c). */
void bluetooth_hid_indicator_user(uint8_t leds) {
    keyglow_frame(leds);
}

/* USB: QMK delivers each LED report here. In Bluetooth mode the hook above already ran. */
bool led_update_user(led_t state) {
    if (get_transport() == TRANSPORT_USB) keyglow_frame(state.raw);
    return true;
}

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    if (keycode == KG_VIEW) {
        if (record->event.pressed) view = !view;
        return false;
    }
    return true;
}

/* Keys 1..5 = Num, Caps, Scroll, Compose, Kana: green when that bit is set. */
#define KEY_1_INDEX 17

/* (rgb_matrix_indicators_user is taken by Keychron's factory test, so use the advanced hook.) */
bool rgb_matrix_indicators_advanced_user(uint8_t led_min, uint8_t led_max) {
    if (ping_on) {
        if (timer_elapsed32(ping_start) > 400) ping_on = false;
        else {
            for (uint8_t i = led_min; i < led_max; i++) rgb_matrix_set_color(i, 255, 255, 255);
            return true;
        }
    }
    if (view) {
        for (uint8_t i = 0; i < 5; i++) {
            uint8_t idx = KEY_1_INDEX + i;
            if (idx < led_min || idx >= led_max) continue;
            bool on = (raw_leds >> i) & 1;
            rgb_matrix_set_color(idx, on ? 0 : 40, on ? 255 : 0, 0);
        }
    }
    return true;
}
