---
layout: default
---

# AppArmor

AppArmor can limit damage when wkhtmltopdf handles risky HTML. It is a backstop, not permission to trust input. Prefer trusted input; otherwise combine sanitization, process isolation, and filesystem/network limits. SELinux is the usual Red Hat/Fedora equivalent.

## Enable

```bash
systemctl status apparmor
sudo systemctl enable --now apparmor
```

Install `apparmor` and `apparmor-utils` if `aa-status` or the unit is missing.

## Profile

1. Save as `/etc/apparmor.d/usr.local.bin.wkhtmltopdf`.
2. Replace paths with the minimum your app needs.
3. Reload: `sudo systemctl reload apparmor`.
4. Verify: `sudo aa-status`.

```apparmor
#include <tunables/global>

/usr/local/bin/wkhtmltopdf {
  #include <abstractions/base>
  #include <abstractions/fonts>
  #include <abstractions/openssl>
  # Remove if network/DNS is unnecessary.
  #include <abstractions/nameservice>

  deny capability sys_ptrace,

  /proc/*/maps r,
  /usr/local/bin/wkhtmltopdf mr,
  /var/cache/fontconfig/* r,
  # Set TMPDIR here.
  /var/tmp/wkhtmltopdf/** rwlk,

  /opt/example_worktree/** rwk,
  /opt/other_workspace/single_dir/* rwk,
}
```

## Denials

Check `journalctl` or `/var/log/audit/audit.log` for `apparmor="DENIED"`. Tighten the profile until expected rendering works and unexpected access fails.
