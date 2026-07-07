kcoreaddons_add_plugin(latte_packagestructure_indicator SOURCES indicatorpackage.cpp INSTALL_NAMESPACE kpackage/packagestructure)
set_target_properties(latte_packagestructure_indicator PROPERTIES OUTPUT_NAME latte_indicator)

target_link_libraries(latte_packagestructure_indicator
   KF6::I18n
   KF6::Package
)

# KDEInstallDirs6 dropped the kservicetypes dir (servicetypes are a KF5
# concept). Keep the file installed at a deterministic path until Phase 3
# decides the KPackage metadata story for indicators.
install(FILES latte-indicator.desktop DESTINATION ${KDE_INSTALL_DATADIR}/kservicetypes6)
