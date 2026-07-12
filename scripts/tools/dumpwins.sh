#!/usr/bin/env bash
# Dump all KWin windows (caption, geometry, output) via a transient KWin script.
set -euo pipefail
js=$(mktemp --suffix=.js)
cat > "$js" <<'EOF'
for (const w of workspace.windowList()) {
    print("DUMPWIN|" + w.resourceClass + "|" + w.caption + "|" + w.frameGeometry.x + "," + w.frameGeometry.y + " " + w.frameGeometry.width + "x" + w.frameGeometry.height + "|" + (w.output ? w.output.name : "?") + "|layer=" + w.layer);
}
EOF
mark=$(date +%s.%N)
num=$(busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting loadScript ss "$js" "dumpwins$$" | awk '{print $2}')
busctl --user call org.kde.KWin /Scripting/Script$num org.kde.kwin.Script run >/dev/null
sleep 0.5
busctl --user call org.kde.KWin /Scripting/Script$num org.kde.kwin.Script stop >/dev/null
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting unloadScript s "dumpwins$$" >/dev/null 2>&1 || true
journalctl --user -u plasma-kwin_wayland --since "@$mark" --no-pager -o cat | grep "DUMPWIN|" || echo "no output captured"
rm -f "$js"
