pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Auto-scrolling engine for windows under the pointer via vpointer.py.
Singleton {
    id: root

    property bool running: false
    property real speed: 1.5        // multiplier: 0.2× to 8.0×
    property int dir: 1             // 1 = down, -1 = up
    property bool smooth: true      // fractional continuous axis vs discrete wheel
    property int intervalMs: 35     // timer tick (~28 fps)
    property string statusText: running ? (dir > 0 ? "прокрутка вниз ↓" : "прокрутка вверх ↑") : "остановлено"

    function toggle() {
        if (running)
            stop();
        else
            start();
    }

    function start() {
        if (!hand.running)
            hand.running = true;
        running = true;
    }

    function stop() {
        running = false;
    }

    function setSpeed(v) {
        speed = Math.max(0.2, Math.min(10.0, v));
    }

    function setDir(d) {
        dir = d >= 0 ? 1 : -1;
    }

    function setSmooth(s) {
        smooth = !!s;
    }

    Process {
        id: hand
        property bool ok: false
        running: true
        stdinEnabled: true
        command: ["python3", "-u", Quickshell.shellDir + "/scripts/vpointer.py"]
        onRunningChanged: if (!running)
            ok = false
        stdout: SplitParser {
            onRead: line => hand.ok = (line === "ready")
        }
        stderr: StdioCollector {}
    }

    Timer {
        id: ticker
        interval: root.intervalMs
        repeat: true
        running: root.running && hand.ok
        onTriggered: {
            if (!hand.ok)
                return;
            var step = root.smooth ? (root.speed * 0.12) : (root.speed >= 3.0 ? 2.0 : 1.0);
            var dy = (step * root.dir).toFixed(3);
            hand.write("wheel " + dy + " 0.0\n");
        }
    }
}
