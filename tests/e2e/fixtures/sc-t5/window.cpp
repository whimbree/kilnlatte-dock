/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <QByteArray>
#include <QFile>
#include <QFileInfo>
#include <QApplication>
#include <QGuiApplication>
#include <QWidget>

#include <unistd.h>

namespace {

QByteArray processStartTime()
{
    QFile stat(QStringLiteral("/proc/self/stat"));
    if (!stat.open(QIODevice::ReadOnly)) {
        return {};
    }

    const QByteArray data = stat.readAll();
    const qsizetype commandEnd = data.lastIndexOf(')');
    if (commandEnd < 0) {
        return {};
    }

    // Fields after the command begin at field 3. Start time is field 22.
    const QList<QByteArray> fields = data.mid(commandEnd + 1).simplified().split(' ');
    return fields.size() > 19 ? fields.at(19) : QByteArray{};
}

bool recordProcessIdentity()
{
    const QString recordPath = qEnvironmentVariable("SC_T5_PROCESS_RECORDS");
    const QByteArray startTime = processStartTime();
    const QString executable = QFileInfo(QStringLiteral("/proc/self/exe")).symLinkTarget();
    if (recordPath.isEmpty() || startTime.isEmpty() || executable.isEmpty()) {
        return false;
    }

    QFile records(recordPath);
    if (!records.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Unbuffered)) {
        return false;
    }

    const QByteArray record = QByteArray::number(getpid()) + '|' + startTime + '|'
        + QFile::encodeName(executable) + '\n';
    return records.write(record) == record.size();
}

}

int main(int argc, char **argv)
{
    QGuiApplication::setDesktopFileName(QStringLiteral("org.kde.latte.sc-t5"));
    QGuiApplication::setApplicationName(QStringLiteral("Latte SC-T5 Fixture"));
    QApplication app(argc, argv);

    if (!recordProcessIdentity()) {
        qCritical("SC-T5 fixture could not record its process identity");
        return 2;
    }

    QWidget window;
    window.setWindowTitle(QStringLiteral("latte-sc-t5-window"));
    window.resize(320, 180);
    window.show();
    return app.exec();
}
