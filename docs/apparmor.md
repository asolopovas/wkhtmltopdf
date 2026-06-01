---
layout: default
---

# AppArmor

Use AppArmor to reduce damage when wkhtmltopdf handles risky HTML. It is a backstop; still sanitize input and isolate filesystem, network, credentials, caches, and logs. SELinux is the Red Hat/Fedora equivalent.

## Enable

```bash
systemctl status apparmor
sudo systemctl enable --now apparmor
```

Install `apparmor` and `apparmor-utils` if needed.

## Minimal profile

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
  #include <abstractions/nameservice> # remove if network/DNS is unnecessary

  deny capability sys_ptrace,

  /proc/*/maps r,
  /usr/local/bin/wkhtmltopdf mr,
  /var/cache/fontconfig/* r,
  /var/tmp/wkhtmltopdf/** rwlk,

  /opt/example_worktree/** rwk,
}
```

## Denials

Check `journalctl` or `/var/log/audit/audit.log` for `apparmor="DENIED"`. Tighten the profile until expected rendering works and unexpected access fails.
