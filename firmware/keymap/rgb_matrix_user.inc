/* KeyGlow multi-color effects.
 *
 * Color 1 is the normal RGB matrix color (rgb_matrix_config.hsv).
 * Colors 2 and 3 come from the Mac (commands 8 and 9) and live in keyglow.c.
 * Brightness always follows rgb_matrix_config.hsv.v; speed follows the speed setting.
 * Positions run left to right across the board (LED point x: 0..224).
 */
RGB_MATRIX_EFFECT(KG_SPLIT)
RGB_MATRIX_EFFECT(KG_GRADIENT)
RGB_MATRIX_EFFECT(KG_FADE)
RGB_MATRIX_EFFECT(KG_WAVE)

#ifdef RGB_MATRIX_CUSTOM_EFFECT_IMPLS

extern uint8_t kg_hue[3], kg_sat[3]; /* [0] is refreshed from rgb_matrix_config each frame */
extern uint8_t kg_count;             /* 2 or 3 */

static RGB kg_color(uint8_t i) {
    HSV hsv = {kg_hue[i], kg_sat[i], rgb_matrix_config.hsv.v};
    return rgb_matrix_hsv_to_rgb(hsv);
}

static RGB kg_mix(RGB a, RGB b, uint8_t t) { /* t: 0 = a, 255 = b */
    RGB c = {
        .r = lerp8by8(a.r, b.r, t),
        .g = lerp8by8(a.g, b.g, t),
        .b = lerp8by8(a.b, b.b, t),
    };
    return c;
}

static void kg_sync(void) {
    kg_hue[0] = rgb_matrix_config.hsv.h;
    kg_sat[0] = rgb_matrix_config.hsv.s;
    if (kg_count < 2 || kg_count > 3) kg_count = 2;
}

/* Position along the palette: 0 .. (n-1)*256 for an open run, 0 .. n*256 for a loop. */
static RGB kg_at(uint16_t pos, bool loop) {
    uint8_t n   = kg_count;
    uint8_t idx = pos >> 8;
    uint8_t t   = pos & 0xFF;
    if (loop) {
        idx %= n;
        return kg_mix(kg_color(idx), kg_color((idx + 1) % n), t);
    }
    if (idx >= n - 1) return kg_color(n - 1);
    return kg_mix(kg_color(idx), kg_color(idx + 1), t);
}

/* Phase that advances with time; speed 0..255. One step = one color. */
static uint16_t kg_phase(void) {
    uint32_t span = (uint32_t)kg_count * 256;
    uint64_t p    = (uint64_t)g_rgb_timer * (rgb_matrix_config.speed + 8) / 128;
    return (uint16_t)(p % span);
}

/* Hard zones: left / right, or left / middle / right. */
bool KG_SPLIT(effect_params_t *params) {
    RGB_MATRIX_USE_LIMITS(led_min, led_max);
    kg_sync();
    for (uint8_t i = led_min; i < led_max; i++) {
        RGB_MATRIX_TEST_LED_FLAGS();
        uint8_t zone = (uint16_t)g_led_config.point[i].x * kg_count / 225;
        RGB     c    = kg_color(zone);
        rgb_matrix_set_color(i, c.r, c.g, c.b);
    }
    return rgb_matrix_check_finished_leds(led_max);
}

/* Smooth blend from color 1 on the left to the last color on the right. */
bool KG_GRADIENT(effect_params_t *params) {
    RGB_MATRIX_USE_LIMITS(led_min, led_max);
    kg_sync();
    for (uint8_t i = led_min; i < led_max; i++) {
        RGB_MATRIX_TEST_LED_FLAGS();
        uint16_t pos = (uint32_t)g_led_config.point[i].x * (kg_count - 1) * 256 / 224;
        RGB      c   = kg_at(pos, false);
        rgb_matrix_set_color(i, c.r, c.g, c.b);
    }
    return rgb_matrix_check_finished_leds(led_max);
}

/* Whole board fades from color to color, in order, then loops. */
bool KG_FADE(effect_params_t *params) {
    RGB_MATRIX_USE_LIMITS(led_min, led_max);
    kg_sync();
    RGB c = kg_at(kg_phase(), true);
    for (uint8_t i = led_min; i < led_max; i++) {
        RGB_MATRIX_TEST_LED_FLAGS();
        rgb_matrix_set_color(i, c.r, c.g, c.b);
    }
    return rgb_matrix_check_finished_leds(led_max);
}

/* The colors flow across the board from right to left, looping. */
bool KG_WAVE(effect_params_t *params) {
    RGB_MATRIX_USE_LIMITS(led_min, led_max);
    kg_sync();
    uint32_t span  = (uint32_t)kg_count * 256;
    uint16_t phase = kg_phase();
    for (uint8_t i = led_min; i < led_max; i++) {
        RGB_MATRIX_TEST_LED_FLAGS();
        uint32_t x   = (uint32_t)g_led_config.point[i].x * span / 225;
        RGB      c   = kg_at((uint16_t)((x + phase) % span), true);
        rgb_matrix_set_color(i, c.r, c.g, c.b);
    }
    return rgb_matrix_check_finished_leds(led_max);
}

#endif // RGB_MATRIX_CUSTOM_EFFECT_IMPLS
