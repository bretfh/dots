# authorized-keys/

Public keys checked in here so `lab/prelude.scm` can `local-file` them
into every lab VM's `openssh-service-type` config.

## bfh.pub — required before `guix system image` works

You don't have an SSH key pair yet. Generate one and copy the pubkey here:

```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
cp ~/.ssh/id_ed25519.pub ~/dots/authorized-keys/bfh.pub
```

`lab/prelude.scm` reads `~/dots/authorized-keys/bfh.pub` at OS-expression
time. Until that file exists with non-zero size, building any lab VM
image will fail.
