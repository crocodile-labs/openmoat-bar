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
