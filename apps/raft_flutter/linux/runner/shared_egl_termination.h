#ifndef RAFT_SHARED_EGL_TERMINATION_H_
#define RAFT_SHARED_EGL_TERMINATION_H_

#include <cstddef>
#include <mutex>

// One process-owned display, not one reference per eglInitialize: EGL's
// Wayland/X11 default is non-reference-counted (KHR_display_reference).
// Child engines still destroy their contexts and release all their objects.
class SharedEglTermination {
 public:
  using Display = void*;
  using Terminate = unsigned int (*)(Display);

  bool Install(Display display, Terminate* dispatch, Terminate original);
  bool Ready() const;
  bool Matches(Display display) const;
  void EngineAdded();
  void EngineRemoved();
  bool Release();
  size_t live_engines() const;
  size_t deferred() const;
  size_t terminated() const;

 private:
  static unsigned int Dispatch(Display display);
  static SharedEglTermination* owner_;
  static Terminate retired_forward_;
  static std::mutex mutex_;
  Display display_ = nullptr;
  Terminate* dispatch_ = nullptr;
  Terminate previous_ = nullptr;
  Terminate original_ = nullptr;
  size_t live_engines_ = 0;
  size_t deferred_ = 0;
  size_t terminated_ = 0;
  bool installed_ = false;
};

#endif
