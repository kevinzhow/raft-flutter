#include "shared_egl_termination.h"

#include <cassert>
#include <cstdio>

namespace {
int calls = 0;
bool primary_context_valid = true;
void* shared_display = reinterpret_cast<void*>(0x11);
void* another_display = reinterpret_cast<void*>(0x22);
unsigned int Terminate(void* display) {
  ++calls;
  if (display == shared_display) primary_context_valid = false;
  return 1;
}
unsigned int ForeignHook(void*) { return 1; }
void Reset() { calls = 0; primary_context_valid = true; }
}  // namespace

int main() {
  // The native failure's EGL semantics: Initialize is not reference-counted;
  // child Terminate invalidates the surviving GTK/primary contexts.
  Reset();
  Terminate(shared_display);
  assert(!primary_context_valid);

  // Same production dispatch, real installed guard. Three close/reopen cycles
  // release every child engine while the original display stays renderable.
  Reset();
  SharedEglTermination guard;
  auto dispatch = Terminate;
  guard.EngineAdded();
  assert(guard.Install(shared_display, &dispatch, Terminate));
  assert(guard.Matches(shared_display) && !guard.Matches(another_display));
  auto saved_hook = dispatch;
  assert(guard.Install(shared_display, &dispatch, Terminate));
  for (int cycle = 0; cycle < 3; ++cycle) {
    guard.EngineAdded();
    dispatch(shared_display);
    guard.EngineRemoved();
    assert(primary_context_valid && calls == 0 && guard.live_engines() == 1);
  }
  assert(guard.deferred() == 3);
  dispatch(another_display);
  assert(calls == 1 && primary_context_valid);  // Other display is never owned.
  dispatch(shared_display);
  guard.EngineRemoved();
  assert(guard.Release());
  assert(dispatch == Terminate && guard.terminated() == 1 && calls == 2);
  assert(!primary_context_valid && !guard.Ready());
  assert(guard.Release() && calls == 2);  // Exactly once.
  saved_hook(another_display);  // No pointer to a retired owner is required.
  assert(calls == 3);

  // Reverse engine teardown order: primary can finalize before the last child.
  Reset();
  SharedEglTermination reverse;
  assert(reverse.Install(shared_display, &dispatch, Terminate));
  reverse.EngineAdded(); reverse.EngineAdded();
  dispatch(shared_display); reverse.EngineRemoved();
  assert(primary_context_valid && calls == 0 && reverse.live_engines() == 1);
  dispatch(shared_display); reverse.EngineRemoved();
  assert(reverse.Release() && calls == 1);

  // Unrelated/new hooks are not overwritten, no shutdown while engines live.
  Reset();
  SharedEglTermination live;
  live.EngineAdded();
  assert(live.Install(shared_display, &dispatch, Terminate));
  dispatch(shared_display);
  assert(!live.Release() && dispatch == Terminate && calls == 0);
  live.EngineRemoved();
  SharedEglTermination changed;
  assert(changed.Install(shared_display, &dispatch, Terminate));
  dispatch = ForeignHook;
  assert(!changed.Ready());
  assert(!changed.Install(shared_display, &dispatch, Terminate));
  assert(!changed.Release() && dispatch == ForeignHook && calls == 0);

  // Missing resolution/invalid display leaves single-window dispatch alone.
  SharedEglTermination unavailable;
  dispatch = Terminate;
  assert(!unavailable.Install(nullptr, &dispatch, Terminate));
  assert(!unavailable.Install(shared_display, &dispatch, nullptr));
  assert(dispatch == Terminate && unavailable.Release());
  std::puts("PASS shared EGL close/reopen/order/forward/retire/failure boundaries");
}
