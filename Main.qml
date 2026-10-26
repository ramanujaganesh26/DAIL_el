import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Dual_dial

ApplicationWindow {
    id: window
    width: 860
    height: 640
    minimumWidth: 780
    maximumWidth: 1050
    minimumHeight: 580
    maximumHeight: 800
    visible: true
    title: qsTr("Dual Dial Controller")

    property real azimuthAngle: 45.0      // 0.0 to 360.0 degrees
    property real elevationAngle: 15.0    // -10.0 to +85.0 degrees

    // Telemetry Receiver instance (COM, TCP, UDP)
    TelemetryReceiver {
        id: telemetryRx

        onTelemetryReceived: function(az, el) {
            window.azimuthAngle = az;
            window.elevationAngle = el;
        }
    }

    // Clean White / Light Background
    background: Rectangle {
        color: "#f8fafc"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // Top Simple & Clean Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Column {
                spacing: 2
                Text {
                    text: "Dual Dial Controller"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    font.family: "Segoe UI, sans-serif"
                    color: "#0f172a"
                }
                Text {
                    text: "Azimuth (0° to 360°) & Elevation (-10° to +85°) Multi-Port Receiver"
                    font.pixelSize: 12
                    font.family: "Segoe UI, sans-serif"
                    color: "#64748b"
                }
            }

            Item { Layout.fillWidth: true }

            // Connection Status Indicator
            Rectangle {
                Layout.preferredHeight: 30
                Layout.preferredWidth: 115
                radius: 15
                color: telemetryRx.isConnected ? "#ecfdf5" : "#f1f5f9"
                border.color: telemetryRx.isConnected ? "#a7f3d0" : "#cbd5e1"
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: telemetryRx.isConnected ? "#10b981" : "#94a3b8"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: telemetryRx.isConnected ? "Connected" : "Disconnected"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.family: "Segoe UI, sans-serif"
                        color: telemetryRx.isConnected ? "#047857" : "#64748b"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Simple Reset Button
            Button {
                id: resetBtn
                implicitWidth: 80
                implicitHeight: 30
                text: "Reset"

                contentItem: Text {
                    text: resetBtn.text
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.family: "Segoe UI, sans-serif"
                    color: resetBtn.down ? "#ffffff" : "#334155"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: resetBtn.down ? "#2563eb" : (resetBtn.hovered ? "#f1f5f9" : "#ffffff")
                    border.color: "#cbd5e1"
                    border.width: 1
                    radius: 6
                }

                onClicked: {
                    window.azimuthAngle = 0.0;
                    window.elevationAngle = 0.0;
                }
            }
        }

        // Center Dials: Clean White Cards
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Azimuth Dial Card
            AzimuthDial {
                Layout.fillWidth: true
                Layout.fillHeight: true
                angle: window.azimuthAngle
                onAngleChangedByUser: function(newA) {
                    window.azimuthAngle = newA;
                }
            }

            // Elevation Dial Card
            ElevationDial {
                Layout.fillWidth: true
                Layout.fillHeight: true
                angle: window.elevationAngle
                onAngleChangedByUser: function(newA) {
                    window.elevationAngle = newA;
                }
            }
        }

        // Bottom Telemetry & Port Control
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 210
            color: "#ffffff"
            border.color: "#e2e8f0"
            border.width: 1
            radius: 8

            TelemetryTable {
                anchors.fill: parent
                anchors.margins: 10
                receiver: telemetryRx

                onTargetAnglesSelected: function(az, el) {
                    window.azimuthAngle = az;
                    window.elevationAngle = el;
                }
            }
        }
    }
}
