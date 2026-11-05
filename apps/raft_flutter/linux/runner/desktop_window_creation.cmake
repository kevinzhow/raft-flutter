# Pinned desktop_multi_window0.3.1. Adapt only a private build-local copy;
# never write into pub-cache or replace the existing channel/handler owners.
set(RAFT_DESKTOP_WINDOW_COPY_HELPER "${CMAKE_CURRENT_LIST_DIR}/../../../../tool/desktop_window_creation.py")
function(raft_copy_window_control original destination)
  find_package(Python3 COMPONENTS Interpreter REQUIRED)
  execute_process(COMMAND "${Python3_EXECUTABLE}" -I "${RAFT_DESKTOP_WINDOW_COPY_HELPER}"
    --source "${original}" --destination "${destination}"
    RESULT_VARIABLE copy_result ERROR_VARIABLE copy_error)
  if(NOT copy_result EQUAL 0)
    message(FATAL_ERROR "The private creation-control copy was refused: ${copy_error}")
  endif()
endfunction()

function(raft_guard_window_creation runner)
  get_target_property(plugin_dir desktop_multi_window_plugin SOURCE_DIR)
  get_target_property(plugin_sources desktop_multi_window_plugin SOURCES)
  set(patched "${CMAKE_CURRENT_BINARY_DIR}/raft_desktop_multi_window_plugin.cc")
  raft_copy_window_control("${plugin_dir}/desktop_multi_window_plugin.cc" "${patched}")
  set(guarded_sources)
  foreach(source IN LISTS plugin_sources)
    if(source STREQUAL "desktop_multi_window_plugin.cc" OR
       source STREQUAL "${plugin_dir}/desktop_multi_window_plugin.cc")
      list(APPEND guarded_sources "${patched}")
    elseif(IS_ABSOLUTE "${source}")
      list(APPEND guarded_sources "${source}")
    else()
      list(APPEND guarded_sources "${plugin_dir}/${source}")
    endif()
  endforeach()
  set_property(TARGET desktop_multi_window_plugin PROPERTY SOURCES "${guarded_sources}")
  target_include_directories(desktop_multi_window_plugin PRIVATE "${plugin_dir}")
  # One specific C predicate; do not export the whole runner with -rdynamic.
  target_link_options(${runner} PRIVATE
    "-Wl,--export-dynamic-symbol=raft_desktop_window_creation_allowed")
endfunction()
