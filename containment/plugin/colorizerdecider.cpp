/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "colorizerdecider.h"

// Qt
#include <QDebug>
#include <QMetaEnum>

namespace Latte {
namespace Containment {

namespace {

//! true when the raw config int names a real enumerator - the settings
//! arrive from outside (plasmoid configuration), so an unknown value is
//! refused at this boundary, never walked into the tree
template<typename Enum>
bool isKnownEnumValue(int raw)
{
    return QMetaEnum::fromType<Enum>().valueToKey(raw) != nullptr;
}

}

ColorizerDecider::ColorizerDecider(QObject *parent)
    : QObject(parent)
{
    connect(this, &ColorizerDecider::inputsChanged, this, &ColorizerDecider::recomputeDecision);
    recomputeDecision();
}

int ColorizerDecider::themeColors() const
{
    return m_themeColors;
}

void ColorizerDecider::setThemeColors(int themeColors)
{
    if (m_themeColors == themeColors) {
        return;
    }

    if (!isKnownEnumValue<Types::ThemeColorsGroup>(themeColors)) {
        qCritical() << "ColorizerDecider: unknown themeColors setting" << themeColors
                    << "- refusing it; the colorizer renders plasma-default until it is fixed";
    }

    m_themeColors = themeColors;
    Q_EMIT inputsChanged();
}

int ColorizerDecider::windowColors() const
{
    return m_windowColors;
}

void ColorizerDecider::setWindowColors(int windowColors)
{
    if (m_windowColors == windowColors) {
        return;
    }

    if (!isKnownEnumValue<Types::WindowColorsGroup>(windowColors)) {
        qCritical() << "ColorizerDecider: unknown windowColors setting" << windowColors
                    << "- refusing it; window color tracking stays off until it is fixed";
    }

    m_windowColors = windowColors;
    Q_EMIT inputsChanged();
}

QObject *ColorizerDecider::applyTheme() const
{
    return m_applyTheme;
}

QObject *ColorizerDecider::schemeColors() const
{
    return m_schemeColors;
}

bool ColorizerDecider::mustBeShown() const
{
    return m_mustBeShown;
}

bool ColorizerDecider::useLayoutTextColor() const
{
    return m_useLayoutTextColor;
}

ColorizerDecision::ColorizerEnv ColorizerDecider::snapshotEnv() const
{
    ColorizerDecision::ColorizerEnv env;

    //! a refused settings value renders as the do-nothing default
    //! (the setter already reported it loudly)
    env.themeColors = isKnownEnumValue<Types::ThemeColorsGroup>(m_themeColors)
            ? static_cast<Types::ThemeColorsGroup>(m_themeColors)
            : Types::PlasmaThemeColors;
    env.windowColors = isKnownEnumValue<Types::WindowColorsGroup>(m_windowColors)
            ? static_cast<Types::WindowColorsGroup>(m_windowColors)
            : Types::NoneWindowColors;

    env.graphicsSystemAccelerated = m_graphicsSystemAccelerated;
    env.compositingActive = m_compositingActive;
    env.themeExtendedExists = m_themeExtendedExists;
    env.plasmaThemeIsLight = m_plasmaThemeIsLight;

    env.windowsTrackerEnabled = m_windowsTrackerEnabled;
    //! resolved-pointer facts, not guesses: QPointer nulls on destruction
    env.selectedActiveWindowSchemeExists = !m_selectedActiveWindowScheme.isNull();
    env.currentScreenActiveWindowSchemeExists = !m_currentScreenActiveWindowScheme.isNull();
    env.touchingWindowSchemeExists = !m_touchingWindowScheme.isNull();
    env.existsWindowTouching = m_existsWindowTouching;
    env.existsWindowTouchingEdge = m_existsWindowTouchingEdge;
    env.activeWindowTouching = m_activeWindowTouching;
    env.activeWindowTouchingEdge = m_activeWindowTouchingEdge;
    env.layoutExists = m_layoutExists;

    env.plasmaBackgroundForPopups = m_plasmaBackgroundForPopups;
    env.hasExpandedApplet = m_hasExpandedApplet;
    env.userShowPanelBackground = m_userShowPanelBackground;
    env.plasmaStyleBusyForTouchingBusyVerticalView = m_plasmaStyleBusyForTouchingBusyVerticalView;
    env.forceSolidPanel = m_forceSolidPanel;
    env.forcePanelForBusyBackground = m_forcePanelForBusyBackground;
    env.inConfigureAppletsMode = m_inConfigureAppletsMode;
    env.editModeTextColorIsBright = m_editModeTextColorIsBright;
    env.currentBackgroundBrightness = m_currentBackgroundBrightness;
    env.backgroundStoredOpacity = m_backgroundStoredOpacity;

    return env;
}

QObject *ColorizerDecider::resolveThemeObject(ColorizerDecision::ThemeSource source) const
{
    using ColorizerDecision::ThemeSource;

    switch (source) {
    case ThemeSource::PlasmaDefault:
        return m_plasmaTheme;
    case ThemeSource::SelectedActiveWindowScheme:
        return m_selectedActiveWindowScheme;
    case ThemeSource::CurrentScreenActiveWindowScheme:
        return m_currentScreenActiveWindowScheme;
    case ThemeSource::TouchingWindowScheme:
        return m_touchingWindowScheme;
    case ThemeSource::DarkTheme:
        return m_darkTheme;
    case ThemeSource::LightTheme:
        return m_lightTheme;
    case ThemeSource::LayoutScheme:
        return m_layoutScheme;
    }

    Q_UNREACHABLE_RETURN(nullptr);
}

QObject *ColorizerDecider::resolveSchemeFileObject(ColorizerDecision::SchemeFile file, QObject *applied) const
{
    using ColorizerDecision::SchemeFile;

    //! Total mapping, deliberately safer than the Qt5 QML: a chosen source
    //! whose live object is null yields null here, and the shell publishes
    //! the "kdeglobals" literal - where the QML would have thrown a
    //! TypeError reading .schemeFile of null (latent there, practically
    //! unreachable: layout schemes fall back to the kdeglobals SchemeColors
    //! instance).
    switch (file) {
    case SchemeFile::AppliedScheme:
        return applied;
    case SchemeFile::LightThemeFile:
        return m_lightTheme;
    case SchemeFile::DarkThemeFile:
        return m_darkTheme;
    case SchemeFile::DefaultThemeFile:
        return m_plasmaTheme;
    case SchemeFile::KdeGlobalsFallback:
        return nullptr;
    }

    Q_UNREACHABLE_RETURN(nullptr);
}

void ColorizerDecider::logEditModeBreadcrumb(const ColorizerDecision::ColorizerEnv &env,
                                             ColorizerDecision::SchemeFile file) const
{
    using ColorizerDecision::SchemeFile;

    //! the Qt5 Manager.qml logged these on every edit-mode scheme
    //! re-selection; kept verbatim (same trigger, same text) so live
    //! debugging notes stay comparable across the extraction
    if (!(env.inConfigureAppletsMode && env.themeColors == Types::SmartThemeColors)) {
        return;
    }

    switch (file) {
    case SchemeFile::LightThemeFile:
        qDebug() << "light theme... : " << env.plasmaThemeIsLight;
        break;
    case SchemeFile::DarkThemeFile:
        qDebug() << "dark theme... : " << !env.plasmaThemeIsLight;
        break;
    case SchemeFile::DefaultThemeFile:
        qDebug() << "default theme... : " << env.plasmaThemeIsLight;
        break;
    case SchemeFile::AppliedScheme:
    case SchemeFile::KdeGlobalsFallback:
        break;
    }
}

void ColorizerDecider::recomputeDecision()
{
    const ColorizerDecision::ColorizerEnv env = snapshotEnv();

    const ColorizerDecision::ThemeSource source = ColorizerDecision::chooseThemeSource(env);
    QObject *applied = resolveThemeObject(source);

    const bool shown = ColorizerDecision::mustBeShown(env, source, applied != nullptr);
    const ColorizerDecision::SchemeFile file = ColorizerDecision::chooseSchemeFile(env, source, applied != nullptr);
    QObject *schemeObject = resolveSchemeFileObject(file, applied);
    const bool layoutText = ColorizerDecision::useLayoutTextColor(env);

    if (applied == m_applyTheme && schemeObject == m_schemeColors
            && shown == m_mustBeShown && layoutText == m_useLayoutTextColor) {
        return;
    }

    logEditModeBreadcrumb(env, file);

    m_applyTheme = applied;
    m_schemeColors = schemeObject;
    m_mustBeShown = shown;
    m_useLayoutTextColor = layoutText;

    Q_EMIT decisionChanged();
}

}
}
