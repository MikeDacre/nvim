# TYPE: config — machine and service configuration under version control

Configuration is code (branches, commits, changelog, review), and the tree **mirrors a live system**: a wrong file in the wrong place takes a service down or locks you out.

## Always
- The repo path mirrors the deploy path exactly (`layout.mirrors`: repo → target); never invent a directory the target lacks or reorganise for tidiness.
- Never edit a live system file in place: edit the repo copy, validate, deploy through the mirror's own command.
- Validate before deploying — every mirror names a `validate` command (`sshd -t`, `nginx -t`, `visudo -c`, ...); run it and show the output.
- Anything that can lock you out (sshd, firewall, PAM, sudoers, network, boot) is stop-and-ask, applied only with a second live session open on that host.
- `CLAUDE/` stays tracked in the main repo; the remote stays private unless project.json says `visibility: public` (making it public is a gate every time).
- No key, password, certificate or host credential in a tracked file: `project.yaml`, referenced from the config (§8).

## Layout
`subtype`: environment (a user's own machine — dotfiles, shell), host (one machine), provisioning (config shared across hosts), service (one daemon). A file's repo path is its path on the machine minus the mirror root:

    layout.mirrors: [{ "repo": "etc/nginx", "target": "/etc/nginx", "host": "web1",
                       "validate": "nginx -t", "reload": "sudo systemctl reload nginx" }]

Record every mirror before the first file lands in it.

## Workflow
1. Change the repo copy on a `feat/` or `fix/` branch.  2. Run `validate`; paste the output.
3. Deploy (rsync, symlink, or the project's script), then `reload`.  4. Confirm the service is up before closing.
5. `CHANGELOG.txt` records what changed on which host — the only history a future incident has.

## Hazards worth writing into project.json
Which hosts are live, which paths are symlinked into the running system, what reloads on write, and any file whose syntax error is fatal at boot rather than at reload.
