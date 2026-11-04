#include <gio/gio.h>
using MyApplication = GApplication;
G_DEFINE_AUTOPTR_CLEANUP_FUNC(MyApplication, g_object_unref)
MyApplication* my_application_new();
int raft_test_application_run(GApplication*, int, char**);
#define g_application_run raft_test_application_run
