import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_cpuColor: cpuSwatch.color
    property alias cfg_gpuColor: gpuSwatch.color
    property alias cfg_downloadColor: downloadSwatch.color
    property alias cfg_uploadColor: uploadSwatch.color
    property alias cfg_trackColor: trackSwatch.color
    property alias cfg_updateInterval: intervalSpin.value
    property alias cfg_barLength: barLengthSpin.value
    property alias cfg_barThickness: barThicknessSpin.value
    property alias cfg_maxDownloadMbps: maxDownloadSpin.value
    property alias cfg_maxUploadMbps: maxUploadSpin.value
    property alias cfg_networkInterface: interfaceField.text
    property alias cfg_displayOrientation: orientationCombo.currentIndex

    component ColorRow: RowLayout {
        id: colorRow
        property alias color: swatch.color
        property alias dialog: colorDialog

        Rectangle {
            id: swatch
            width: Kirigami.Units.gridUnit * 1.6
            height: Kirigami.Units.gridUnit * 1.6
            radius: 4
            border.width: 1
            border.color: Kirigami.Theme.disabledTextColor

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: colorDialog.open()
            }
        }

        QQC2.Button {
            text: i18n("Choose…")
            onClicked: colorDialog.open()
        }

        ColorDialog {
            id: colorDialog
            options: ColorDialog.ShowAlphaChannel
            selectedColor: swatch.color
            onAccepted: swatch.color = selectedColor
        }
    }

    ColorRow {
        id: cpuSwatch
        Kirigami.FormData.label: i18n("CPU used color:")
    }

    ColorRow {
        id: gpuSwatch
        Kirigami.FormData.label: i18n("GPU used color:")
    }

    ColorRow {
        id: downloadSwatch
        Kirigami.FormData.label: i18n("Download color:")
    }

    ColorRow {
        id: uploadSwatch
        Kirigami.FormData.label: i18n("Upload color:")
    }

    ColorRow {
        id: trackSwatch
        Kirigami.FormData.label: i18n("Unused bar (track) color:")
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
    }

    QQC2.SpinBox {
        id: intervalSpin
        Kirigami.FormData.label: i18n("Update interval (seconds):")
        from: 1
        to: 60
        stepSize: 1
    }

    QQC2.SpinBox {
        id: barLengthSpin
        Kirigami.FormData.label: i18n("Panel bar length (px):")
        from: 30
        to: 300
        stepSize: 10
    }

    QQC2.SpinBox {
        id: barThicknessSpin
        Kirigami.FormData.label: i18n("Panel bar thickness (px):")
        from: 2
        to: 40
        stepSize: 1
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
    }

    QQC2.SpinBox {
        id: maxDownloadSpin
        Kirigami.FormData.label: i18n("Max download speed (Mbps):")
        from: 1
        to: 100000
        stepSize: 10
        editable: true
    }

    QQC2.SpinBox {
        id: maxUploadSpin
        Kirigami.FormData.label: i18n("Max upload speed (Mbps):")
        from: 1
        to: 100000
        stepSize: 5
        editable: true
    }

    QQC2.TextField {
        id: interfaceField
        Kirigami.FormData.label: i18n("Network interface (blank = auto-detect):")
        placeholderText: i18n("e.g. wlan0, enp3s0 — leave blank for default route")
    }

    QQC2.ComboBox {
        id: orientationCombo
        Kirigami.FormData.label: i18n("Bar orientation:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: i18n("Auto (Follow panel orientation)"), value: 0 },
            { text: i18n("Always Horizontal"), value: 1 },
            { text: i18n("Always Vertical"), value: 2 }
        ]
    }
}
