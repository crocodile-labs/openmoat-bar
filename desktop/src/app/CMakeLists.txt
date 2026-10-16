# The tray app. Logic belongs in moatbar_core with a test; this is presentation.
qt_add_executable(moatbar_app WIN32
    main.cpp
    SnapshotStore.hpp SnapshotStore.cpp
    TrayIcon.hpp TrayIcon.cpp
    TrayMenu.hpp TrayMenu.cpp
    TrayController.hpp TrayController.cpp
)
set_target_properties(moatbar_app PROPERTIES OUTPUT_NAME "moatbar")
target_compile_definitions(moatbar_app PRIVATE MOATBAR_VERSION="${PROJECT_VERSION}")
target_link_libraries(moatbar_app PRIVATE moatbar_core Qt6::Gui Qt6::Widgets)
moatbar_warnings(moatbar_app)

# The logo and agent icons are shared with the macOS app.
set(MOATBAR_SHARED_RESOURCES "${CMAKE_CURRENT_SOURCE_DIR}/../../../Sources/MoatBar/Resources")
qt_add_resources(moatbar_app "shared_images"
    PREFIX "/"
    BASE "${MOATBAR_SHARED_RESOURCES}"
    FILES
        "${MOATBAR_SHARED_RESOURCES}/logo-float@4x.png"
        "${MOATBAR_SHARED_RESOURCES}/agent-claude@3x.png"
        "${MOATBAR_SHARED_RESOURCES}/agent-codex@3x.png"
        "${MOATBAR_SHARED_RESOURCES}/agent-cursor@3x.png"
)

install(TARGETS moatbar_app RUNTIME DESTINATION bin)
