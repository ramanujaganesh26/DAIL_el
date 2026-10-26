#include "telemetryreceiver.h"
#include <QDebug>
#include <QRegularExpression>

TelemetryReceiver::TelemetryReceiver(QObject *parent)
    : QObject(parent)
    , m_connectionType("COM")
    , m_portName("COM1")
    , m_baudRate(115200)
    , m_ipAddress("127.0.0.1")
    , m_networkPort(8080)
    , m_isConnected(false)
    , m_statusMessage("Ready")
    , m_lastAzimuth(0.0)
    , m_lastElevation(0.0)
    , m_packetCount(0)
    , m_errorCount(0)
    , m_serialPort(nullptr)
    , m_tcpServer(nullptr)
    , m_tcpClientSocket(nullptr)
    , m_udpSocket(nullptr)
{
    refreshPorts();
}

TelemetryReceiver::~TelemetryReceiver()
{
    disconnectReceiver();
}

void TelemetryReceiver::setConnectionType(const QString &type)
{
    if (m_connectionType != type) {
        if (m_isConnected) {
            disconnectReceiver();
        }
        m_connectionType = type;
        emit connectionTypeChanged();
    }
}

void TelemetryReceiver::setPortName(const QString &port)
{
    if (m_portName != port) {
        m_portName = port;
        emit portNameChanged();
    }
}

void TelemetryReceiver::setBaudRate(int baud)
{
    if (m_baudRate != baud) {
        m_baudRate = baud;
        emit baudRateChanged();
    }
}

void TelemetryReceiver::setIpAddress(const QString &ip)
{
    if (m_ipAddress != ip) {
        m_ipAddress = ip;
        emit ipAddressChanged();
    }
}

void TelemetryReceiver::setNetworkPort(int port)
{
    if (m_networkPort != port) {
        m_networkPort = port;
        emit networkPortChanged();
    }
}

void TelemetryReceiver::setStatus(bool connected, const QString &msg)
{
    m_isConnected = connected;
    m_statusMessage = msg;
    emit connectionStatusChanged();
}

void TelemetryReceiver::refreshPorts()
{
    m_availablePorts.clear();
    const auto ports = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo &info : ports) {
        m_availablePorts.append(info.portName());
    }

    if (m_availablePorts.isEmpty()) {
        m_availablePorts << "COM1" << "COM2" << "COM3" << "COM4";
    }

    if (!m_availablePorts.contains(m_portName) && !m_availablePorts.isEmpty()) {
        m_portName = m_availablePorts.first();
        emit portNameChanged();
    }

    emit availablePortsChanged();
}

void TelemetryReceiver::clearLog()
{
    m_packetCount = 0;
    m_errorCount = 0;
    emit packetCountChanged();
    emit errorCountChanged();
}

