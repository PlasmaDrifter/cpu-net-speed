import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property real cpuPercent: 0
    property real gpuPercent: 0
    property real downloadMbps: 0
    property real uploadMbps: 0

    property var prevCpu: null   // { total, idle }
    property var prevNet: null   // { rx, tx, time, iface }

    readonly property color cpuColor: plasmoid.configuration.cpuColor
    readonly property color gpuColor: plasmoid.configuration.gpuColor
    readonly property color downloadColor: plasmoid.configuration.downloadColor
    readonly property color uploadColor: plasmoid.configuration.uploadColor
    readonly property color trackColor: plasmoid.configuration.trackColor

    readonly property real maxDownloadMbps: plasmoid.configuration.maxDownloadMbps
    readonly property real maxUploadMbps: plasmoid.configuration.maxUploadMbps

    toolTipMainText: ""
    toolTipSubText: ""

    function formatMbps(mbps) {
        if (mbps >= 1000) return (mbps / 1000).toFixed(2) + " Gbps"
        return mbps.toFixed(1) + " Mbps"
    }

    function parseCpuLine(line) {
        // "cpu  user nice system idle iowait irq softirq steal guest guest_nice"
        var parts = line.trim().split(/\s+/)
        if (parts.length < 5 || parts[0] !== "cpu") return null
        var user = parseFloat(parts[1]) || 0
        var nice = parseFloat(parts[2]) || 0
        var system = parseFloat(parts[3]) || 0
        var idle = parseFloat(parts[4]) || 0
        var iowait = parseFloat(parts[5]) || 0
        var irq = parseFloat(parts[6]) || 0
        var softirq = parseFloat(parts[7]) || 0
        var steal = parseFloat(parts[8]) || 0
        var idleAll = idle + iowait
        var total = user + nice + system + idle + iowait + irq + softirq + steal
        return { total: total, idle: idleAll }
    }

    function parseNetDev(text, ifaceName) {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            var colonIdx = line.indexOf(":")
            if (colonIdx < 0) continue
            var name = line.substring(0, colonIdx).trim()
            if (name !== ifaceName) continue
            var rest = line.substring(colonIdx + 1).trim().split(/\s+/)
            if (rest.length < 9) continue
            return { rx: parseFloat(rest[0]) || 0, tx: parseFloat(rest[8]) || 0 }
        }
        return null
    }

    function parseDefaultIface(text) {
        // "default via 192.168.1.1 dev wlan0 proto dhcp metric 600"
        var match = text.match(/\sdev\s+(\S+)/)
        return match ? match[1] : ""
    }

    function handleOutput(text) {
        var sections = text.split("###SPLIT###")
        if (sections.length < 4) return

        var cpuSection = sections[0].trim()
        var gpuSection = sections[1].trim()
        var netSection = sections[2]
        var routeSection = sections[3].trim()

        // --- CPU ---
        var cpuLine = cpuSection.split("\n")[0]
        var cur = parseCpuLine(cpuLine)
        if (cur) {
            if (prevCpu) {
                var deltaTotal = cur.total - prevCpu.total
                var deltaIdle = cur.idle - prevCpu.idle
                if (deltaTotal > 0) {
                    cpuPercent = Math.max(0, Math.min(100, 100 * (deltaTotal - deltaIdle) / deltaTotal))
                }
            }
            prevCpu = cur
        }

        // --- GPU ---
        var gpuValue = parseInt(gpuSection)
        if (!isNaN(gpuValue)) {
            gpuPercent = Math.max(0, Math.min(100, gpuValue))
        }

        // --- Network ---
        var configuredIface = plasmoid.configuration.networkInterface
        var iface = configuredIface && configuredIface.length > 0
            ? configuredIface
            : parseDefaultIface(routeSection)

        if (iface) {
            var netNow = parseNetDev(netSection, iface)
            var now = Date.now()
            if (netNow) {
                if (prevNet && prevNet.iface === iface) {
                    var deltaSec = (now - prevNet.time) / 1000
                    var deltaRx = netNow.rx - prevNet.rx
                    var deltaTx = netNow.tx - prevNet.tx
                    if (deltaSec > 0 && deltaRx >= 0 && deltaTx >= 0) {
                        downloadMbps = (deltaRx * 8 / 1000000) / deltaSec
                        uploadMbps = (deltaTx * 8 / 1000000) / deltaSec
                    }
                }
                prevNet = { rx: netNow.rx, tx: netNow.tx, time: now, iface: iface }
            }
        }
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            var stdout = data["stdout"]
            if (stdout) {
                root.handleOutput(stdout)
            }
            disconnectSource(sourceName)
        }
        function exec(cmd) {
            connectSource(cmd)
        }
    }

    readonly property string pollCommand:
        "cat /proc/stat | head -n1; echo '###SPLIT###'; cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null || echo 0; echo '###SPLIT###'; cat /proc/net/dev; echo '###SPLIT###'; ip route show default 2>/dev/null | head -n1"

    Timer {
        interval: (plasmoid.configuration.updateInterval || 2) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: executable.exec(root.pollCommand)
    }

    component StatBar: ColumnLayout {
        id: barRoot
        property string label: ""
        property string valueText: ""
        property real ratio: 0
        property color barColor: "#ff2fc0"

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing / 2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: barRoot.label
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            PlasmaComponents3.Label {
                text: barRoot.valueText
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 0.55
            radius: height / 2
            color: root.trackColor

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: parent.radius
                color: barRoot.barColor
                width: Math.max(0, Math.min(1, barRoot.ratio)) * parent.width

                Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    fullRepresentation: ColumnLayout {
        id: fullRepItem
        readonly property var appletInterface: Plasmoid.self

        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        Layout.preferredWidth: plasmoid.configuration.popupWidth
        Layout.preferredHeight: plasmoid.configuration.popupHeight
        Layout.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing * 2

        onWidthChanged: {
            if (plasmoid.expanded && width >= Layout.minimumWidth && width !== plasmoid.configuration.popupWidth) {
                plasmoid.configuration.popupWidth = width;
            }
        }
        onHeightChanged: {
            if (plasmoid.expanded && height >= Layout.minimumHeight && height !== plasmoid.configuration.popupHeight) {
                plasmoid.configuration.popupHeight = height;
            }
        }

        StatBar {
            label: "CPU"
            valueText: root.cpuPercent.toFixed(0) + "%"
            ratio: root.cpuPercent / 100
            barColor: root.cpuColor
        }

        StatBar {
            label: "GPU"
            valueText: root.gpuPercent.toFixed(0) + "%"
            ratio: root.gpuPercent / 100
            barColor: root.gpuColor
        }

        StatBar {
            label: "Download"
            valueText: root.formatMbps(root.downloadMbps)
            ratio: root.maxDownloadMbps > 0 ? root.downloadMbps / root.maxDownloadMbps : 0
            barColor: root.downloadColor
        }

        StatBar {
            label: "Upload"
            valueText: root.formatMbps(root.uploadMbps)
            ratio: root.maxUploadMbps > 0 ? root.uploadMbps / root.maxUploadMbps : 0
            barColor: root.uploadColor
        }
    }

    // Small icon-style bars used when the plasmoid sits in a panel.
    compactRepresentation: Item {
        id: compact

        readonly property bool isPanelVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property bool isVerticalLayout: {
            var opt = plasmoid.configuration.displayOrientation;
            if (opt === 1) return false;
            if (opt === 2) return true;
            return compact.isPanelVertical;
        }

        readonly property int barThickness: plasmoid.configuration.barThickness
        readonly property int barGap: 3
        readonly property int margin: 4
        readonly property int barLength: plasmoid.configuration.barLength

        Layout.fillWidth: compact.isPanelVertical
        Layout.preferredWidth: {
            if (compact.isPanelVertical) {
                return -1;
            }
            if (compact.isVerticalLayout) {
                return compact.barThickness * 4 + compact.barGap * 3 + compact.margin * 2;
            } else {
                return compact.barLength;
            }
        }
        Layout.minimumWidth: Layout.preferredWidth

        Layout.fillHeight: !compact.isPanelVertical
        Layout.preferredHeight: {
            if (!compact.isPanelVertical) {
                return -1;
            }
            if (compact.isVerticalLayout) {
                return compact.barLength;
            } else {
                return compact.barThickness * 4 + compact.barGap * 3 + compact.margin * 2;
            }
        }
        Layout.minimumHeight: Layout.preferredHeight

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }

        // Horizontal layout (horizontal bars, stacked):
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - compact.margin * 2
            spacing: compact.barGap
            visible: !compact.isVerticalLayout

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: compact.barThickness
                radius: height / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.cpuColor
                    width: Math.max(0, Math.min(1, root.cpuPercent / 100)) * parent.width
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: compact.barThickness
                radius: height / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.gpuColor
                    width: Math.max(0, Math.min(1, root.gpuPercent / 100)) * parent.width
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: compact.barThickness
                radius: height / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.downloadColor
                    width: root.maxDownloadMbps > 0
                        ? Math.max(0, Math.min(1, root.downloadMbps / root.maxDownloadMbps)) * parent.width
                        : 0
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: compact.barThickness
                radius: height / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.uploadColor
                    width: root.maxUploadMbps > 0
                        ? Math.max(0, Math.min(1, root.uploadMbps / root.maxUploadMbps)) * parent.width
                        : 0
                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }
        }

        // Vertical layout (vertical bars, side-by-side):
        RowLayout {
            anchors.centerIn: parent
            height: parent.height - compact.margin * 2
            spacing: compact.barGap
            visible: compact.isVerticalLayout

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: compact.barThickness
                radius: width / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.cpuColor
                    height: Math.max(0, Math.min(1, root.cpuPercent / 100)) * parent.height
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: compact.barThickness
                radius: width / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.gpuColor
                    height: Math.max(0, Math.min(1, root.gpuPercent / 100)) * parent.height
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: compact.barThickness
                radius: width / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.downloadColor
                    height: root.maxDownloadMbps > 0
                        ? Math.max(0, Math.min(1, root.downloadMbps / root.maxDownloadMbps)) * parent.height
                        : 0
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: compact.barThickness
                radius: width / 2
                color: root.trackColor
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    radius: parent.radius
                    color: root.uploadColor
                    height: root.maxUploadMbps > 0
                        ? Math.max(0, Math.min(1, root.uploadMbps / root.maxUploadMbps)) * parent.height
                        : 0
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
