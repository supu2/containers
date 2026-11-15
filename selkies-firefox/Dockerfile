# syntax=docker/dockerfile:1
#
# Selkies + Firefox that opens a URL straight from the browser address bar:
#
#   https://remote.proxy.incloudy.com.tr/?app=firefox&url=https%3A%2F%2Fgoogle.com
#
# How it works
#   1. nginx (already in the Selkies base image) serves the normal web client.
#      For page loads that carry ?app= or ?url= it also *mirrors* the request,
#      in the background, to a unix socket. The page is never delayed or changed.
#   2. /usr/local/bin/app-launcher listens on that socket. It runs inside the
#      desktop session (started from autostart), so Firefox inherits the right
#      DISPLAY / WAYLAND_DISPLAY / D-Bus and "firefox --new-tab URL" reuses the
#      running window instead of fighting over the profile lock.
#   3. Only http(s) URLs and apps from the APPS table are accepted.
#
# Build:  docker build -t selkies-firefox .        (needs BuildKit, Docker 23+)
# Run:    docker run -d --name selkies-firefox --shm-size=1gb \
#             -p 3000:3000 -v selkies-config:/config selkies-firefox

FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie

ENV TITLE="Firefox" \
    PIXELFLUX_WAYLAND="true" \
    LAUNCH_DEFAULT_APP="firefox" \
    LAUNCH_AUTOSTART="" \
    LAUNCH_ALLOWED_HOSTS="" \
    LAUNCH_DEDUP_SECONDS="10"

# ---------------------------------------------------------------------------
# Firefox (nginx, python3 and dbus-x11 already ship in the base image)
# ---------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      firefox-esr \
      fonts-liberation \
      fonts-noto-core && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

# Skip the first-run / welcome tabs so the requested URL is the only thing that
# opens. Debian reads /etc/firefox/policies; the install-dir copy is a fallback.
COPY <<'EOF' /etc/firefox/policies/policies.json
{
  "policies": {
    "DisableAppUpdate": true,
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DontCheckDefaultBrowser": true,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "UserMessaging": {
      "WhatsNew": false,
      "ExtensionRecommendations": false,
      "FeatureRecommendations": false,
      "UrlbarInterventions": false,
      "SkipOnboarding": true
    }
  }
}
EOF
RUN mkdir -p /usr/lib/firefox-esr/distribution && \
    cp /etc/firefox/policies/policies.json /usr/lib/firefox-esr/distribution/policies.json && \
    echo 'pref("security.sandbox.warn_unprivileged_namespaces", false);' >> /etc/firefox-esr/firefox-esr.js

# ---------------------------------------------------------------------------
# The launcher (runs in the session, listens on a unix socket)
# ---------------------------------------------------------------------------
COPY --chmod=0755 <<'LAUNCHER_PY' /usr/local/bin/app-launcher
#!/usr/bin/env python3
"""Opens apps inside the running Selkies desktop session.

nginx mirrors page loads of /?app=firefox&url=... to the unix socket below.
Responses are ignored by nginx, so errors are only visible in the log:
    /tmp/app-launcher.log
"""
import os
import shlex
import socketserver
import subprocess
import sys
import threading
import time
import urllib.parse
from fnmatch import fnmatch
from http.server import BaseHTTPRequestHandler

SOCKET_PATH = "/tmp/app-launcher.sock"   # must match the nginx patch below
LOG_FILE = "/tmp/app-launcher.log"
MAX_URL_LEN = 2048

DEFAULT_APP = (os.environ.get("LAUNCH_DEFAULT_APP") or "firefox").strip().lower()
AUTOSTART = (os.environ.get("LAUNCH_AUTOSTART") or "").strip().lower()
DEDUP_SECONDS = float(os.environ.get("LAUNCH_DEDUP_SECONDS") or 10)
ALLOWED_HOSTS = [
    h.strip().lower()
    for h in (os.environ.get("LAUNCH_ALLOWED_HOSTS") or "").split(",")
    if h.strip()
]
FIREFOX = os.environ.get("FIREFOX_BIN") or "/usr/bin/firefox-esr"

# Allowlist of launchable apps: name -> function(url or None) -> argv.
# To support another app, add an entry here (and install it in the image).
APPS = {
    "firefox": lambda url: [FIREFOX, "--new-tab", url] if url else [FIREFOX],
}


class Rejected(Exception):
    pass


def log(msg):
    line = time.strftime("%Y-%m-%d %H:%M:%S ") + msg
    print(line, file=sys.stderr, flush=True)
    try:
        with open(LOG_FILE, "a") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def check_url(raw):
    """Accept only plain http(s) URLs. Never hand anything else to the browser."""
    if len(raw) > MAX_URL_LEN:
        raise Rejected("url too long")
    # Backslashes: browsers read them as "/", Python does not -> parser mismatch.
    if "\\" in raw or any(c.isspace() or ord(c) < 32 or ord(c) == 127 for c in raw):
        raise Rejected("url contains forbidden characters")
    try:
        parts = urllib.parse.urlsplit(raw)
        host = (parts.hostname or "").lower()
    except ValueError:
        raise Rejected("malformed url")
    if parts.scheme.lower() not in ("http", "https"):
        raise Rejected("only http and https urls are allowed")
    if not host or "@" in parts.netloc:
        raise Rejected("url needs a host and must not contain credentials")
    if ALLOWED_HOSTS and not any(
        host == h or host.endswith("." + h) or fnmatch(host, h) for h in ALLOWED_HOSTS
    ):
        raise Rejected("host not allowed: " + host)
    return raw