void TelemetryReceiver::connectReceiver()
{
    disconnectReceiver();
    m_rxBuffer.clear();

    if (m_connectionType == "COM") {
        if (!m_serialPort) {
            m_serialPort = new QSerialPort(this);
            connect(m_serialPort, &QSerialPort::readyRead, this, &TelemetryReceiver::handleSerialReadyRead);
            connect(m_serialPort, &QSerialPort::errorOccurred, this, &TelemetryReceiver::handleSerialError);
        }

        m_serialPort->setPortName(m_portName);
        m_serialPort->setBaudRate(m_baudRate);
        m_serialPort->setDataBits(QSerialPort::Data8);
        m_serialPort->setParity(QSerialPort::NoParity);
        m_serialPort->setStopBits(QSerialPort::OneStop);
        m_serialPort->setFlowControl(QSerialPort::NoFlowControl);

        if (m_serialPort->open(QIODevice::ReadWrite)) {
            setStatus(true, QString("Connected to %1 @ %2 bps").arg(m_portName).arg(m_baudRate));
        } else {
            setStatus(false, QString("Failed to open %1: %2").arg(m_portName, m_serialPort->errorString()));
        }
    }
    else if (m_connectionType == "TCP_CLIENT") {
        if (!m_tcpClientSocket) {
            m_tcpClientSocket = new QTcpSocket(this);
            connect(m_tcpClientSocket, &QTcpSocket::readyRead, this, &TelemetryReceiver::handleTcpClientReadyRead);
            connect(m_tcpClientSocket, &QTcpSocket::connected, this, &TelemetryReceiver::handleTcpClientConnected);
            connect(m_tcpClientSocket, &QTcpSocket::disconnected, this, &TelemetryReceiver::handleTcpClientDisconnected);
            connect(m_tcpClientSocket, &QTcpSocket::errorOccurred, this, &TelemetryReceiver::handleTcpError);
        }

        setStatus(false, QString("Connecting to %1:%2...").arg(m_ipAddress).arg(m_networkPort));
        m_tcpClientSocket->connectToHost(m_ipAddress, static_cast<quint16>(m_networkPort));
    }
    else if (m_connectionType == "TCP_SERVER") {
        if (!m_tcpServer) {
            m_tcpServer = new QTcpServer(this);
            connect(m_tcpServer, &QTcpServer::newConnection, this, &TelemetryReceiver::handleTcpNewConnection);
        }

        if (m_tcpServer->listen(QHostAddress::Any, static_cast<quint16>(m_networkPort))) {
            setStatus(true, QString("TCP Server listening on port %1").arg(m_networkPort));
        } else {
            setStatus(false, QString("Server failed on port %1: %2").arg(m_networkPort).arg(m_tcpServer->errorString()));
        }
    }
    else if (m_connectionType == "UDP") {
        if (!m_udpSocket) {
            m_udpSocket = new QUdpSocket(this);
            connect(m_udpSocket, &QUdpSocket::readyRead, this, &TelemetryReceiver::handleUdpReadyRead);
        }

        if (m_udpSocket->bind(QHostAddress::Any, static_cast<quint16>(m_networkPort), QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint)) {
            setStatus(true, QString("UDP listening on port %1").arg(m_networkPort));
        } else {
            setStatus(false, QString("UDP bind failed on port %1: %2").arg(m_networkPort).arg(m_udpSocket->errorString()));
        }
    }
}

void TelemetryReceiver::disconnectReceiver()
{
    if (m_serialPort && m_serialPort->isOpen()) {
        m_serialPort->close();
    }
    if (m_tcpClientSocket) {
        m_tcpClientSocket->abort();
    }
    if (m_tcpServer && m_tcpServer->isListening()) {
        m_tcpServer->close();
    }
    if (m_udpSocket && m_udpSocket->isOpen()) {
        m_udpSocket->close();
    }

    setStatus(false, "Disconnected");
}

void TelemetryReceiver::handleSerialReadyRead()
{
    if (!m_serialPort) return;
    QByteArray data = m_serialPort->readAll();
    processData(data, QString("SERIAL (%1)").arg(m_portName));
}

void TelemetryReceiver::handleSerialError(QSerialPort::SerialPortError error)
{
    if (error == QSerialPort::ResourceError || error == QSerialPort::DeviceNotFoundError) {
        disconnectReceiver();
        setStatus(false, QString("Serial error: %1").arg(m_serialPort ? m_serialPort->errorString() : "Device lost"));
    }
}

void TelemetryReceiver::handleTcpClientConnected()
{
    setStatus(true, QString("TCP connected to %1:%2").arg(m_ipAddress).arg(m_networkPort));
}

void TelemetryReceiver::handleTcpClientDisconnected()
{
    setStatus(false, "TCP client disconnected");
}

void TelemetryReceiver::handleTcpClientReadyRead()
{
    if (!m_tcpClientSocket) return;
    QByteArray data = m_tcpClientSocket->readAll();
    processData(data, "TCP CLIENT");
}

void TelemetryReceiver::handleTcpError()
{
    if (m_tcpClientSocket) {
        setStatus(false, QString("TCP error: %1").arg(m_tcpClientSocket->errorString()));
    }
}

void TelemetryReceiver::handleTcpNewConnection()
{
    if (!m_tcpServer) return;
    while (m_tcpServer->hasPendingConnections()) {
        QTcpSocket *client = m_tcpServer->nextPendingConnection();
        connect(client, &QTcpSocket::readyRead, this, [this, client]() {
            QByteArray data = client->readAll();
            processData(data, QString("TCP SRV (%1)").arg(client->peerAddress().toString()));
        });
        connect(client, &QTcpSocket::disconnected, client, &QTcpSocket::deleteLater);
        setStatus(true, QString("Client connected from %1").arg(client->peerAddress().toString()));
    }
}

