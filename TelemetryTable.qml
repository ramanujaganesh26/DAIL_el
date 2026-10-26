import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Item {
    id: root

    required property var receiver

    signal targetAnglesSelected(real az, real el)

    implicitWidth: 780
    implicitHeight: 210

    ListModel {
        id: packetModel
    }

    Connections {
        target: root.receiver

        function onPacketLogged(timeStr, channel, hexStr, asciiStr, az, el, ok) {
            packetModel.insert(0, {
                "timestamp": timeStr,
                "channel": channel,
                "hexData": hexStr,
                "azimuth": az.toFixed(1) + "°",
                "elevation": ((el > 0) ? "+" : "") + el.toFixed(1) + "°",
                "azRaw": az,
                "elRaw": el,
                "valid": ok
            });

            if (packetModel.count > 100) {
                packetModel.remove(100);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Simple Toolbar: Port Configuration
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Port:"
                font.pixelSize: 12
                font.family: "Segoe UI, sans-serif"
                color: "#475569"
            }

            ComboBox {
                id: protocolCombo
                Layout.preferredWidth: 105
                Layout.preferredHeight: 28
                model: ["Serial COM", "UDP", "TCP Client", "TCP Server"]
                currentIndex: 0

                onCurrentIndexChanged: {
                    if (currentIndex === 0) root.receiver.connectionType = "COM";
                    else if (currentIndex === 1) root.receiver.connectionType = "UDP";
                    else if (currentIndex === 2) root.receiver.connectionType = "TCP_CLIENT";
                    else if (currentIndex === 3) root.receiver.connectionType = "TCP_SERVER";
                }

                background: Rectangle {
                    color: "#f8fafc"
                    border.color: "#cbd5e1"
                    border.width: 1
                    radius: 5
                }

                contentItem: Text {
                    leftPadding: 8
                    text: protocolCombo.displayText
                    font.pixelSize: 11
                    font.family: "Segoe UI, sans-serif"
                    color: "#0f172a"
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Serial Port Controls
            Row {
                spacing: 6
                visible: protocolCombo.currentIndex === 0

                ComboBox {
                    id: portCombo
                    width: 78
                    height: 28
                    model: root.receiver.availablePorts
                    currentIndex: 0

                    onCurrentTextChanged: {
                        if (currentText !== "") root.receiver.portName = currentText;
                    }

                    background: Rectangle { color: "#f8fafc"; border.color: "#cbd5e1"; border.width: 1; radius: 5 }
                    contentItem: Text { leftPadding: 8; text: portCombo.displayText; font.pixelSize: 11; font.family: "Segoe UI, sans-serif"; color: "#0f172a"; verticalAlignment: Text.AlignVCenter }
                }

                Button {
                    id: refreshBtn
                    width: 28
                    height: 28
                    text: "🔄"
                    background: Rectangle { color: refreshBtn.down ? "#e2e8f0" : "#f8fafc"; border.color: "#cbd5e1"; border.width: 1; radius: 5 }
                    onClicked: root.receiver.refreshPorts()
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Baud:"
                    font.pixelSize: 12
                    font.family: "Segoe UI, sans-serif"
                    color: "#475569"
                }

                ComboBox {
                    id: baudCombo
                    width: 84
                    height: 28
                    model: [9600, 19200, 38400, 57600, 115200, 230400, 921600]
                    currentIndex: 4 // 115200

                    onCurrentValueChanged: {
                        root.receiver.baudRate = model[currentIndex];
                    }

                    background: Rectangle { color: "#f8fafc"; border.color: "#cbd5e1"; border.width: 1; radius: 5 }
                    contentItem: Text { leftPadding: 8; text: baudCombo.displayText; font.pixelSize: 11; font.family: "Segoe UI, sans-serif"; color: "#0f172a"; verticalAlignment: Text.AlignVCenter }
                }
            }

            // Ethernet Controls
            Row {
                spacing: 6
                visible: protocolCombo.currentIndex !== 0

                TextField {
                    id: ipField
                    width: 95
                    height: 28
                    text: root.receiver.ipAddress
                    font.pixelSize: 11
                    font.family: "Segoe UI, sans-serif"
                    color: "#0f172a"
                    background: Rectangle { color: "#f8fafc"; border.color: "#cbd5e1"; border.width: 1; radius: 5 }
                    onEditingFinished: root.receiver.ipAddress = text
                }

                TextField {
                    id: netPortField
                    width: 55
                    height: 28
                    text: root.receiver.networkPort.toString()
                    font.pixelSize: 11
                    font.family: "Segoe UI, sans-serif"
                    color: "#0f172a"
                    background: Rectangle { color: "#f8fafc"; border.color: "#cbd5e1"; border.width: 1; radius: 5 }
                    onEditingFinished: {
                        var p = parseInt(text);
                        if (!isNaN(p)) root.receiver.networkPort = p;
                    }
                }
            }

            // Connect Button
            Button {
                id: connectBtn
                Layout.preferredWidth: 92
                Layout.preferredHeight: 28
                text: root.receiver.isConnected ? "Disconnect" : "Connect"

                contentItem: Text {
                    text: connectBtn.text
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.family: "Segoe UI, sans-serif"
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: root.receiver.isConnected ?
                        "#ef4444" :
                        (connectBtn.down ? "#1d4ed8" : (connectBtn.hovered ? "#2563eb" : "#3b82f6"))
                    radius: 5
                }

                onClicked: {
                    if (root.receiver.isConnected) {
                        root.receiver.disconnectReceiver();
                    } else {
                        root.receiver.connectReceiver();
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Simple Test Packet Button (Manual Bench Check)
            Button {
                id: testBtn
                Layout.preferredWidth: 80
                Layout.preferredHeight: 28
                text: "Test Packet"

                contentItem: Text {
                    text: testBtn.text
                    font.pixelSize: 11
                    font.family: "Segoe UI, sans-serif"
                    color: "#334155"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: testBtn.down ? "#e2e8f0" : (testBtn.hovered ? "#f1f5f9" : "#ffffff")
                    border.color: "#cbd5e1"
                    border.width: 1
                    radius: 5
                }

                onClicked: {
                    root.receiver.sendTestPacketHex(45.0, 15.0);
                }
            }

            Button {
                id: clearBtn
                Layout.preferredWidth: 55
                Layout.preferredHeight: 28
                text: "Clear"

                contentItem: Text {
                    text: clearBtn.text
                    font.pixelSize: 11
                    font.family: "Segoe UI, sans-serif"
                    color: "#64748b"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: clearBtn.down ? "#e2e8f0" : (clearBtn.hovered ? "#f1f5f9" : "#ffffff")
                    border.color: "#cbd5e1"
                    border.width: 1
                    radius: 5
                }

                onClicked: {
                    packetModel.clear();
                    root.receiver.clearLog();
                }
            }
        }

        // Clean Table Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            color: "#f8fafc"
            border.color: "#e2e8f0"
            border.width: 1
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                Text { Layout.preferredWidth: 80; text: "Time"; font.pixelSize: 11; font.weight: Font.DemiBold; font.family: "Segoe UI, sans-serif"; color: "#475569" }
                Text { Layout.preferredWidth: 85; text: "Port"; font.pixelSize: 11; font.weight: Font.DemiBold; font.family: "Segoe UI, sans-serif"; color: "#475569" }
                Text { Layout.fillWidth: true; text: "Raw Data (Hex)"; font.pixelSize: 11; font.weight: Font.DemiBold; font.family: "Segoe UI, sans-serif"; color: "#475569" }
                Text { Layout.preferredWidth: 75; text: "Azimuth"; font.pixelSize: 11; font.weight: Font.DemiBold; font.family: "Segoe UI, sans-serif"; color: "#2563eb" }
                Text { Layout.preferredWidth: 75; text: "Elevation"; font.pixelSize: 11; font.weight: Font.DemiBold; font.family: "Segoe UI, sans-serif"; color: "#059669" }
            }
        }

        // Clean Table Rows
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#ffffff"
            border.color: "#e2e8f0"
            border.width: 1
            radius: 4
            clip: true

            ListView {
                id: packetListView
                anchors.fill: parent
                model: packetModel
                delegate: Rectangle {
                    width: packetListView.width
                    height: 24
                    color: (index % 2 === 0) ? "#ffffff" : "#f8fafc"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text { Layout.preferredWidth: 80; text: model.timestamp; font.pixelSize: 11; font.family: "Consolas, monospace"; color: "#64748b" }
                        Text { Layout.preferredWidth: 85; text: model.channel; font.pixelSize: 11; font.family: "Segoe UI, sans-serif"; color: "#475569"; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: model.hexData; font.pixelSize: 11; font.family: "Consolas, monospace"; color: "#334155"; elide: Text.ElideRight }
                        Text { Layout.preferredWidth: 75; text: model.azimuth; font.pixelSize: 11; font.weight: Font.Bold; font.family: "Segoe UI, sans-serif"; color: "#2563eb" }
                        Text { Layout.preferredWidth: 75; text: model.elevation; font.pixelSize: 11; font.weight: Font.Bold; font.family: "Segoe UI, sans-serif"; color: (model.elRaw < 0) ? "#ef4444" : "#059669" }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.targetAnglesSelected(model.azRaw, model.elRaw);
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    width: 6
                    policy: ScrollBar.AsNeeded
                }
            }

            // Empty state placeholder
            Text {
                anchors.centerIn: parent
                text: "No packets received yet. Connect a port to read data."
                font.pixelSize: 11
                font.family: "Segoe UI, sans-serif"
                color: "#94a3b8"
                visible: packetModel.count === 0
            }
        }
    }
}
