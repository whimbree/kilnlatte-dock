# Pure-core unit tests (docs/QML_EXTRACTION_PLAN.md, section D). Each core
# header under a units/ directory (or an app-subtree capt placement listed in
# app-subtree-units.list) gets exactly one ecm_add_test entry here, named
# <header-basename>test. scripts/coverage-ratchet.sh fails build-check if a
# header has no registered pair, so keep the naming mechanical.
include(ECMAddTests)
