import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

Item {
    id: root

    property real angle: 0.0          // Range: -10.0 to +85.0 degrees
    readonly property real minAngle: -10.0
    readonly property real maxAngle: 85.0

    property color accentColor: "#059669"     // Clean Emerald Green
    property color warningColor: "#dc2626"    // Coral Red

    signal angleChangedByUser(real newAngle)

    implicitWidth: 350
    implicitHeight: 380

    function clampAngle(a) {
        return Math.max(root.minAngle, Math.min(root.maxAngle, a));
    }

    function setAngleSafe(val) {
        var c = clampAngle(val);
        angle = c;
        angleChangedByUser(c);
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
                        text: "Elevation"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        font.family: "Segoe UI, sans-serif"
                        color: "#0f172a"
                    }
                    Text {
                        text: "-10° to +85°"
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
                    color: (root.angle < 0) ? "#fef2f2" : "#ecfdf5"
                    border.color: (root.angle < 0) ? "#fca5a5" : "#a7f3d0"
                    border.width: 1
                    radius: 6

                    Text {
                        anchors.centerIn: parent
                        text: ((root.angle > 0) ? "+" : "") + root.angle.toFixed(1) + "°"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        font.family: "Segoe UI, sans-serif"
                        color: (root.angle < 0) ? root.warningColor : root.accentColor
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

                        // 2. Inactive Zone Shading (+85° around to -10°)
                        var radDep = 10.0 * Math.PI / 180.0;
                        var radElev = -85.0 * Math.PI / 180.0;

                        ctx.beginPath();
                        ctx.arc(cx, cy, radius * 0.96, radElev, radDep, false);
                        ctx.arc(cx, cy, radius * 0.74, radDep, radElev, true);
                        ctx.closePath();
                        ctx.fillStyle = "#f1f5f9";
                        ctx.fill();

                        // 3. Active Travel Arc (-10° to +85°)
                        ctx.beginPath();
                        ctx.arc(cx, cy, radius * 0.74, radElev, radDep, true);
                        ctx.lineWidth = 2.5;
                        ctx.strokeStyle = "#10b981";
                        ctx.stroke();

                        // Negative sector (-10° to 0°) in red
                        ctx.beginPath();
                        ctx.arc(cx, cy, radius * 0.74, 0, radDep, false);
                        ctx.lineWidth = 3.0;
                        ctx.strokeStyle = root.warningColor;
                        ctx.stroke();

                        // 4. Exact Requested Labels: -10, 0, 10, 15, 45, 65, 85
                        var targetLabels = [-10, 0, 10, 15, 45, 65, 85];
                        ctx.textAlign = "center";
                        ctx.textBaseline = "middle";

                        for (var i = 0; i < targetLabels.length; ++i) {
                            var elDeg = targetLabels[i];
                            var radC = -elDeg * Math.PI / 180.0;
                            var cosC = Math.cos(radC);
                            var sinC = Math.sin(radC);

                            // Tick
                            var p1 = radius * 0.96;
                            var p2 = radius * 0.80;

                            ctx.beginPath();
                            ctx.moveTo(cx + cosC * p1, cy + sinC * p1);
                            ctx.lineTo(cx + cosC * p2, cy + sinC * p2);

                            if (elDeg === -10) {
                                ctx.strokeStyle = root.warningColor;
                                ctx.lineWidth = 2.0;
                            } else if (elDeg === 0) {
                                ctx.strokeStyle = "#0f172a";
                                ctx.lineWidth = 2.2;
                            } else {
                                ctx.strokeStyle = "#059669";
                                ctx.lineWidth = 1.8;
                            }
                            ctx.stroke();

                            // Label Text
                            var labelText = (elDeg > 0 ? "+" : "") + elDeg.toString() + "°";
                            var textDist = radius * 0.64;

                            if (elDeg === -10) ctx.fillStyle = root.warningColor;
                            else if (elDeg === 0) ctx.fillStyle = "#0f172a";
                            else ctx.fillStyle = "#334155";

                            ctx.font = (elDeg === 0 || elDeg === 85 || elDeg === -10) ?
                                "bold 11px Segoe UI, sans-serif" :
                                "10px Segoe UI, sans-serif";

                            ctx.fillText(labelText, cx + cosC * textDist, cy + sinC * textDist);
                        }

                        // Minor ticks every 5°
                        for (var mDeg = -10; mDeg <= 85; mDeg += 5) {
                            if (targetLabels.indexOf(mDeg) !== -1) continue;
                            var mRad = -mDeg * Math.PI / 180.0;
                            var mCos = Math.cos(mRad);
                            var mSin = Math.sin(mRad);

                            ctx.beginPath();
                            ctx.moveTo(cx + mCos * (radius * 0.92), cy + mSin * (radius * 0.92));
                            ctx.lineTo(cx + mCos * (radius * 0.84), cy + mSin * (radius * 0.84));
                            ctx.lineWidth = 0.8;
                            ctx.strokeStyle = "#cbd5e1";
                            ctx.stroke();
                        }

                        // 5. Center Level Reference Line
                        ctx.beginPath();
                        ctx.moveTo(cx - 20, cy); ctx.lineTo(cx + 20, cy);
                        ctx.lineWidth = 1;
                        ctx.strokeStyle = "#cbd5e1";
                        ctx.stroke();

                        // 6. Pointer Needle
                        var curRad = -root.angle * Math.PI / 180.0;
                        var nCos = Math.cos(curRad);
                        var nSin = Math.sin(curRad);

                        var perpCos = -nSin;
                        var perpSin = nCos;
                        var baseW = 4;
                        var needleColor = (root.angle < 0) ? root.warningColor : root.accentColor;

                        // Needle pointer
                        ctx.beginPath();
                        ctx.moveTo(cx + perpCos * baseW, cy + perpSin * baseW);
                        ctx.lineTo(cx + nCos * (radius * 0.92), cy + nSin * (radius * 0.92));
                        ctx.lineTo(cx - perpCos * baseW, cy - perpSin * baseW);
                        ctx.closePath();
                        ctx.fillStyle = needleColor;
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
                        ctx.strokeStyle = needleColor;
                        ctx.stroke();

                        ctx.beginPath();
                        ctx.arc(cx, cy, 3, 0, 2 * Math.PI);
                        ctx.fillStyle = needleColor;
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
                        var deg = -rad * 180.0 / Math.PI;
                        if (deg < -180.0) deg += 360.0;
                        if (deg > 180.0) deg -= 360.0;

                        if (deg >= root.minAngle && deg <= root.maxAngle) {
                            root.setAngleSafe(Math.round(deg * 10) / 10.0);
                        }
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
                    id: btnM5
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    text: "-5°"
                    contentItem: Text { text: btnM5.text; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#334155"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: btnM5.down ? "#e2e8f0" : (btnM5.hovered ? "#f1f5f9" : "#ffffff"); border.color: "#cbd5e1"; border.width: 1; radius: 5 }
                    onClicked: root.setAngleSafe(root.angle - 5.0)
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
                    id: btnP5
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    text: "+5°"
                    contentItem: Text { text: btnP5.text; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#334155"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: btnP5.down ? "#e2e8f0" : (btnP5.hovered ? "#f1f5f9" : "#ffffff"); border.color: "#cbd5e1"; border.width: 1; radius: 5 }
                    onClicked: root.setAngleSafe(root.angle + 5.0)
                }
            }
        }
    }
}
