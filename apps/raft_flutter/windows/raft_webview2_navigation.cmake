# Compatibility backport for the pinned flutter_inappwebview_windows 0.7.0-beta.3.
# Fetch.requestPaused loses the trusted NavigationStarting classification, and
# NavigationCompleted labels a failed request with the still-visible old URL.
# Compile a guarded build-local copy; never alter the shared Pub cache.
function(raft_fix_webview2_navigation)
  set(plugin flutter_inappwebview_windows_plugin)
  if(NOT TARGET ${plugin})
    message(FATAL_ERROR "The reviewed Windows HTML renderer is missing")
  endif()
  get_target_property(plugin_dir ${plugin} SOURCE_DIR)
  set(upstream "${plugin_dir}/in_app_webview/in_app_webview.cpp")
  file(SHA256 "${upstream}" upstream_hash)
  if(NOT upstream_hash STREQUAL "b35ad66ed82e6f88455983b221c4c86e45b86e80037d40f0319488b8eb1e57d1")
    message(FATAL_ERROR "Review the WebView2 navigation backport for the changed plugin source")
  endif()
  file(READ "${upstream}" patched)
  set(old_navigation "std::optional<NavigationActionType> navigationType = isRedirect ? NavigationActionType::other : std::optional<NavigationActionType>{};")
  set(new_navigation [=[std::optional<NavigationActionType> navigationType = isRedirect ? NavigationActionType::other : std::optional<NavigationActionType>{};
                // Reuse only this frame/URL's native IsUserInitiated-derived classification.
                // A script navigation, redirect or missing native event stays untrusted.
                if (isForMainFrame && !isRedirect && url.has_value() &&
                    lastNavigationAction_ && lastNavigationAction_->request &&
                    lastNavigationAction_->request->url == url) {
                  navigationType = lastNavigationAction_->navigationType;
                }]=])
  set(old_request "std::make_unique<WebResourceRequest>(url, navigationAction->request->method, navigationAction->request->headers, navigationAction->isForMainFrame)")
  set(new_request "std::make_unique<WebResourceRequest>(navigationAction->request->url, navigationAction->request->method, navigationAction->request->headers, navigationAction->isForMainFrame)")
  foreach(fragment IN ITEMS old_navigation old_request)
    string(FIND "${patched}" "${${fragment}}" found)
    if(found EQUAL -1)
      message(FATAL_ERROR "The reviewed WebView2 navigation patch no longer matches")
    endif()
  endforeach()
  string(REPLACE "${old_navigation}" "${new_navigation}" patched "${patched}")
  string(REPLACE "${old_request}" "${new_request}" patched "${patched}")
  # This one translation unit moves to the build directory. Anchor its quoted
  # includes upstream without changing flags or recompiling every plugin file.
  string(REGEX REPLACE "#include \"([^\"]+)\""
    "#include \"${plugin_dir}/in_app_webview/\\1\"" patched "${patched}")
  set(patched "// Raft navigation compatibility backport; original source remains in Pub cache.\n${patched}")
  set(output_dir "${CMAKE_CURRENT_BINARY_DIR}/raft_webview2_navigation")
  set(output "${output_dir}/in_app_webview.cpp")
  file(MAKE_DIRECTORY "${output_dir}")
  set(previous "")
  if(EXISTS "${output}")
    file(READ "${output}" previous)
  endif()
  if(NOT "${previous}" STREQUAL "${patched}")
    file(WRITE "${output}" "${patched}")
  endif()
  get_target_property(sources ${plugin} SOURCES)
  set(replacement_sources "")
  set(replaced FALSE)
  foreach(source IN LISTS sources)
    if(source MATCHES "^\\$<")
      list(APPEND replacement_sources "${source}")
      continue()
    endif()
    get_filename_component(absolute "${source}" ABSOLUTE BASE_DIR "${plugin_dir}")
    if("${absolute}" STREQUAL "${upstream}")
      list(APPEND replacement_sources "${output}")
      set(replaced TRUE)
    else()
      list(APPEND replacement_sources "${absolute}")
    endif()
  endforeach()
  if(NOT replaced)
    message(FATAL_ERROR "The reviewed WebView2 source is not in the plugin target")
  endif()
  set_property(TARGET ${plugin} PROPERTY SOURCES "${replacement_sources}")
endfunction()
