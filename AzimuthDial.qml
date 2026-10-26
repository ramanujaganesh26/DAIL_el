import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Item {
    id: root

    property real angle: 0.0          // Range: 0.0 to 360.0 degrees
    property color accentColor: "#2563eb" // Modern clean Royal Blue

    signal angleChangedByUser(real newAngle)

    implicitWidth: 350
    implicitHeight: 380

    function normalizeAngle(a) {
        var n = a % 360.0;
        if (n < 0) n += 360.0;
        return n;
    }

    function setAngleSafe(val) {
        var n = normalizeAngle(val);
        angle = n;
        angleChangedByUser(n);
    }

    // Clean White Card Background
    Rectangle {
        anchors.fill: parent
        color: "#ffffff"
        border.color: "#e2e8f0"
        border.width: 1
        radius: 8

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Clean Header: Title & Digital Badge
            RowLayout {
                Layout.fillWidth: true

                Column {
                    spacing: 1
                    Text {
                        text: "Azimuth"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        font.family: "Segoe UI, sans-serif"
                        color: "#0f172a"
                    }
                    Text {
                        text: "0° to 360°"
                        font.pixelSize: 11
                        font.family: "Segoe UI, sans-serif"
                        color: "#64748b"
                    }
                }

                Item { Layout.fillWidth: true }

                // Angle Readout Badge
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 30
                    color: "#eff6ff"
                    border.color: "#bfdbfe"
                    border.width: 1
                    radius: 6

                    Text {
                        anchors.centerIn: parent
                        text: root.angle.toFixed(1) + "°"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        font.family: "Segoe UI, sans-serif"
                        color: "#2563eb"
                    }
                }
            }

            // Dial Canvas
            Item {
                id: dialArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 200

                Canvas {
                    id: dialCanvas
                    anchors.fill: parent
                    antialiasing: true

                    Connections {
                        target: root
                        function onAngleChanged() { dialCanvas.requestPaint(); }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();

                        var cx = width / 2;
                        var cy = height / 2;
                        var radius = Math.min(cx, cy) - 8;
                        if (radius <= 25) return;

                        // 1. Dial Face
                        ctx.beginPath();
                        ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
                        ctx.fillStyle = "#fafafa";
                        ctx.fill();
                        ctx.lineWidth = 1.5;
                        ctx.strokeStyle = "#cbd5e1";
                        ctx.stroke();

                        // 2. Subtle Inner Ring
                        ctx.beginPath();
                        ctx.arc(cx, cy, radius * 0.76, 0, 2 * Math.PI);
                        ctx.lineWidth = 1;
                        ctx.strokeStyle = "#e2e8f0";
                        ctx.stroke();

                        // 3. Degree Graduations & Labels
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";

                        for (var deg = 0; deg < 360; deg += 5) {
                            var rad = (deg - 90) * Math.PI / 180.0;
                            var cos = Math.cos(rad);
                            var sin = Math.sin(rad);

                            var isMajor = (deg % 30 === 0);
                            var isMid = (deg % 15 === 0);

                            var t1 = radius * 0.96;
                            var t2 = isMajor ? (radius * 0.84) : (isMid ? (radius * 0.88) : (radius * 0.92));

                            ctx.beginPath();
                            ctx.moveTo(cx + cos * t1, cy + sin * t1);
                            ctx.lineTo(cx + cos * t2, cy + sin * t2);

                            if (isMajor) {
                                ctx.strokeStyle = "#0f172a";
                                ctx.lineWidth = 2.0;
                                ctx.stroke();

                                // Degree label (NO N, S, E, W)
                                var label = deg.toString() + "°";
                                var textR = radius * 0.64;
                                ctx.fillStyle = (deg % 90 === 0) ? "#0f172a" : "#475569";
                                ctx.font = (deg % 90 === 0) ? "bold 11px Segoe UI, sans-serif" : "10px Segoe UI, sans-serif";
                                ctx.fillText(label, cx + cos * textR, cy + sin * textR);
                            } else {
                                ctx.strokeStyle = isMid ? "#94a3b8" : "#cbd5e1";
                                ctx.lineWidth = isMid ? 1.0 : 0.6;
                                ctx.stroke();
                            }
                        }

                        // 4. Pointer Needle
                        var curRad = (root.angle - 90) * Math.PI / 180.0;
                        var nCos = Math.cos(curRad);
                        var nSin = Math.sin(curRad);

                        var perpCos = -nSin;
                        var perpSin = nCos;
                        var baseW = 4;

                        // Needle pointer
                        ctx.beginPath();
                        ctx.moveTo(cx + perpCos * baseW, cy + perpSin * baseW);
                        ctx.lineTo(cx + nCos * (radius * 0.92), cy + nSin * (radius * 0.92));
                        ctx.lineTo(cx - perpCos * baseW, cy - perpSin * baseW);
                        ctx.closePath();
                        ctx.fillStyle = root.accentColor;
                        ctx.fill();

                        // Counterweight
                        ctx.beginPath();
                        ctx.moveTo(cx + perpCos * baseW, cy + perpSin * baseW);
                        ctx.lineTo(cx - nCos * (radius * 0.2), cy - nSin * (radius * 0.2));
                        ctx.lineTo(cx - perpCos * baseW, cy - perpSin * baseW);
                        ctx.closePath();
                        ctx.fillStyle = "#64748b";
                        ctx.fill();

                        // Center Hub
                        ctx.beginPath();
                        ctx.arc(cx, cy, 8, 0, 2 * Math.PI);
                        ctx.fillStyle = "#ffffff";
                        ctx.fill();
                        ctx.lineWidth = 2;
                        ctx.strokeStyle = root.accentColor;
                        ctx.stroke();

                        ctx.beginPath();
                        ctx.arc(cx, cy, 3, 0, 2 * Math.PI);
                        ctx.fillStyle = root.accentColor;
                        ctx.fill();
                    }
                }

                // Drag angle with mouse
                MouseArea {
                    id: dialMouseArea
                    anchors.fill: parent
                    preventStealing: true

                    function updateFromMouse(mouseX, mouseY) {
                        var cx = width / 2;
                        var cy = height / 2;
                        var dx = mouseX - cx;
                        var dy = mouseY - cy;
                        var rad = Math.atan2(dy, dx);
                        var deg = rad * 180.0 / Math.PI + 90.0;
                        deg = root.normalizeAngle(deg);
                        root.setAngleSafe(Math.round(deg * 10) / 10.0);
                    }

                    onPressed: function(mouse) { updateFromMouse(mouse.x, mouse.y); }
                    onPositionChanged: function(mouse) {
                        if (pressed) updateFromMouse(mouse.x, mouse.y);
                    }
                }
            }

            // Simple Nudge Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Button {
                    id: btnM10
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    text: "-10°"
                    contentItem: Text { text: btnM10.text; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#334155"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: btnM10.down ? "#e2e8f0" : (btnM10.hovered ? "#f1f5f9" : "#ffffff"); border.color: "#cbd5e1"; border.width: 1; radius: 5 }
                    onClicked: root.setAngleSafe(root.angle - 10.0)
                }

                Button {
                    id: btnM1
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    text: "-1°"
                    contentItem: Text { text: btnM1.text; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#334155"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: btnM1.down ? "#e2e8f0" : (btnM1.hovered ? "#f1f5f9" : "#ffffff"); border.color: "#cbd5e1"; border.width: 1; radius: 5 }
                    onClicked: root.setAngleSafe(root.angle - 1.0)
                }

                Button {
                    id: btnP1
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    text: "+1°"
                    contentItem: Text { text: btnP1.text; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#334155"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: btnP1.down ? "#e2e8f0" : (btnP1.hovered ? "#f1f5f9" : "#ffffff"); border.color: "#cbd5e1"; border.width: 1; radius: 5 }
                    onClicked: root.setAngleSafe(root.angle + 1.0)
                }

                Button {
                    id: btnP10
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    text: "+10°"
                    contentItem: Text { text: btnP10.text; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#334155"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: btnP10.down ? "#e2e8f0" : (btnP10.hovered ? "#f1f5f9" : "#ffffff"); border.color: "#cbd5e1"; border.width: 1; radius: 5 }
                    onClicked: root.setAngleSafe(root.angle + 10.0)
                }
            }
        }
    }
}
