# Compatibility backport for flutter_inappwebview_linux 0.1.0-beta.1 and the
# reviewed WPE 2.54 SDK. Keep the shared Pub cache unchanged. Copy the whole
# plugin source tree so internal quoted includes and types remain consistent.
function(raft_fix_wpe_compatibility)
  set(plugin flutter_inappwebview_linux_plugin)
  if(NOT TARGET ${plugin})
    message(FATAL_ERROR "The reviewed Linux HTML renderer is missing")
  endif()
  get_target_property(plugin_dir ${plugin} SOURCE_DIR)
  set(settings "in_app_webview/in_app_webview_settings.cc")
  file(SHA256 "${plugin_dir}/${settings}" settings_hash)
  if(NOT settings_hash STREQUAL "4288f88084645211d79693855a70c294bbfefed2c15c5adf7ad57695ac0cece4")
    message(FATAL_ERROR "Review the WPE compatibility backport for the changed plugin source")
  endif()
  set(output "${CMAKE_CURRENT_BINARY_DIR}/raft_wpe_plugin")
  file(COPY "${plugin_dir}/" DESTINATION "${output}")
  file(READ "${output}/${settings}" patched)
  # WPE 2.54 exposes the preference as reduced-motion. Both settings are
  # boolean user preferences; this does not disable JavaScript or animations
  # unconditionally. The branch remains opt-in through disableAnimations.
  string(REPLACE "WPE_SETTING_DISABLE_ANIMATIONS" "WPE_SETTING_REDUCED_MOTION"
    patched "${patched}")
  file(WRITE "${output}/${settings}" "${patched}")
  get_target_property(sources ${plugin} SOURCES)
  set(replacement_sources "")
  foreach(source IN LISTS sources)
    if(source MATCHES "^\\$<")
      message(FATAL_ERROR "Review generated sources in the WPE plugin backport")
    endif()
    get_filename_component(absolute "${source}" ABSOLUTE BASE_DIR "${plugin_dir}")
    file(RELATIVE_PATH relative "${plugin_dir}" "${absolute}")
    if(relative MATCHES "^\\.\\./" OR IS_ABSOLUTE "${relative}")
      message(FATAL_ERROR "Review external sources in the WPE plugin backport")
    endif()
    list(APPEND replacement_sources "${output}/${relative}")
  endforeach()
  set_property(TARGET ${plugin} PROPERTY SOURCES "${replacement_sources}")
  target_include_directories(${plugin} BEFORE PRIVATE "${output}")
endfunction()
