# MODE: config — machine and service configuration under version control

Configuration is code: same branches, same commits, same changelog, same
review. What differs is that this tree is a **mirror of a live system**. A
wrong file in the wrong place does not fail a test — it takes a service down,
or locks you out of the host.

## Always
- The repo path mirrors the deploy path exactly. `layout.mirrors` in project.json maps repo -> target; never invent a directory the target does not have, and never reorganise the tree for tidiness.
- Never edit a live system file in place. Edit the repo copy, validate, then deploy through the mirror's own command.
- Validate before deploying. Every mirror entry names a `validate` command (`sshd -t`, `nginx -t`, `visudo -c`, `systemd-analyze verify`); run it and show the output.
- A change that can lock you out — sshd, firewall, PAM, sudoers, network, boot — is stop-and-ask, and it is applied only with a second live session already open on that host.
- `CLAUDE/` is tracked in the main repo, never a subrepo: a config repo is private already and a second remote is one more thing to forget.
- The remote stays **private** unless project.json records `visibility: public`. Making one public is an approval gate every time (CLAUDE.md §3).
- No key, password, certificate, or host-specific credential in a tracked file. It lives in `priv/` and the config references it (§8).

## Layout
`subtype` records the scope: `dotfiles` (a user's own environment), `host`
(one machine), `server` (services on a fleet), `service` (one daemon).

The tree is the target's tree. A file's path in the repo is its path on the
machine, minus the mirror root:

    layout.mirrors: [
      { "repo": "etc/nginx", "target": "/etc/nginx", "host": "web1",
        "validate": "nginx -t", "reload": "sudo systemctl reload nginx" }
    ]

Record every mirror before the first file lands in it. An unmapped file in
this repo is a file nobody knows where to install.

## Workflow
1. Change the repo copy on a `feat/` or `fix/` branch.
2. Run the mirror's `validate`. Paste the output into the session.
3. Deploy (rsync, symlink, or the project's own script), then `reload`.
4. Confirm the service is actually up before committing the session closed.
5. `CHANGELOG.txt` records what changed on which host — that log is the only
   history a future incident has.

## Hazards worth writing into project.json
Which hosts are live, which paths are symlinked into the running system,
anything that reloads on write, and any file whose syntax error is fatal at
boot rather than at reload.