void TelemetryReceiver::handleUdpReadyRead()
{
    if (!m_udpSocket) return;
    while (m_udpSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(static_cast<int>(m_udpSocket->pendingDatagramSize()));
        QHostAddress sender;
        quint16 senderPort;
        m_udpSocket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);
        processData(datagram, QString("UDP (%1:%2)").arg(sender.toString()).arg(senderPort));
    }
}

void TelemetryReceiver::processData(const QByteArray &data, const QString &channel)
{
    m_rxBuffer.append(data);

    // Look for packets in the buffer
    while (!m_rxBuffer.isEmpty()) {
        // Check for Binary frame header: 0xAA 0x55
        int syncIndex = -1;
        for (int i = 0; i < m_rxBuffer.size() - 1; ++i) {
            if ((static_cast<quint8>(m_rxBuffer.at(i)) == 0xAA) &&
                (static_cast<quint8>(m_rxBuffer.at(i + 1)) == 0x55)) {
                syncIndex = i;
                break;
            }
        }

        if (syncIndex >= 0) {
            // Discard any garbage before sync header
            if (syncIndex > 0) {
                m_rxBuffer.remove(0, syncIndex);
            }

            // Need at least 8 bytes for 8-byte frame
            if (m_rxBuffer.size() < 8) {
                break; // wait for more bytes
            }

            // Check if 8-byte packet ends with 0xEE at index 7
            bool is8Byte = (static_cast<quint8>(m_rxBuffer.at(7)) == 0xEE);
            bool is10Byte = (m_rxBuffer.size() >= 10 && static_cast<quint8>(m_rxBuffer.at(9)) == 0xEE);

            if (is8Byte) {
                QByteArray packet = m_rxBuffer.left(8);
                m_rxBuffer.remove(0, 8);

                double az = 0.0, el = 0.0;
                bool ok = parseBinaryPacket(packet, az, el);
                QString hexStr = packet.toHex(' ').toUpper();
                QString asciiStr = QString::fromLatin1(packet);
                QString timeStr = QDateTime::currentDateTime().toString("HH:mm:ss.zzz");

                if (ok) {
                    m_lastAzimuth = az;
                    m_lastElevation = el;
                    m_packetCount++;
                    emit packetCountChanged();
                    emit telemetryReceived(az, el);
                } else {
                    m_errorCount++;
                    emit errorCountChanged();
                }

                emit packetLogged(timeStr, channel, hexStr, asciiStr, az, el, ok);
                continue;
            } else if (is10Byte) {
                QByteArray packet = m_rxBuffer.left(10);
                m_rxBuffer.remove(0, 10);

                double az = 0.0, el = 0.0;
                bool ok = parseBinaryPacket(packet, az, el);
                QString hexStr = packet.toHex(' ').toUpper();
                QString asciiStr = QString::fromLatin1(packet);
                QString timeStr = QDateTime::currentDateTime().toString("HH:mm:ss.zzz");

                if (ok) {
                    m_lastAzimuth = az;
                    m_lastElevation = el;
                    m_packetCount++;
                    emit packetCountChanged();
                    emit telemetryReceived(az, el);
                } else {
                    m_errorCount++;
                    emit errorCountChanged();
                }

                emit packetLogged(timeStr, channel, hexStr, asciiStr, az, el, ok);
                continue;
            } else if (m_rxBuffer.size() >= 10) {
                // False sync, skip first byte and search again
                m_rxBuffer.remove(0, 1);
                continue;
            } else {
                break; // Wait for complete frame
            }
        }

        // Check for ASCII packet delimited by '\n' or '\r'
        int nlIndex = m_rxBuffer.indexOf('\n');
        if (nlIndex < 0) nlIndex = m_rxBuffer.indexOf('\r');

        if (nlIndex >= 0) {
            QByteArray line = m_rxBuffer.left(nlIndex).trimmed();
            m_rxBuffer.remove(0, nlIndex + 1);

            if (!line.isEmpty()) {
                QString text = QString::fromUtf8(line);
                double az = 0.0, el = 0.0;
                bool ok = parseAsciiPacket(text, az, el);
                QString hexStr = line.toHex(' ').toUpper();
                QString timeStr = QDateTime::currentDateTime().toString("HH:mm:ss.zzz");

                if (ok) {
                    m_lastAzimuth = az;
                    m_lastElevation = el;
                    m_packetCount++;
                    emit packetCountChanged();
                    emit telemetryReceived(az, el);
                } else {
                    m_errorCount++;
                    emit errorCountChanged();
                }

                emit packetLogged(timeStr, channel, hexStr, text, az, el, ok);
            }
            continue;
        }

        // Limit buffer size to prevent memory buildup if stream has no delimiters
        if (m_rxBuffer.size() > 512) {
            m_rxBuffer.remove(0, 256);
        }
        break;
    }
}

