# Screenshots of the tray menu and icons, drawn offscreen from the test
# fixtures. CI runs it on Linux and Windows and keeps the images with the run.
qt_add_executable(moatbar_shots shots.cpp)
# Qt Test only for the fixture helpers it shares with the tests.
target_link_libraries(moatbar_shots PRIVATE moatbar_ui Qt6::Test)
target_compile_definitions(moatbar_shots PRIVATE MOATBAR_FIXTURES_DIR="${MOATBAR_FIXTURES_DIR}")
moatbar_warnings(moatbar_shots)
