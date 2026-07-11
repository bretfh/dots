#include <pty.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/ioctl.h>

/* Spawn CMD under /bin/sh in a new pseudo-terminal. forkpty does
   openpty+fork+setsid+TIOCSCTTY; the child execs immediately so no Lisp
   runs in the forked child of a threaded runtime. Returns the master fd
   (or -1) and writes the child pid to PID_OUT. */
int pine_pty_spawn(const char *cmd, int rows, int cols, int *pid_out) {
    struct winsize ws = {0};
    ws.ws_row = (unsigned short) rows;
    ws.ws_col = (unsigned short) cols;
    int master = -1;
    pid_t pid = forkpty(&master, NULL, NULL, &ws);
    if (pid < 0) return -1;
    if (pid == 0) {
        setenv("TERM", "xterm-256color", 1);
        setenv("COLORTERM", "truecolor", 1);
        execl("/bin/sh", "/bin/sh", "-c", cmd, (char *) NULL);
        _exit(127);
    }
    *pid_out = (int) pid;
    return master;
}

void pine_pty_set_size(int fd, int rows, int cols) {
    struct winsize ws = {0};
    ws.ws_row = (unsigned short) rows;
    ws.ws_col = (unsigned short) cols;
    ioctl(fd, TIOCSWINSZ, &ws);
}