bool TelemetryReceiver::parseBinaryPacket(const QByteArray &packet, double &outAz, double &outEl)
{
    // 8-Byte Frame format:
    // [0] 0xAA  [1] 0x55
    // [2] AZ_H  [3] AZ_L  (uint16_t, 0.1 deg units, 0..3600)
    // [4] EL_H  [5] EL_L  (int16_t,  0.1 deg units, -100..+850)
    // [6] CHECKSUM (Sum of bytes 2..5 & 0xFF)
    // [7] 0xEE
    if (packet.size() == 8) {
        quint8 h1 = static_cast<quint8>(packet.at(0));
        quint8 h2 = static_cast<quint8>(packet.at(1));
        quint8 tail = static_cast<quint8>(packet.at(7));

        if (h1 != 0xAA || h2 != 0x55 || tail != 0xEE) return false;

        quint8 azH = static_cast<quint8>(packet.at(2));
        quint8 azL = static_cast<quint8>(packet.at(3));
        quint8 elH = static_cast<quint8>(packet.at(4));
        quint8 elL = static_cast<quint8>(packet.at(5));
        quint8 cs  = static_cast<quint8>(packet.at(6));

        quint8 calcCs = static_cast<quint8>((azH + azL + elH + elL) & 0xFF);
        if (cs != calcCs) return false;

        quint16 rawAz = (static_cast<quint16>(azH) << 8) | azL;
        qint16  rawEl = static_cast<qint16>((static_cast<quint16>(elH) << 8) | elL);

        double az = rawAz / 10.0;
        double el = rawEl / 10.0;

        if (az < 0.0 || az > 360.0) return false;
        if (el < -10.0 || el > 85.0) return false;

        outAz = az;
        outEl = el;
        return true;
    }

    // 10-Byte Frame format:
    // [0] 0xAA  [1] 0x55  [2] ID (0x01)
    // [3] AZ_H  [4] AZ_L  (uint16_t)
    // [5] EL_H  [6] EL_L  (int16_t)
    // [7] STATUS
    // [8] CHECKSUM (Sum of bytes 2..7 & 0xFF)
    // [9] 0xEE
    if (packet.size() == 10) {
        quint8 h1 = static_cast<quint8>(packet.at(0));
        quint8 h2 = static_cast<quint8>(packet.at(1));
        quint8 tail = static_cast<quint8>(packet.at(9));

        if (h1 != 0xAA || h2 != 0x55 || tail != 0xEE) return false;

        quint8 azH = static_cast<quint8>(packet.at(3));
        quint8 azL = static_cast<quint8>(packet.at(4));
        quint8 elH = static_cast<quint8>(packet.at(5));
        quint8 elL = static_cast<quint8>(packet.at(6));
        quint8 cs  = static_cast<quint8>(packet.at(8));

        quint32 sum = 0;
        for (int i = 2; i <= 7; ++i) {
            sum += static_cast<quint8>(packet.at(i));
        }
        if (cs != static_cast<quint8>(sum & 0xFF)) return false;

        quint16 rawAz = (static_cast<quint16>(azH) << 8) | azL;
        qint16  rawEl = static_cast<qint16>((static_cast<quint16>(elH) << 8) | elL);

        double az = rawAz / 10.0;
        double el = rawEl / 10.0;

        if (az < 0.0 || az > 360.0) return false;
        if (el < -10.0 || el > 85.0) return false;

        outAz = az;
        outEl = el;
        return true;
    }

    return false;
}

