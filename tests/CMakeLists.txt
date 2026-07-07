include(ECMAddTests)

# Behavioral tests drive the real compiled application code through the
# lattedock-core object library - no mocks of Latte's own logic, per
# docs/TESTING.md. QT_QPA_PLATFORM=offscreen keeps them headless.

ecm_add_test(importerregressiontest.cpp
    TEST_NAME importerregressiontest
    LINK_LIBRARIES lattedock-core Qt6::Test
)
set_tests_properties(importerregressiontest PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
target_include_directories(importerregressiontest PRIVATE
    ${CMAKE_SOURCE_DIR}/app
    ${CMAKE_BINARY_DIR}/app)
