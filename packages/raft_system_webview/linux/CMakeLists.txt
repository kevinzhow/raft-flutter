cmake_minimum_required(VERSION 3.24)
project(raft_system_webview LANGUAGES CXX)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WEBKIT REQUIRED IMPORTED_TARGET webkit2gtk-4.1>=2.40)
pkg_check_modules(WEBKIT_EXTENSION REQUIRED IMPORTED_TARGET webkit2gtk-web-extension-4.1>=2.40)
set(PLUGIN_NAME raft_system_webview_plugin)
add_library(${PLUGIN_NAME} SHARED raft_system_webview_plugin.cc native_host.cc native_view.cc
  trusted_navigation.cc extension_paths.cc native_snapshot.cc)
apply_standard_settings(${PLUGIN_NAME})
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)
target_compile_options(${PLUGIN_NAME} PRIVATE -Wno-deprecated-declarations)
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter PkgConfig::GTK PkgConfig::WEBKIT ${CMAKE_DL_LIBS})
set(raft_system_webview_bundled_libraries "" PARENT_SCOPE)

# Application adapter only: dynamically links the distribution engine ABI.
# The app installs this target after its bundle-clean rule into lib/raft-webview.
add_library(raft_system_webview_extension MODULE trusted_link_extension.cc)
apply_standard_settings(raft_system_webview_extension)
target_compile_features(raft_system_webview_extension PRIVATE cxx_std_17)
target_compile_options(raft_system_webview_extension PRIVATE -Wno-deprecated-declarations)
target_link_libraries(raft_system_webview_extension PRIVATE PkgConfig::WEBKIT_EXTENSION)
set_target_properties(raft_system_webview_extension PROPERTIES
  CXX_VISIBILITY_PRESET hidden INSTALL_RPATH "$ORIGIN/..")
add_dependencies(${PLUGIN_NAME} raft_system_webview_extension)
