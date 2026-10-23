cmake_minimum_required(VERSION 3.21)

project(MoatBarDesktop
    VERSION 0.3.0
    DESCRIPTION "OpenMoat Bar for Linux and Windows: what OpenMoat does for your coding agents"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# 6.4 is what Ubuntu 24.04 and Debian 12 ship; CI builds with it and with 6.7.
find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Widgets Network Qml Quick QuickControls2 Test)
if(UNIX AND NOT APPLE)
    # Notifications without a tray go to the freedesktop service on D-Bus.
    find_package(Qt6 6.4 REQUIRED COMPONENTS DBus)
endif()
qt_standard_project_setup()

option(MOATBAR_WARNINGS_AS_ERRORS "Fail the build on compiler warnings (GCC/Clang)" ON)

# Strict warnings for our own targets. Qt's headers come from imported targets,
# which CMake treats as system headers, so they stay quiet.
function(moatbar_warnings target)
    if(MSVC)
        target_compile_options(${target} PRIVATE /W4 /permissive- /utf-8 /Zc:__cplusplus)
    else()
        target_compile_options(${target} PRIVATE
            -Wall -Wextra -Wpedantic -Wnon-virtual-dtor -Woverloaded-virtual
            $<$<BOOL:${MOATBAR_WARNINGS_AS_ERRORS}>:-Werror>)
    endif()
    target_compile_definitions(${target} PRIVATE
        QT_NO_CAST_FROM_ASCII QT_NO_CAST_TO_ASCII QT_NO_URL_CAST_FROM_STRING QT_USE_QSTRINGBUILDER)
endfunction()

# The macOS app's fixtures (Tests/MoatBarCoreTests/Fixtures), shared by the
# tests and the screenshot tool so both apps are held to the same moat JSON.
set(MOATBAR_FIXTURES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../Tests/MoatBarCoreTests/Fixtures")

add_subdirectory(src/core)
add_subdirectory(src/app)
add_subdirectory(tools)

enable_testing()
add_subdirectory(tests)
