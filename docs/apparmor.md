---
layout: default
---

# AppArmor

AppArmor can reduce damage if wkhtmltopdf must process risky HTML. It is a backstop, not permission to trust untrusted input. Prefer trusted input; otherwise combine sanitization, process isolation, and filesystem/network restrictions.

AppArmor is common on Ubuntu, Debian, and SUSE. Red Hat/Fedora systems normally use SELinux instead.

## Enable AppArmor

```bash
systemctl status apparmor
sudo systemctl enable --now apparmor
```

The status should show AppArmor loaded and active. If the unit or `aa-status` is missing, install your distribution's `apparmor` and `apparmor-utils` packages first.

## Install a profile

1. Save a profile as `/etc/apparmor.d/usr.local.bin.wkhtmltopdf`.
2. Customize the allowed working paths.
3. Reload AppArmor: `sudo systemctl reload apparmor`.
4. Confirm it is loaded: `sudo aa-status`.

Example profile:

```apparmor
#include <tunables/global>

/usr/local/bin/wkhtmltopdf {
  #include <abstractions/base>
  #include <abstractions/fonts>
  #include <abstractions/openssl>

  # Remove if wkhtmltopdf does not need network or DNS access.
  #include <abstractions/nameservice>

  deny capability sys_ptrace,

  /proc/*/maps r,
  /usr/local/bin/wkhtmltopdf mr,
  /var/cache/fontconfig/* r,

  # Use a private temp directory; set TMPDIR for the wkhtmltopdf process.
  /var/tmp/wkhtmltopdf/** rwlk,

  # Replace with the minimal paths your app needs.
  /opt/example_worktree/** rwk,
  /opt/other_workspace/single_dir/* rwk,
}
```

## Check denials

AppArmor denials appear in the audit log, commonly through `journalctl` or `/var/log/audit/audit.log`:

```text
AVC apparmor="DENIED" operation="open" profile="/usr/local/bin/wkhtmltopdf" name="/etc/passwd" comm="wkhtmltopdf" requested_mask="r" denied_mask="r"
```

Tighten the profile until expected rendering works and unexpected filesystem or network access is denied.
