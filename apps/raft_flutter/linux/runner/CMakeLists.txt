cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "vsync_driver.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# QA-only, additive readback. Product builds omit the observer and dependency.
if("$ENV{RAFT_QA_ENGINE_INSTRUMENTATION}" STREQUAL "1")
  pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)
  target_sources(${BINARY_NAME} PRIVATE "desktop_qa_identity.cc")
  target_compile_definitions(${BINARY_NAME} PRIVATE RAFT_MULTIWINDOW_QA=1)
  target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::WAYLAND_CLIENT)
endif()
