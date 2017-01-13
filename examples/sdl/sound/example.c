/* KallistiOS ##version##

   sdl/sound/example.c
   Copyright (C) 2016 Lawrence Sebald
*/

/* This is a basic demonstration of how to set up and play audio with SDL on the
   Dreamcast. It isn't actually meant as an example of how to do things the
   right way, but rather as more of a regression test to make sure that SDL
   still works...

   That all said, it does show how to set up a very simple audio callback to
   generate sound. In the case of this example, a simple tone generated from a
   sine wave is what is played. Of course, more complex things are possible, but
   are left as an exercise for the reader. ;-)
*/

#include <SDL/SDL.h>
#include <dc/fmath.h>

/* Amplitude controls the volume of the generated sound. Valid values are
   anything from 0 to 32767. 16384 works nicely here. Don't change it. ;-) */
#define AMPLITUDE 16384

/* 44100HZ audio frequency... Pretty standard. */
#define FRQ_44KHZ 44100

/* This controls what tone is generated. Feel free to play with this if you want
   to make different sounds. */
#define INCREMENT 1.0f / 100.0f

static float pos = 0.0f;

/* Generate a nice pretty sine wave for some simple audio. */
static void audio_callback(void *userdata, Uint8 *stream, int length) {
    Sint16 *out = (Sint16 *)stream;
    int i;

    /* Length is in bytes, we're generating 16 bit samples, so divide the length
       by two to get the number of samples to generate. */
    length >>= 1;

    /* Generate samples on demand. */
    for(i = 0; i < length; ++i) {
        out[i] = (Sint16)(fsin(pos * F_PI) * AMPLITUDE);
        pos += INCREMENT;

        if(pos >= 2.0f)
            pos -= 2.0f;
    }
}

int main(int argc, char *argv[]) {
    SDL_AudioSpec spec, rspec;

    /* All we're doing is using audio, so only initialize audio... */
    SDL_Init(SDL_INIT_AUDIO);

    /* Set up our desired audio context. */
    spec.freq = FRQ_44KHZ;
    spec.format = AUDIO_S16SYS;
    spec.channels = 1;
    spec.samples = 2048;
    spec.callback = audio_callback;
    spec.userdata = NULL;

    /* Open and unpause audio. It'd probably be a good idea to check for any
       problems while opening the audio (or that the real spec is equal to the
       desired one), but we're just doing the bare minimum here... */
    SDL_OpenAudio(&spec, &rspec);
    SDL_PauseAudio(0);

    /* Let the sound run for a bit... */
    SDL_Delay(10 * 1000);

    /* We're done, so mute the audio and clean it up. */
    SDL_PauseAudio(1);
    SDL_CloseAudio();

    return 0;
}
