#include <kos.h>

void kb_test() {
    maple_device_t *cont, *kbd;
    cont_state_t *state;
    int k, x = 20, y = 20 + 24;

    printf("Now doing keyboard test\n");

    while(1) {
        cont = maple_enum_type(0, MAPLE_FUNC_CONTROLLER);

        if(!cont) continue;

        kbd = maple_enum_type(0, MAPLE_FUNC_KEYBOARD);

        if(!kbd) continue;

        /* Check for start on the controller */
        state = (cont_state_t *)maple_dev_status(cont);

        if(!state) {
            return;
        }

        if(state->buttons & CONT_START) {
            printf("Pressed start\n");
            return;
        }

        thd_sleep(10);

        /* Check for keyboard input */
        /* if (kbd_poll(mkb)) {
            printf("Error checking keyboard status\n");
            return;
        } */

        /* Get queued keys */
        while((k = kbd_get_key()) != -1) {
            if(k == 27) {
                printf("ESC pressed\n");
                return;
            }

            if(k > 0xff)
                printf("Special key %04x\n", k);

            if(k != 13) {
                bfont_draw(vram_s + y * 640 + x, 640, 0, k);
                x += 12;
            }
            else {
                x = 20;
                y += 24;
            }
        }

        thd_sleep(10);
    }
}

int main(int argc, char **argv) {
    int x, y;

    for(y = 0; y < 480; y++)
        for(x = 0; x < 640; x++) {
            int c = (x ^ y) & 255;
            vram_s[y * 640 + x] = ((c >> 3) << 12)
                                  | ((c >> 2) << 5)
                                  | ((c >> 3) << 0);
        }

    kb_test();

    return 0;
}
