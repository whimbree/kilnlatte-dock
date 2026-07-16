/*
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-License-Identifier: GPL-2.0-or-later
*/

// Ported from latte-dock-qt6 at 81384003 (EX-24 in
// docs/QML_EXTRACTION_PLAN.md, capt ad74a34a): our iconitem.cpp ladder was
// diffed against capt's ancestor and the Qt5 ancestor (f0ad7b23) before
// adoption - all three agree, so their case analysis transfers. capt's
// instrument-first qDebug probes of Qt6 QVariant::canConvert behavior are
// upgraded to assertions here: the premises they printed are pinned, not
// just logged. Two slots added beyond capt's set: the nameless-QIcon Icon
// branch (absent from their slots despite the commit claiming full branch
// coverage) and the named-QIcon precedence path sourceName exists for.

#include "../../declarativeimports/core/units/iconsourceclassifier.h"

#include <QtTest>

#include <QIcon>
#include <QImage>
#include <QPixmap>

using namespace Latte::IconSourceClassifier;

class IconSourceClassifierTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void sourceName_plainString_returnsString();
    void sourceName_imageVariant_returnsEmpty();
    void sourceName_namedThemeIcon_prefersIconName();
    void classify_localFileUrl_isLocalFile();
    void classify_plainName_isSvgOrIconName();
    void classify_relativeToken_isSvgOrIconName();
    void classify_namelessIcon_isIcon();
    void classify_qimage_isImage();
    void classify_emptyVariant_isClear();
    void classify_emptyString_isClear();
    void filter_empty_isFiltered();
    void filter_executablePlaceholder_isFiltered();
    void filter_realName_isNotFiltered();
    void isValid_truthTable();
    void isValid_truthTable_data();
};

void IconSourceClassifierTest::sourceName_plainString_returnsString()
{
    QCOMPARE(sourceName(QVariant(QStringLiteral("firefox"))), QStringLiteral("firefox"));
}

void IconSourceClassifierTest::sourceName_imageVariant_returnsEmpty()
{
    // premise (capt pinned this instrument-first on Qt 6.11): a QImage
    // variant stringifies empty and does not convert to QIcon, so no name
    // can be derived from it
    const QVariant v(QImage(4, 4, QImage::Format_ARGB32));
    QVERIFY(v.toString().isEmpty());
    QVERIFY(!v.canConvert<QIcon>());

    QCOMPARE(sourceName(v), QString());
}

void IconSourceClassifierTest::sourceName_namedThemeIcon_prefersIconName()
{
    // QIcon::name() is only non-empty once the theme lookup RESOLVES, so a
    // named QIcon needs a real theme on disk (the offscreen test env ships
    // none - fromTheme() there yields name()==""). Build a minimal fixture
    // theme the way Qt's own tst_qicon does: index.theme plus one icon.
    QTemporaryDir searchPath;
    QVERIFY(searchPath.isValid());
    const QDir themeRoot(searchPath.path() + QStringLiteral("/fixturetheme"));
    QVERIFY(themeRoot.mkpath(QStringLiteral("16x16/apps")));

    QFile indexFile(themeRoot.filePath(QStringLiteral("index.theme")));
    QVERIFY(indexFile.open(QIODevice::WriteOnly));
    indexFile.write("[Icon Theme]\nName=fixturetheme\nComment=test fixture\n"
                    "Directories=16x16/apps\n\n[16x16/apps]\nSize=16\nType=Fixed\n");
    indexFile.close();

    QImage pixel(16, 16, QImage::Format_ARGB32);
    pixel.fill(Qt::red);
    QVERIFY(pixel.save(themeRoot.filePath(QStringLiteral("16x16/apps/firefox.png"))));

    // theme state is process-global; restore it so later slots see a clean env
    const QStringList previousPaths = QIcon::themeSearchPaths();
    const QString previousTheme = QIcon::themeName();
    QIcon::setThemeSearchPaths({searchPath.path()});
    QIcon::setThemeName(QStringLiteral("fixturetheme"));

    const QIcon themed = QIcon::fromTheme(QStringLiteral("firefox"));
    QCOMPARE(themed.name(), QStringLiteral("firefox")); // premise

    const QVariant v = QVariant::fromValue(themed);
    QCOMPARE(sourceName(v), QStringLiteral("firefox"));
    QCOMPARE(classify(v), SourceKind::SvgOrIconName);

    QIcon::setThemeSearchPaths(previousPaths);
    QIcon::setThemeName(previousTheme);
}

