# Qt Test suites. They read the shared fixtures (MOATBAR_FIXTURES_DIR).

function(moatbar_test name)
    qt_add_executable(${name} ${name}.cpp Fixtures.hpp)
    target_link_libraries(${name} PRIVATE moatbar_core Qt6::Test)
    target_compile_definitions(${name} PRIVATE MOATBAR_FIXTURES_DIR="${MOATBAR_FIXTURES_DIR}")
    moatbar_warnings(${name})
    add_test(NAME ${name} COMMAND ${name})
endfunction()

moatbar_test(tst_json)
moatbar_test(tst_snapshot)
moatbar_test(tst_client)

# The Quick View's model, from the same fixtures.
moatbar_test(tst_quickview)
target_link_libraries(tst_quickview PRIVATE moatbar_ui)

# The Activity window's filter, export and model.
moatbar_test(tst_activity)
target_link_libraries(tst_activity PRIVATE moatbar_ui)

# Notifications (new blocks, the rule throttle) and MoatBar's own settings.
moatbar_test(tst_settings)
target_link_libraries(tst_settings PRIVATE moatbar_ui)
