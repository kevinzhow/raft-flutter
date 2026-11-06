// Install only the GTK host before any Flutter view is parented or realized.
// WebKit and its plugin stay optional and are loaded on feature use.
#include "../../../../packages/raft_system_webview/linux/host_bootstrap.h"

__attribute__((constructor)) static void PrepareOptionalWebviewHost() {
  RaftInstallWebviewHostBootstrap();
}