void IconSourceClassifierTest::classify_localFileUrl_isLocalFile()
{
    QCOMPARE(classify(QVariant(QStringLiteral("file:///tmp/x.png"))), SourceKind::LocalFile);
}

void IconSourceClassifierTest::classify_plainName_isSvgOrIconName()
{
    QCOMPARE(classify(QVariant(QStringLiteral("firefox"))), SourceKind::SvgOrIconName);
}

void IconSourceClassifierTest::classify_relativeToken_isSvgOrIconName()
{
    QCOMPARE(classify(QVariant(QStringLiteral("plain-icon-name"))), SourceKind::SvgOrIconName);
}

void IconSourceClassifierTest::classify_namelessIcon_isIcon()
{
    // a pixmap-built QIcon has no theme name, so it routes to the Icon
    // branch; this is the branch capt's slot set left uncovered
    QPixmap pix(4, 4);
    pix.fill(Qt::red);
    const QIcon nameless(pix);
    QVERIFY(nameless.name().isEmpty()); // premise

    QCOMPARE(classify(QVariant::fromValue(nameless)), SourceKind::Icon);
}

void IconSourceClassifierTest::classify_qimage_isImage()
{
    // premise (capt pinned this instrument-first on Qt 6.11): a QImage
    // variant reaches the Image branch only because it fails the QIcon
    // conversion first - if Qt ever grows a QImage->QIcon variant
    // conversion, classification changes and this must be re-decided
    QImage img(4, 4, QImage::Format_ARGB32);
    img.fill(Qt::red);
    const QVariant v(img);
    QVERIFY(!v.canConvert<QIcon>());
    QVERIFY(v.canConvert<QImage>());

    QCOMPARE(classify(v), SourceKind::Image);
}

void IconSourceClassifierTest::classify_emptyVariant_isClear()
{
    // premise (capt pinned this instrument-first on Qt 6.11): a default
    // QVariant converts to neither QIcon nor QImage
    const QVariant empty;
    QVERIFY(!empty.canConvert<QIcon>());
    QVERIFY(!empty.canConvert<QImage>());

    QCOMPARE(classify(empty), SourceKind::Clear);
}

void IconSourceClassifierTest::classify_emptyString_isClear()
{
    QCOMPARE(classify(QVariant(QString())), SourceKind::Clear);
}

void IconSourceClassifierTest::filter_empty_isFiltered()
{
    QVERIFY(isFilteredSourceName(QString()));
}

void IconSourceClassifierTest::filter_executablePlaceholder_isFiltered()
{
    QVERIFY(isFilteredSourceName(QStringLiteral("application-x-executable")));
}

void IconSourceClassifierTest::filter_realName_isNotFiltered()
{
    QVERIFY(!isFilteredSourceName(QStringLiteral("firefox")));
}

void IconSourceClassifierTest::isValid_truthTable_data()
{
    QTest::addColumn<bool>("hasIcon");
    QTest::addColumn<bool>("hasSvg");
    QTest::addColumn<bool>("hasImage");
    QTest::addColumn<bool>("expected");

    QTest::newRow("none")       << false << false << false << false;
    QTest::newRow("icon only")  << true  << false << false << true;
    QTest::newRow("svg only")   << false << true  << false << true;
    QTest::newRow("image only") << false << false << true  << true;
    QTest::newRow("icon+svg")   << true  << true  << false << true;
    QTest::newRow("icon+image") << true  << false << true  << true;
    QTest::newRow("svg+image")  << false << true  << true  << true;
    QTest::newRow("all")        << true  << true  << true  << true;
}

void IconSourceClassifierTest::isValid_truthTable()
{
    QFETCH(bool, hasIcon);
    QFETCH(bool, hasSvg);
    QFETCH(bool, hasImage);
    QFETCH(bool, expected);

    const ResolvedIcon resolved{hasIcon, hasSvg, hasImage};
    QCOMPARE(resolved.isValid(), expected);
}

// QTEST_MAIN, not GUILESS: with QT_GUI_LIB defined it instantiates a
// QGuiApplication (offscreen via the ctest environment), which the themed
// icon engine and QPixmap construction require - under QCoreApplication
// QIcon::fromTheme() has no engine (name() comes back empty) and QPixmap
// aborts with "QGuiApplication required". capt stayed guiless and that is
// exactly why their slot set could not cover these two branches.
QTEST_MAIN(IconSourceClassifierTest)

#include "iconsourceclassifiertest.moc"