_recent = {}
_lock = threading.Lock()


def is_repeat(key):
    """Reloading the page re-sends the request; ignore identical ones for a while."""
    now = time.monotonic()
    with _lock:
        for k in [k for k, t in _recent.items() if now - t > DEDUP_SECONDS]:
            del _recent[k]
        if key in _recent:
            return True
        _recent[key] = now
        return False


def spawn(argv):
    log("start " + " ".join(shlex.quote(a) for a in argv))
    proc = subprocess.Popen(
        argv,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    threading.Thread(target=proc.wait, daemon=True).start()  # reap, no zombies


def launch(query):
    params = urllib.parse.parse_qs(query)
    if "app" not in params and "url" not in params:
        return
    app = (params.get("app") or [DEFAULT_APP])[0].strip().lower()
    url = (params.get("url") or [None])[0]
    if app not in APPS:
        raise Rejected("unknown app: %r" % app[:40])
    if url is not None:
        url = check_url(url)
    if is_repeat((app, url)):
        log("ignored repeat: %s %s" % (app, url or ""))
        return
    spawn(APPS[app](url))


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, *args):
        pass

    def address_string(self):
        return "unix"

    def handle_request(self):
        status = 200
        try:
            launch(urllib.parse.urlsplit(self.path).query)
        except Rejected as exc:
            log("rejected: %s" % exc)
            status = 400
        except Exception as exc:
            log("error: %r" % (exc,))
            status = 500
        self.send_response(status)
        self.send_header("Content-Length", "0")
        self.end_headers()

    do_GET = do_HEAD = handle_request


class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True


def main():
    try:
        os.unlink(SOCKET_PATH)  # stale socket after "docker restart"
    except FileNotFoundError:
        pass
    old_umask = os.umask(0)
    try:
        server = Server(SOCKET_PATH, Handler)
    finally:
        os.umask(old_umask)
    os.chmod(SOCKET_PATH, 0o666)  # nginx workers run as another user

    if AUTOSTART == "firefox":
        spawn([FIREFOX] + shlex.split(os.environ.get("FIREFOX_CLI", "")))

    log("listening on " + SOCKET_PATH)
    server.serve_forever()


if __name__ == "__main__":
    main()
LAUNCHER_PY

# Wayland sessions (labwc) have no D-Bus session bus by default, and Firefox needs
# one to hand a URL to an already-running instance. X11 sessions already have one.
COPY --chmod=0755 <<'EOF' /usr/local/bin/session-start
#!/bin/bash
LAUNCHER=/usr/local/bin/app-launcher
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session -- "${LAUNCHER}"
  elif command -v dbus-launch >/dev/null 2>&1; then
    exec dbus-launch --exit-with-session "${LAUNCHER}"
  fi
fi
exec "${LAUNCHER}"
EOF

# The base image runs these on login. They are copied into /config on first run
# only: if you reuse a /config volume from another Selkies container, delete
# /config/.config/labwc/autostart and /config/.config/openbox/autostart once.
COPY --chmod=0755 <<'EOF' /defaults/autostart_wayland
#!/bin/bash
/usr/local/bin/session-start
EOF
COPY --chmod=0755 <<'EOF' /defaults/autostart
#!/bin/bash
/usr/local/bin/session-start
EOF

# ---------------------------------------------------------------------------
# nginx: mirror "/?app=..." / "/?url=..." page loads to the launcher socket.
# The base image renders /defaults/default.conf at every start (copy + sed), so
# patch the template here. The build FAILS if the template ever changes shape,
# instead of silently losing the feature.
# ---------------------------------------------------------------------------
COPY <<'NGINX_PATCH_PY' /tmp/patch-nginx.py
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "/defaults/default.conf"
conf = open(path).read()

# init-nginx rewrites the file with sed, so inserted text must not contain:
#   - the hash character (stripped everywhere when PASSWORD is set)
#   - the digits 3000 / 3001 or the token CWS (replaced by port settings)
# SUBFOLDER is intentional: init-nginx swaps it for the configured sub-path.
MAP = r'''map $request_uri $app_launch_requested {
  default 0;
  "~^SUBFOLDER\?([^ ]*&)?(app|url)=" 1;
}

'''

LOCATIONS = r'''  location = SUBFOLDER {
    mirror /_app_launch;
    mirror_request_body off;
    alias /usr/share/selkies/web/;
    index index.html;
  }
  location = /_app_launch {
    internal;
    if ($app_launch_requested = 0) {
      return 204;
    }
    proxy_pass http://unix:/tmp/app-launcher.sock:$request_uri;
    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
    proxy_set_header Host localhost;
    proxy_connect_timeout 2s;
    proxy_read_timeout 5s;
  }
'''

for bad in ("#", "3000", "3001", "CWS"):
    assert bad not in MAP + LOCATIONS, "forbidden text in nginx patch: " + bad

anchor = re.compile(r"^  location SUBFOLDER \{$", re.M)
conf, count = anchor.subn(lambda m: LOCATIONS + m.group(0), conf)
if count != 2:  # one server block for HTTP, one for HTTPS
    sys.exit("nginx template changed (found %d anchors, expected 2): update the patch" % count)

open(path, "w").write(MAP + conf)
print("patched %s (%d server blocks)" % (path, count))
NGINX_PATCH_PY

RUN python3 /tmp/patch-nginx.py /defaults/default.conf && rm -f /tmp/patch-nginx.py

EXPOSE 3000 3001
VOLUME /config