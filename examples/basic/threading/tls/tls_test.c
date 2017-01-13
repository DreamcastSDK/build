/* KallistiOS ##version##

   tls_test.c
   Copyright (C) 2009 Lawrence Sebald

*/

/* This program is a test for thread-local storage added in KOS 1.3.0. */

#include <stdio.h>
#include <stdlib.h>
#include <kos/thread.h>
#include <kos/once.h>
#include <kos/tls.h>

#include <arch/arch.h>
#include <dc/maple.h>
#include <dc/maple/controller.h>

#define UNUSED __attribute__((unused))

kthread_once_t once = KTHREAD_ONCE_INIT;
kthread_key_t key1, key2;

void destructor(void *data) {
    printf("Destroying %d\n", (int)data);
}

void once_func(void) {
    if(kthread_key_create(&key2, &destructor)) {
        printf("Error in calling kthread_key_create\n");
    }
}

void *thd_func(void *param UNUSED) {
    kthread_t *cur = thd_get_current();
    void *data;

    printf("Thd %d: Reading key 1\n", cur->tid);
    data = kthread_getspecific(key1);
    printf("Thd %d: kthread_getspecific returned %p (should be NULL)\n",
           cur->tid, data);

    printf("Thd %d: Will create key 2, if its not created\n", cur->tid);
    kthread_once(&once, &once_func);

    printf("Thd %d: Writing to key 2\n", cur->tid);

    if(kthread_setspecific(key2, (void *)cur->tid)) {
        printf("Error in kthread_setspecific!!!\n");
        thd_exit(NULL);
    }

    if(cur->tid & 0x01) {
        printf("Thd %d: sleeping...\n", cur->tid);
        thd_sleep(200);
    }

    printf("Thd %d: Reading key 2\n", cur->tid);
    data = kthread_getspecific(key2);
    printf("Thd %d: kthread_getspecific returned %d (should be %d)\n", cur->tid,
           (int)data, cur->tid);
    return NULL;
}

KOS_INIT_FLAGS(INIT_DEFAULT);

int main(int argc, char *argv[]) {
    kthread_t *thds[2];
    void *data;

    cont_btn_callback(0, CONT_START | CONT_A | CONT_B | CONT_X | CONT_Y,
                      (cont_btn_callback_t)arch_exit);

    printf("KallistiOS TLS test program\n");

    printf("Main thread: Creating key 1\n");

    if(kthread_key_create(&key1, NULL)) {
        printf("Error in creating key 1\n");
        exit(-1);
    }

    printf("Main thread: Setting key 1 to 0xDEADBEEF\n");
    kthread_setspecific(key1, (void *)0xDEADBEEF);
    data = kthread_getspecific(key1);
    printf("Main thread: Key 1 value: %p\n", data);

    /* Create the threads. */
    printf("Main therad: Creating 2 threads\n");
    thds[0] = thd_create(0, &thd_func, NULL);
    thds[1] = thd_create(0, &thd_func, NULL);

    printf("Main thread: Waiting for the threads to finish\n");
    thd_join(thds[0], NULL);
    thd_join(thds[1], NULL);

    data = kthread_getspecific(key1);
    printf("Main thread: Key 1 value: %p\n", data);

    printf("Main thread: Removing keys\n");
    kthread_key_delete(key1);
    kthread_key_delete(key2);

    printf("Test finished\n");

    return 0;
}
