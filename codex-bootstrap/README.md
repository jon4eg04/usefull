# Codex server bootstrap

One-command bootstrap for the shared Codex environment used on client servers.

It installs:

- Superpowers into `/opt/superpowers`;
- the pinned Superpowers release defined in `install.sh`;
- the global policy from this folder into `/etc/codex/AGENTS.md`;
- native skill symlinks for `root` and `dev`;
- global AGENTS.md symlinks for `root` and `dev`.

Run only after the `dev` Linux user exists:

```bash
curl -fsSL https://raw.githubusercontent.com/jon4eg04/usefull/main/codex-bootstrap/install.sh | bash
```

The installer is designed to be rerunnable. It refuses to delete a real file/directory that conflicts with a managed symlink and refuses to overwrite a modified or unexpected `/opt/superpowers` checkout.

`auth.json`, ChatGPT credentials, Codex sessions, and other per-user state are never shared between `root` and `dev`.

To roll Superpowers forward, review the new upstream release and then change `SUPERPOWERS_REF` in `install.sh`. New installations will use that pinned release.