bool TelemetryReceiver::parseAsciiPacket(const QString &text, double &outAz, double &outEl)
{
    // Pattern 1: $AZ,45.0,EL,15.0 or AZ:45.0,EL:15.0 or A045.0E+15.0
    // Try matching two floating-point numbers with identifiers
    static QRegularExpression re1(R"((?:AZ[:,\s=]*|A)([+-]?\d+(?:\.\d+)?).*(?:EL[:,\s=]*|E)([+-]?\d+(?:\.\d+)?))", QRegularExpression::CaseInsensitiveOption);
    QRegularExpressionMatch match = re1.match(text);
    if (match.hasMatch()) {
        bool okAz = false, okEl = false;
        double az = match.captured(1).toDouble(&okAz);
        double el = match.captured(2).toDouble(&okEl);

        if (okAz && okEl) {
            // Normalize Azimuth 0..360
            while (az < 0.0) az += 360.0;
            while (az > 360.0) az -= 360.0;
            el = qBound(-10.0, el, 85.0);

            outAz = az;
            outEl = el;
            return true;
        }
    }

    // Pattern 2: Two comma or space separated numbers "45.0, 15.0"
    QStringList parts = text.split(QRegularExpression(R"([,\s;]+)"), Qt::SkipEmptyParts);
    if (parts.size() >= 2) {
        bool ok1 = false, ok2 = false;
        double az = parts[0].toDouble(&ok1);
        double el = parts[1].toDouble(&ok2);
        if (ok1 && ok2) {
            while (az < 0.0) az += 360.0;
            while (az > 360.0) az -= 360.0;
            el = qBound(-10.0, el, 85.0);
            outAz = az;
            outEl = el;
            return true;
        }
    }

    return false;
}

void TelemetryReceiver::sendTestPacketHex(double testAz, double testEl)
{
    // Construct 8-byte Hex Frame
    quint16 rawAz = static_cast<quint16>(qBound(0.0, testAz, 360.0) * 10.0);
    qint16  rawEl = static_cast<qint16>(qBound(-10.0, testEl, 85.0) * 10.0);

    quint8 azH = static_cast<quint8>((rawAz >> 8) & 0xFF);
    quint8 azL = static_cast<quint8>(rawAz & 0xFF);
    quint8 elH = static_cast<quint8>((static_cast<quint16>(rawEl) >> 8) & 0xFF);
    quint8 elL = static_cast<quint8>(rawEl & 0xFF);
    quint8 cs  = static_cast<quint8>((azH + azL + elH + elL) & 0xFF);

    QByteArray packet;
    packet.append(static_cast<char>(0xAA));
    packet.append(static_cast<char>(0x55));
    packet.append(static_cast<char>(azH));
    packet.append(static_cast<char>(azL));
    packet.append(static_cast<char>(elH));
    packet.append(static_cast<char>(elL));
    packet.append(static_cast<char>(cs));
    packet.append(static_cast<char>(0xEE));

    processData(packet, "SIM (HEX-8B)");
}

void TelemetryReceiver::sendTestPacketAscii(double testAz, double testEl)
{
    double az = qBound(0.0, testAz, 360.0);
    double el = qBound(-10.0, testEl, 85.0);
    QString ascii = QString("$AZ,%1,EL,%2\r\n").arg(az, 0, 'f', 1).arg(el, 0, 'f', 1);
    processData(ascii.toUtf8(), "SIM (ASCII)");
}

void TelemetryReceiver::injectRawHex(const QString &hexStr)
{
    QString cleaned = hexStr;
    cleaned.remove(' ');
    cleaned.remove(':');
    cleaned.remove(',');
    cleaned.remove("0x", Qt::CaseInsensitive);
    QByteArray rawBytes = QByteArray::fromHex(cleaned.toLatin1());
    if (!rawBytes.isEmpty()) {
        processData(rawBytes, "MANUAL (HEX)");
    }
}

void TelemetryReceiver::injectRawAscii(const QString &asciiStr)
{
    QByteArray data = asciiStr.toUtf8();
    if (!data.endsWith('\n') && !data.endsWith('\r')) {
        data.append('\n');
    }
    processData(data, "MANUAL (ASCII)");
}

