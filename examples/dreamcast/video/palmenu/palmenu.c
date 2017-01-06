/* KallistiOS ##version##

   palmenu.c
   Copyright (C) 2015 Lawrence Sebald

   Every once in a while, a question pops up on one of the various Dreamcast-
   related forums of how to deal with 50Hz TVs. Well, the standard tactic is to
   detect if the console is European and display a simple menu if so. That's
   exactly what this example does.

   For those on a US or Japanese console, this example is pretty boring.
*/

#include <kos/thread.h>

#include <dc/biosfont.h>
#include <dc/flashrom.h>
#include <dc/maple.h>
#include <dc/video.h>
#include <dc/maple/controller.h>

#define USE_50HZ 0
#define USE_60HZ 1

/* Draw a very simple "menu" on the screen to pick between 50Hz and 60Hz mode...
   This could obviously be spruced up a bit with a real menu, but this will do
   for an example. */
static int pal_menu(void) {
    maple_device_t *cont1;
    cont_state_t *state;

    /* Re-init to a 50Hz mode to display the menu. */
    vid_set_mode(DM_640x480_PAL_IL, PM_RGB565);

    /* Draw the "menu" on the screen. */
    bfont_draw_str(vram_s + 640 * 200 + 64, 640, 1, "Press A to run at 60Hz");
    bfont_draw_str(vram_s + 640 * 240 + 64, 640, 1, "or B to run at 50Hz");

    /* Wait for the user to press either A or B to pick which mode to use.*/
    for(;;) {
        if((cont1 = maple_enum_type(0, MAPLE_FUNC_CONTROLLER))) {
            if((state = (cont_state_t *)maple_dev_status(cont1))) {
                if(state->buttons & CONT_A)
                    return USE_60HZ;
                else if(state->buttons & CONT_B)
                    return USE_50HZ;
            }
        }

        /* Sleep for a bit. */
        thd_sleep(20);
    }
}

static void wait_for_start(void) {
    maple_device_t *cont1;
    cont_state_t *state;

    for(;;) {
        if((cont1 = maple_enum_type(0, MAPLE_FUNC_CONTROLLER))) {
            if((state = (cont_state_t *)maple_dev_status(cont1))) {
                if(state->buttons & CONT_START)
                    return;
            }
        }

        /* Sleep for a bit. */
        thd_sleep(20);
    }
}

int main(int argc, char *argv[]) {
    int region, cable, mode;
    int x, y, c;

    /* KOS normally initializes the video hardware to run at 60Hz, so on NTSC
       consoles, or those with VGA connections, we don't have to do anything
       else here... */
    region = flashrom_get_region();
    cable = vid_check_cable();

    /* So, if we detect a European console that isn't using VGA, prompt the user
       whether they want 50Hz mode or 60Hz mode. */
    if(region == FLASHROM_REGION_EUROPE && cable != CT_VGA) {
        mode = pal_menu();

        if(mode == USE_60HZ)
            vid_set_mode(DM_640x480_NTSC_IL, PM_RGB565);
        else /* if(mode == USE_50HZ) */
            vid_set_mode(DM_640x480_PAL_IL, PM_RGB565);
    }

    /* Draw a pattern on the screen, like the libdream/640x480 example. */
    for(y = 0; y < 480; y++) {
        for(x = 0; x < 640; x++) {
            c = (x ^ y) & 255;
            vram_s[y * 640 + x] = ((c >> 3) << 12) | ((c >> 2) << 5) |
                ((c >> 3) << 0);
        }
    }

    /* Wait for the user to press start. */
    wait_for_start();

    return 0;
}
