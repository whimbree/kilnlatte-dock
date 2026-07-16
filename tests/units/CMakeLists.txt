# Pure-core unit tests (docs/QML_EXTRACTION_PLAN.md, section D). Each core
# header under a units/ directory (or an app-subtree capt placement listed in
# app-subtree-units.list) gets exactly one latte_add_unit_test entry here,
# named <header-basename>test. scripts/coverage-ratchet.sh fails build-check
# if a header has no registered pair, so keep the naming mechanical.
include(ECMAddTests)

# Every pure-core test runs under ASan+UBSan (docs/TESTING.md, the step-2.5
# rule). The cores are compiled INTO the test binary (header-only today;
# a .cpp core must be added to the test's SOURCES, never linked from an
# unsanitized object library, or the code under test runs uninstrumented
# and the sanitizers are theater). -fno-sanitize-recover turns any UBSan
# find into a test failure instead of a log line.
set(LATTE_UNIT_SANITIZE_FLAGS -fsanitize=address,undefined -fno-sanitize-recover=all)

function(latte_add_unit_test _name)
    # extra arguments: additional sources compiled into the binary
    ecm_add_test(${_name}.cpp ${ARGN}
        TEST_NAME ${_name}
        LINK_LIBRARIES Qt6::Test
    )
    set_tests_properties(${_name} PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
    target_compile_options(${_name} PRIVATE ${LATTE_UNIT_SANITIZE_FLAGS})
    target_link_options(${_name} PRIVATE ${LATTE_UNIT_SANITIZE_FLAGS})
endfunction()

# EX-22 ActivitySetAlgebra: header-only pure core, no Latte link needed.
latte_add_unit_test(activitysetalgebratest)
target_include_directories(activitysetalgebratest PRIVATE
    ${CMAKE_SOURCE_DIR}/app)

# EX-01 PreviewSwitchEngine: header-only pure core, injected clock.
latte_add_unit_test(previewswitchenginetest)

# EX-03 ParabolicMathCore: header-only pure math.
latte_add_unit_test(parabolicmathtest)

# EX-02 ParabolicRouter: header-only pure routing walk.
latte_add_unit_test(parabolicroutertest)
