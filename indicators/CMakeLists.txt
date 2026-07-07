# relative destinations so cmake --install --prefix and DESTDIR staging both
# relocate; the old ${CMAKE_INSTALL_PREFIX}-prefixed form baked the configure
# prefix into the install rules
install(DIRECTORY default DESTINATION ${KDE_INSTALL_DATADIR}/latte/indicators)
install(DIRECTORY org.kde.latte.plasma DESTINATION ${KDE_INSTALL_DATADIR}/latte/indicators)
install(DIRECTORY org.kde.latte.plasmatabstyle DESTINATION ${KDE_INSTALL_DATADIR}/latte/indicators)
