/*
   KallistiOS 2.0.0

   main.c
   (C) 2014 Josh Pearson

   OpenGL Texture Environment Example.
*/
/*
   Note that the textures are RGB565 and do not contain alpha channel,
   the PVR hardware is used to perform transparency.
   User may press 'A' or 'B' to Enable or Disable rendering to Translucent list.
   Use D-Pad to toggle different blending modes.
*/

#include <kos.h>

#include <GL/gl.h>
#include <GL/glu.h>
#include <GL/glut.h>

static GLuint tex[2];

static char ENV_MODES[4][24] = { "GL_REPLACE\0", "GL_MODULATE\0", "GL_DECAL\0", "GL_MODULATEALPHA\0" };
static unsigned char ENV_MODE = 0;
static unsigned char BLEND = 0;

extern GLuint glTextureLoadPVR(char *fname, unsigned char isMipMapped, unsigned char glMipMap);

void glDrawQuads(float x, float y, float w, float h, int count,
                 unsigned int color, unsigned int texID, unsigned char useTex) {
    if(useTex)
        glBindTexture(GL_TEXTURE_2D, texID);
    else
        glDisable(GL_TEXTURE_2D);

    glBegin(GL_QUADS);

    glColor1ui(color);

    while(count--) {
        glTexCoord2f(0.0f + 0.01f, 0.0f + 0.01f);
        glKosVertex2f(x, y);
        glTexCoord2f(1.0f - 0.01f, 0.0f + 0.01f);
        glKosVertex2f(x + w, y);
        glTexCoord2f(1.0f - 0.01f, 1.0f - 0.01f);
        glKosVertex2f(x + w, y + h);
        glTexCoord2f(0.0f + 0.01f, 1.0f - 0.01f);
        glKosVertex2f(x, y + h);

        x += w * 2;
    }

    glEnd();
}

void RenderCallback() {
    if(BLEND)
        glEnable(GL_BLEND);

    glBlendFunc(GL_SRC_ALPHA, GL_DST_ALPHA);

    glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, ENV_MODE);

    glDrawQuads(80, 0, 480, 480, 1, 0xFF0000FF, tex[1], 1);

    glDisable(GL_BLEND);

    glDrawQuads(0, 0, 640, 480, 1, 0xFFAAAAAA, tex[0], 1);

    glutSwapBuffers();
}

void InputCallback() {
    maple_device_t *cont = maple_enum_type(0, MAPLE_FUNC_CONTROLLER);

    if(cont) {
        cont_state_t *state = (cont_state_t *)maple_dev_status(cont);

        if(!state)
            return;

        if(state->buttons & CONT_DPAD_UP) {
            ENV_MODE = 0;
            printf("%s\n", ENV_MODES[ENV_MODE]);
        }

        if(state->buttons & CONT_DPAD_DOWN) {
            ENV_MODE = 1;
            printf("%s\n", ENV_MODES[ENV_MODE]);
        }

        if(state->buttons & CONT_DPAD_LEFT) {
            ENV_MODE = 2;
            printf("%s\n", ENV_MODES[ENV_MODE]);
        }

        if(state->buttons & CONT_DPAD_RIGHT) {
            ENV_MODE = 3;
            printf("%s\n", ENV_MODES[ENV_MODE]);
        }

        if(state->buttons & CONT_A) {
            BLEND = 1;
        }

        if(state->buttons & CONT_B) {
            BLEND = 0;
        }
    }
}

extern uint8 romdisk[];
KOS_INIT_ROMDISK(romdisk);

int main(int argc, char **argv) {
    printf("OpenGL TXR_ENV Example v.0.1 (C) 2014 PH3NOM\n");

    glKosInit(); /* GL Will Initialize the PVR */

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluPerspective(60.0f, vid_mode->width / vid_mode->height, 0.1f, 100000.0f);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glShadeModel(GL_SMOOTH);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
	glEnable(GL_TEXTURE_2D);

    tex[0] = glTextureLoadPVR("/rd/wp001vq.pvr", 0, 0);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_FILTER, GL_LINEAR);

    tex[1] = glTextureLoadPVR("/rd/FlareWS_256.pvr", 0, 0);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_FILTER, GL_LINEAR);

    while(1) {
        InputCallback();
        RenderCallback();
    }

    return 0;
}
