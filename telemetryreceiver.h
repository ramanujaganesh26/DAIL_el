#ifndef TELEMETRYRECEIVER_H
#define TELEMETRYRECEIVER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QByteArray>
#include <QDateTime>
#include <QtSerialPort/QSerialPort>
#include <QtSerialPort/QSerialPortInfo>
#include <QtNetwork/QTcpServer>
#include <QtNetwork/QTcpSocket>
#include <QtNetwork/QUdpSocket>

class TelemetryReceiver : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString connectionType READ connectionType WRITE setConnectionType NOTIFY connectionTypeChanged)
    Q_PROPERTY(QString portName READ portName WRITE setPortName NOTIFY portNameChanged)
    Q_PROPERTY(int baudRate READ baudRate WRITE setBaudRate NOTIFY baudRateChanged)
    Q_PROPERTY(QString ipAddress READ ipAddress WRITE setIpAddress NOTIFY ipAddressChanged)
    Q_PROPERTY(int networkPort READ networkPort WRITE setNetworkPort NOTIFY networkPortChanged)
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionStatusChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY connectionStatusChanged)
    Q_PROPERTY(QStringList availablePorts READ availablePorts NOTIFY availablePortsChanged)
    Q_PROPERTY(double lastAzimuth READ lastAzimuth NOTIFY telemetryReceived)
    Q_PROPERTY(double lastElevation READ lastElevation NOTIFY telemetryReceived)
    Q_PROPERTY(int packetCount READ packetCount NOTIFY packetCountChanged)
    Q_PROPERTY(int errorCount READ errorCount NOTIFY errorCountChanged)

public:
    explicit TelemetryReceiver(QObject *parent = nullptr);
    ~TelemetryReceiver() override;

    QString connectionType() const { return m_connectionType; }
    void setConnectionType(const QString &type);

    QString portName() const { return m_portName; }
    void setPortName(const QString &port);

    int baudRate() const { return m_baudRate; }
    void setBaudRate(int baud);

    QString ipAddress() const { return m_ipAddress; }
    void setIpAddress(const QString &ip);

    int networkPort() const { return m_networkPort; }
    void setNetworkPort(int port);

    bool isConnected() const { return m_isConnected; }
    QString statusMessage() const { return m_statusMessage; }
    QStringList availablePorts() const { return m_availablePorts; }

    double lastAzimuth() const { return m_lastAzimuth; }
    double lastElevation() const { return m_lastElevation; }
    int packetCount() const { return m_packetCount; }
    int errorCount() const { return m_errorCount; }

public slots:
    void connectReceiver();
    void disconnectReceiver();
    void refreshPorts();
    void sendTestPacketHex(double testAz, double testEl);
    void sendTestPacketAscii(double testAz, double testEl);
    void injectRawHex(const QString &hexStr);
    void injectRawAscii(const QString &asciiStr);
    void clearLog();

signals:
    void connectionTypeChanged();
    void portNameChanged();
    void baudRateChanged();
    void ipAddressChanged();
    void networkPortChanged();
    void connectionStatusChanged();
    void availablePortsChanged();
    void packetCountChanged();
    void errorCountChanged();

    void telemetryReceived(double azimuth, double elevation);
    void packetLogged(const QString &timestamp, const QString &channel, const QString &hexData,
                      const QString &asciiData, double azimuth, double elevation, bool isValid);

private slots:
    void handleSerialReadyRead();
    void handleSerialError(QSerialPort::SerialPortError error);

    void handleTcpNewConnection();
    void handleTcpClientReadyRead();
    void handleTcpClientConnected();
    void handleTcpClientDisconnected();
    void handleTcpError();

    void handleUdpReadyRead();

private:
    void setStatus(bool connected, const QString &msg);
    void processData(const QByteArray &data, const QString &channel);
    bool parseBinaryPacket(const QByteArray &packet, double &outAz, double &outEl);
    bool parseAsciiPacket(const QString &text, double &outAz, double &outEl);

    QString m_connectionType;  // "COM", "TCP_CLIENT", "TCP_SERVER", "UDP"
    QString m_portName;
    int m_baudRate;
    QString m_ipAddress;
    int m_networkPort;

    bool m_isConnected;
    QString m_statusMessage;
    QStringList m_availablePorts;

    double m_lastAzimuth;
    double m_lastElevation;
    int m_packetCount;
    int m_errorCount;

    // Hardware handles
    QSerialPort *m_serialPort;
    QTcpServer *m_tcpServer;
    QTcpSocket *m_tcpClientSocket;
    QUdpSocket *m_udpSocket;

    QByteArray m_rxBuffer;
};

#endif // TELEMETRYRECEIVER_H
