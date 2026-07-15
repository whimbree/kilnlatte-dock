/*
    SPDX-License-Identifier: GPL-2.0-or-later

    QtQuick.Effects MultiEffect contracts, pinned at the flake's Qt. See
    README.md in this directory for the rules.

    Rendering-level behavior (what actually lands in the texture, which
    sampler warnings fire) is NOT observable here: the offscreen platform
    never initializes a scenegraph render loop, grabs return blank. These
    contracts pin the polish-level state machine instead - the proxy and
    padding decisions Latte's effect gating is built around, all readable
    without a frame ever rendering.
*/

import QtQuick
import QtQuick.Effects
import QtTest

TestCase {
    id: root
    name: "MultiEffectContracts"
    when: windowShown
    width: 120
    height: 60

    //! Contract: autoPaddingEnabled defaults to TRUE. Every MultiEffect in
    //! the tree must therefore disable it explicitly - autoPadding
    //! recomputes per frame and re-dirtied every shadowed window forever
    //! (18.2% idle CPU, e3376405), and it pads by blurMax*(1+blurMultiplier)
    //! = 256px per side regardless of the real shadow size. Depended on by:
    //! declarativeimports/components/ShadowedItem.qml and the qmleffectrules
    //! scan test; if the default ever flips to false the ban can relax.
    MultiEffect {
        id: defaultsFx
        width: 16; height: 16
    }

    function test_autoPaddingDefaultsEnabled() {
        verify(defaultsFx.autoPaddingEnabled,
               "MultiEffect autoPadding no longer defaults to true - "
               + "re-evaluate the tree-wide autoPaddingEnabled: false rule (e3376405)");
    }

    //! Contract: paddingRect components are PER-SIDE extras
    //! (x/y/width/height = extra pixels left/top/right/bottom), observable
    //! through itemRect: for a WxH effect the padded rect is
    //! (-x, -y, W+x+width, H+y+height). Treating width/height as totals
    //! drew every applet scaled and offset inside itself (ghost copies,
    //! 6c7001ce). Depended on by: ShadowedItem's static shadowPaddingPx
    //! rect and tst_shadoweditem's padding contract.
    Item {
        id: paddedSource
        width: 10; height: 10
    }

    MultiEffect {
        id: paddedFx
        width: 10; height: 10
        source: paddedSource
        autoPaddingEnabled: false
        paddingRect: Qt.rect(1, 2, 3, 4)
    }

    function test_paddingRectIsPerSide() {
        tryVerify(function() { return paddedFx.itemRect.width > 0; }, 5000,
                  "effect never initialized (needs window + size)");
        compare(paddedFx.itemRect, Qt.rect(-1, -2, 10 + 1 + 3, 10 + 2 + 4));
    }

    //! Contract: MultiEffect wraps a plain Item source in an internal
    //! ShaderEffectSource (hasProxySource true) and uses a layered source
    //! directly (hasProxySource false). The port's commit narratives call
    //! this "Qt6 does not auto-wrap" - the truth on this pin is sharper: it
    //! DOES wrap, but the wrap decision is made at polish time and, per the
    //! two contracts below, never revisited when layer.enabled changes.
    Item {
        id: plainSource
        width: 16; height: 16
        Rectangle { anchors.fill: parent; color: "red" }
    }

    MultiEffect {
        id: proxiedFx
        width: 16; height: 16
        source: plainSource
    }

    Item {
        id: layeredSource
        width: 16; height: 16
        layer.enabled: true
        Rectangle { anchors.fill: parent; color: "blue" }
    }

    MultiEffect {
        id: directFx
        width: 16; height: 16
        source: layeredSource
    }

    function test_plainSourceIsProxied_layeredSourceIsDirect() {
        tryVerify(function() { return proxiedFx.hasProxySource; }, 5000,
                  "plain Item sources are no longer proxied - the whole "
                  + "provider-duty audit needs a re-read");
        verify(!directFx.hasProxySource,
               "layered sources are no longer taken directly");
    }

    //! Contract: the source proxy does NOT repolish when the source item's
    //! layer.enabled flips OFF. A direct (layered) source whose layer drops
    //! leaves the effect sampling a dead provider: 'No QSGTexture provided'
    //! / 'not assigned a valid texture provider' per repaint. THIS is the
    //! contract that forces Latte's gating rule "a source stays a provider
    //! for the entire time an effect can sample it" (69baabf0, the applet
    //! colorizer visible gate, TaskIcon's forceMonochromaticIcons layer
    //! hold). If Qt starts repolishing here, those gates can relax.
    function test_proxyIgnoresLayerDisable() {
        verify(!directFx.hasProxySource, "precondition: direct while layered");
        layeredSource.layer.enabled = false;
        wait(200); //! several polish cycles - a repolish would have landed
        verify(!directFx.hasProxySource,
               "Qt now repolishes on layer disable - stale-provider gating "
               + "(colorizer visible gate, mono layer hold) can be revisited");
        layeredSource.layer.enabled = true;
    }

    //! Contract: same blindness in the other direction - a proxied plain
    //! source that LATER gains a layer keeps its proxy (wasteful but valid).
    //! This is why settings-stable layer gates are safe: whichever state the
    //! proxy saw first stays consistent for the effect's lifetime as long as
    //! the layer never flips off while the effect can sample.
    function test_proxyIgnoresLayerEnable() {
        verify(proxiedFx.hasProxySource, "precondition: proxied while plain");
        plainSource.layer.enabled = true;
        wait(200);
        verify(proxiedFx.hasProxySource,
               "Qt now repolishes on layer enable - re-read the provider "
               + "stability notes at the TaskIcon/colorizer gates");
        plainSource.layer.enabled = false;
    }
}
