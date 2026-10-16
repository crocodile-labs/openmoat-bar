# Everything that works without a screen: running moat, decoding its JSON,
# counting, and deciding what the tray icon shows. Qt Core only.
qt_add_library(moatbar_core STATIC
    Result.hpp
    Models.hpp Models.cpp
    Json.hpp Json.cpp
    MoatClient.hpp MoatClient.cpp
    Snapshot.hpp Snapshot.cpp
    IconState.hpp IconState.cpp
    SecurityChecks.hpp SecurityChecks.cpp
    Text.hpp Text.cpp
)
target_include_directories(moatbar_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/..)
target_link_libraries(moatbar_core PUBLIC Qt6::Core)
moatbar_warnings(moatbar_core)
