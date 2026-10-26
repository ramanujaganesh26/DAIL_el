#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "telemetryreceiver.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    qmlRegisterType<TelemetryReceiver>("Dual_dial", 1, 0, "TelemetryReceiver");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("Dual_dial", "Main");

    return QGuiApplication::exec();
}
