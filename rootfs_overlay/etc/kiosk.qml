// Fullscreen kiosk shell: a single QtWebEngineView pointed at the
// local Phoenix endpoint. Loaded by `qmlscene` from BabyFirmware.Kiosk
// after Phoenix has started.
//
// Run with:
//   QT_QPA_PLATFORM=linuxfb \
//     qmlscene -fullscreen /etc/kiosk.qml
//
// QtWebEngine renders into the linuxfb QPA platform plugin which
// writes pixels directly to /dev/fb0. The firmware (start.elf) drives
// the DSI panel, so /dev/fb0 == the touchscreen.

import QtQuick 2.12
import QtQuick.Window 2.12
import QtWebEngine 1.10

Window {
    visible: true
    visibility: Window.FullScreen
    color: "black"

    WebEngineView {
        anchors.fill: parent
        url: "http://127.0.0.1:4000"

        // Reload on connection failure so a slow Phoenix boot doesn't
        // leave the kiosk stuck on an error page.
        onLoadingChanged: function(info) {
            if (info.status === WebEngineView.LoadFailedStatus) {
                reloadTimer.start()
            }
        }
    }

    Timer {
        id: reloadTimer
        interval: 2000
        repeat: false
        onTriggered: parent.children[0].reload()
    }
}
