import QtQuick
import Quickshell
import Quickshell.Io
import "."

// IPC handler for slow-scroll / autoscroll:
//   qs -c angelos ipc call autoscroll <toggle|start|stop|status>
Item {
    id: root

    property var plugin

    IpcHandler {
        target: "autoscroll"

        function toggle(): string {
            AutoScroll.toggle();
            return AutoScroll.running ? "running" : "stopped";
        }

        function start(): string {
            AutoScroll.start();
            return "running";
        }

        function stop(): string {
            AutoScroll.stop();
            return "stopped";
        }

        function setSpeed(v: real): string {
            AutoScroll.setSpeed(v);
            return String(AutoScroll.speed);
        }

        function setDir(d: int): string {
            AutoScroll.setDir(d);
            return AutoScroll.dir > 0 ? "down" : "up";
        }

        function status(): string {
            return JSON.stringify({
                "running": AutoScroll.running,
                "speed": AutoScroll.speed,
                "dir": AutoScroll.dir,
                "smooth": AutoScroll.smooth
            });
        }
    }
}
