cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "raft_updater")
project(${PROJECT_NAME} LANGUAGES CXX)

# Must not be changed: the generated registrant links this target.
set(PLUGIN_NAME "raft_updater_plugin")

# WinSparkle 0.9+ is the first release with EdDSA (ed25519) verification.
# Pinned by hash; the DLL is bundled next to the executable and the import
# library is only used at link time.
include(FetchContent)
if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()
FetchContent_Declare(raft_winsparkle
  URL https://github.com/vslavik/winsparkle/releases/download/v0.9.4/WinSparkle-0.9.4.zip
  URL_HASH SHA256=6037df37fc263bd1650a1c4949681a9d40ffe991d01f35892a406cb5d103c976
)
FetchContent_MakeAvailable(raft_winsparkle)
set(WINSPARKLE_DIR "${raft_winsparkle_SOURCE_DIR}")
if(NOT EXISTS "${WINSPARKLE_DIR}/x64/Release/WinSparkle.lib")
  # The archive has a single top-level WinSparkle-<version> directory.
  file(GLOB WINSPARKLE_CANDIDATES LIST_DIRECTORIES true "${raft_winsparkle_SOURCE_DIR}/WinSparkle-*")
  list(GET WINSPARKLE_CANDIDATES 0 WINSPARKLE_DIR)
endif()
set(WINSPARKLE_DLL "${WINSPARKLE_DIR}/x64/Release/WinSparkle.dll")
set(WINSPARKLE_LIB "${WINSPARKLE_DIR}/x64/Release/WinSparkle.lib")

add_library(${PLUGIN_NAME} SHARED
  "raft_updater_plugin.cpp"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(${PLUGIN_NAME} PRIVATE "${WINSPARKLE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin "${WINSPARKLE_LIB}")

# Bundled next to raft_flutter.exe by the app's install step.
set(raft_updater_bundled_libraries
  "${WINSPARKLE_DLL}"
  PARENT_SCOPE
)
