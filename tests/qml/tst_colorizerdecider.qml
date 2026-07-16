/*
    SPDX-FileCopyrightText: 2026 Bree Spektor
    SPDX-FileCopyrightText: 2026 Latte Dock contributors
    SPDX-License-Identifier: GPL-2.0-or-later
*/

//! Shell pin for the colorizer decisions (EX-12). The applyTheme tree,
//! mustBeShown, scheme-file selection and the edit-mode text override the
//! colorizer Manager.qml used to compute in bindings live in the
//! ColorizerDecision core now (containment/plugin/units/colorizerdecision.h;
//! tests/units/colorizerdecisiontest.cpp pins the full decision tables).
//! What must stay pinned HERE is the boundary: the ColorizerDecider the
//! containment instantiates resolves from the staged install, maps the
//! core's enum choices onto the bound candidate objects, holds the
//! null-schemeColors = "kdeglobals" contract the shell's scheme property
//! relies on, and refuses unknown settings values loudly instead of
//! walking them into the tree.

import QtQuick
import QtTest

import org.kde.latte.private.containment 0.1 as LatteContainment

TestCase {
    id: root
    name: "ColorizerDeciderShell"

    //! stand-ins for the SchemeColors instances the real Manager binds;
    //! the decider only routes them, so plain objects with a schemeFile
    //! member are honest fakes
    readonly property QtObject fakeDefaultTheme: QtObject {
        readonly property string schemeFile: "/fake/default.colors"
    }
    readonly property QtObject fakeDarkTheme: QtObject {
        readonly property string schemeFile: "/fake/dark.colors"
    }
    readonly property QtObject fakeLightTheme: QtObject {
        readonly property string schemeFile: "/fake/light.colors"
    }
    readonly property QtObject fakeWindowScheme: QtObject {
        readonly property string schemeFile: "/fake/window.colors"
    }

    LatteContainment.ColorizerDecider {
        id: decider
    }

    function init() {
        //! tests share the decider; each starts from the real Manager's
        //! resting state: themeExtended resolved, plasma colors, light theme
        decider.plasmaTheme = root.fakeDefaultTheme;
        decider.darkTheme = root.fakeDarkTheme;
        decider.lightTheme = root.fakeLightTheme;
        decider.layoutScheme = null;
        decider.selectedActiveWindowScheme = null;
        decider.currentScreenActiveWindowScheme = null;
        decider.touchingWindowScheme = null;
        decider.themeColors = LatteContainment.Types.PlasmaThemeColors;
        decider.windowColors = LatteContainment.Types.NoneWindowColors;
        decider.graphicsSystemAccelerated = true;
        decider.compositingActive = true;
        decider.themeExtendedExists = true;
        decider.plasmaThemeIsLight = true;
        decider.windowsTrackerEnabled = false;
        decider.layoutExists = false;
        decider.inConfigureAppletsMode = false;
        decider.backgroundStoredOpacity = 1.0;
        decider.currentBackgroundBrightness = -1000;
    }

    function test_plasmaDefaultRestingState() {
        compare(decider.applyTheme, root.fakeDefaultTheme);
        verify(!decider.mustBeShown);
        compare(decider.schemeColors, root.fakeDefaultTheme);
        verify(!decider.useLayoutTextColor);
    }

    function test_darkColorsOnLightThemeAppliesTheDarkScheme() {
        //! the 79ca3360 real-config flip through the boundary
        decider.themeColors = LatteContainment.Types.DarkThemeColors;

        compare(decider.applyTheme, root.fakeDarkTheme);
        verify(decider.mustBeShown);
        compare(decider.schemeColors, root.fakeDarkTheme);
    }

    function test_darkColorsOnDarkThemeAliasesThePlasmaDefault() {
        //! in the live tree darkTheme IS the defaultTheme instance on a
        //! dark session; the decider carries that identity as algebra, so
        //! distinct fakes still resolve to the default's scheme file
        decider.themeColors = LatteContainment.Types.DarkThemeColors;
        decider.plasmaThemeIsLight = false;

        verify(!decider.mustBeShown);
        compare(decider.schemeColors, root.fakeDefaultTheme);
    }

    function test_activeWindowSchemeArrivalFlipsTheDecision() {
        //! 1f835402's probe lesson at the boundary: binding the scheme
        //! object alone must flip the applied theme
        decider.windowColors = LatteContainment.Types.ActiveWindowColors;
        decider.windowsTrackerEnabled = true;
        compare(decider.applyTheme, root.fakeDefaultTheme);

        decider.selectedActiveWindowScheme = root.fakeWindowScheme;
        compare(decider.applyTheme, root.fakeWindowScheme);
        verify(decider.mustBeShown);
        compare(decider.schemeColors, root.fakeWindowScheme);
    }

    function test_destroyedSchemeObjectCannotStayApplied() {
        //! the QPointer guard: a scheme object dying between rebinds must
        //! read back as null, never dangle
        var doomed = Qt.createQmlObject(
            "import QtQuick; QtObject { readonly property string schemeFile: '/fake/doomed.colors' }",
            root, "doomedScheme");
        decider.windowColors = LatteContainment.Types.ActiveWindowColors;
        decider.windowsTrackerEnabled = true;
        decider.selectedActiveWindowScheme = doomed;
        compare(decider.applyTheme, doomed);

        doomed.destroy();
        wait(0); //! deferred deletion runs on the event loop

        verify(!decider.applyTheme);
    }

    function test_missingThemeExtendedFallsToKdeglobals() {
        decider.plasmaTheme = null;
        decider.darkTheme = null;
        decider.lightTheme = null;
        decider.themeExtendedExists = false;

        verify(!decider.applyTheme);
        verify(!decider.mustBeShown);
        //! null schemeColors is the named kdeglobals fallback the shell maps
        verify(!decider.schemeColors);
    }

    function test_editModeSmartContrastPublishesTheReversedFile() {
        decider.themeColors = LatteContainment.Types.SmartThemeColors;
        decider.inConfigureAppletsMode = true;
        decider.editModeTextColorIsBright = true; //! matches the light theme

        verify(decider.mustBeShown); //! edit mode + smart shows regardless
        compare(decider.schemeColors, root.fakeDarkTheme);
    }

    function test_layoutTextOverrideFollowsTheOpacityThreshold() {
        decider.themeColors = LatteContainment.Types.SmartThemeColors;
        decider.inConfigureAppletsMode = true;
        decider.layoutExists = true;

        decider.backgroundStoredOpacity = 0.39;
        verify(decider.useLayoutTextColor);

        decider.backgroundStoredOpacity = 0.40;
        verify(!decider.useLayoutTextColor);
    }

    function test_unknownSettingsAreRefusedLoudly() {
        //! the boundary refusal: an out-of-range config int reports itself
        //! and renders as plasma default instead of walking the tree
        decider.themeColors = 999;

        compare(decider.applyTheme, root.fakeDefaultTheme);
        verify(!decider.mustBeShown);
    }
}
