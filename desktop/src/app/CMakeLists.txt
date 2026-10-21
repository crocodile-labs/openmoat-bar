# The tray app. Logic belongs in moatbar_core with a test; this is presentation.
# The views are a library so the screenshot tool (tools/) draws the same menu.
qt_add_library(moatbar_ui STATIC
    SnapshotStore.hpp SnapshotStore.cpp
    TrayIcon.hpp TrayIcon.cpp
    TrayMenu.hpp TrayMenu.cpp
    TrayController.hpp TrayController.cpp
    QuickViewModel.hpp QuickViewModel.cpp
    DetailsModel.hpp DetailsModel.cpp
    QuickView.hpp QuickView.cpp
    EventViews.hpp EventViews.cpp
    ActivityModel.hpp ActivityModel.cpp
    ActivityWindow.hpp ActivityWindow.cpp
    Preferences.hpp Preferences.cpp
    SettingsWindows.hpp SettingsWindows.cpp
    SingleInstance.hpp SingleInstance.cpp
    Notify.hpp Notify.cpp
)
target_link_libraries(moatbar_ui PUBLIC moatbar_core Qt6::Gui Qt6::Widgets Qt6::Network Qt6::Qml Qt6::Quick
                                        Qt6::QuickControls2)
if(TARGET Qt6::DBus)
    target_link_libraries(moatbar_ui PUBLIC Qt6::DBus)
    target_compile_definitions(moatbar_ui PRIVATE MOATBAR_HAS_DBUS)
endif()
moatbar_warnings(moatbar_ui)

# The Quick View's QML, loaded from qrc:/qml/.
qt_add_resources(moatbar_ui "quick_view"
    PREFIX "/"
    FILES
        qml/qmldir
        qml/Theme.qml
        qml/QuickView.qml
        qml/AgentTabs.qml
        qml/AgentIcon.qml
        qml/AgentDetail.qml
        qml/Header.qml
        qml/Card.qml
        qml/TodayChart.qml
        qml/NavRow.qml
        qml/EventRow.qml
        qml/Decision.qml
        qml/CopyRow.qml
        qml/DetailRow.qml
        qml/LinkRow.qml
        qml/SectionHeader.qml
        qml/PageHeader.qml
        qml/Divider.qml
        qml/Footer.qml
        qml/ActivityWindow.qml
        qml/SettingsWindow.qml
        qml/WelcomeWindow.qml
)

# The logo and agent icons are shared with the macOS app.
set(MOATBAR_SHARED_RESOURCES "${CMAKE_CURRENT_SOURCE_DIR}/../../../Sources/MoatBar/Resources")
qt_add_resources(moatbar_ui "shared_images"
    PREFIX "/"
    BASE "${MOATBAR_SHARED_RESOURCES}"
    FILES
        "${MOATBAR_SHARED_RESOURCES}/logo-float@4x.png"
        "${MOATBAR_SHARED_RESOURCES}/agent-claude@3x.png"
        "${MOATBAR_SHARED_RESOURCES}/agent-codex@3x.png"
        "${MOATBAR_SHARED_RESOURCES}/agent-cursor@3x.png"
        "${MOATBAR_SHARED_RESOURCES}/agent-openclaw@3x.png"
        "${MOATBAR_SHARED_RESOURCES}/agent-copilot@3x.png"
        "${MOATBAR_SHARED_RESOURCES}/agent-pi@3x.png"
        "${MOATBAR_SHARED_RESOURCES}/agent-gemini@3x.png"
)

qt_add_executable(moatbar_app WIN32 main.cpp)
set_target_properties(moatbar_app PROPERTIES OUTPUT_NAME "moatbar")
target_compile_definitions(moatbar_app PRIVATE MOATBAR_VERSION="${PROJECT_VERSION}")
target_link_libraries(moatbar_app PRIVATE moatbar_ui)
moatbar_warnings(moatbar_app)

install(TARGETS moatbar_app RUNTIME DESTINATION bin)
if(UNIX AND NOT APPLE)
    # The app menu entry and its icon, also what the AppImage is built from.
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/../../packaging/dev.openmoat.moatbar.desktop"
        DESTINATION share/applications)
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/../../../docs/images/app-icon.png"
        DESTINATION share/icons/hicolor/256x256/apps RENAME dev.openmoat.moatbar.png)
endif()
