add_definitions(-DTRANSLATION_DOMAIN=\"plasma_containmentactions_lattecontextmenu\")

set(contextmenu_SRCS
    generictools.cpp
    layoutmenuitemwidget.cpp
    menu.cpp
)

add_library(plasma_containmentactions_lattecontextmenu MODULE ${contextmenu_SRCS})

# Plasma's PluginLoader looks up containmentactions plugins by the relative
# path "plasma/containmentactions/<KPlugin.Id>", so the installed .so name must
# equal the metadata Id (org.kde.latte.contextmenu). The built-in Plasma
# containmentactions (org.kde.contextmenu.so, org.kde.applauncher.so) follow the
# same convention. Without this rename KPluginMetaData::findPluginById() never
# finds the plugin, Containment::setContainmentActions() silently no-ops, and
# right-click on the dock has no menu (so edit mode is unreachable).
set_target_properties(plasma_containmentactions_lattecontextmenu PROPERTIES
    OUTPUT_NAME "org.kde.latte.contextmenu"
    PREFIX ""
)

target_link_libraries(plasma_containmentactions_lattecontextmenu
                        Qt6::DBus
                        Qt6::Widgets
                        KF6::I18n
                        KF6::XmlGui
                        Plasma::Plasma)

install(TARGETS plasma_containmentactions_lattecontextmenu DESTINATION ${KDE_INSTALL_PLUGINDIR}/plasma/containmentactions)
