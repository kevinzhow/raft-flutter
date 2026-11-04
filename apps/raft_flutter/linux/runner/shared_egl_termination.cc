#include "shared_egl_termination.h"
#ifdef RAFT_MULTIWINDOW_QA
#include <cstdio>
#endif

SharedEglTermination* SharedEglTermination::owner_ = nullptr;
SharedEglTermination::Terminate SharedEglTermination::retired_forward_ = nullptr;
std::mutex SharedEglTermination::mutex_;

bool SharedEglTermination::Install(Display display, Terminate* dispatch,
                                   Terminate original) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (installed_) {
    return owner_ == this && display == display_ && dispatch == dispatch_ &&
           original == original_ && *dispatch_ == Dispatch;
  }
  if (!display || !dispatch || !*dispatch || !original || owner_) return false;
  display_ = display;
  dispatch_ = dispatch;
  previous_ = *dispatch;
  original_ = original;
  deferred_ = terminated_ = 0;
  owner_ = this;
  installed_ = true;
  *dispatch_ = Dispatch;
  return true;
}

bool SharedEglTermination::Ready() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return installed_ && owner_ == this && *dispatch_ == Dispatch;
}

bool SharedEglTermination::Matches(Display display) const {
  std::lock_guard<std::mutex> lock(mutex_);
  return installed_ && owner_ == this && *dispatch_ == Dispatch &&
         display == display_;
}

unsigned int SharedEglTermination::Dispatch(Display display) {
  Terminate forward;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (owner_ && owner_->installed_ && display == owner_->display_) {
      ++owner_->deferred_;
#ifdef RAFT_MULTIWINDOW_QA
      std::fprintf(stderr, "RAFT_EGL_LIFETIME event=defer display=%p live=%zu deferred=%zu\n",
                   display, owner_->live_engines_, owner_->deferred_);
#endif
      return 1;  // EGL_TRUE; the application still owns the live display.
    }
    forward = owner_ ? owner_->original_ : retired_forward_;
  }
  return forward ? forward(display) : 0;
}

void SharedEglTermination::EngineAdded() {
  std::lock_guard<std::mutex> lock(mutex_);
  ++live_engines_;
  ++engines_seen_;
}

void SharedEglTermination::EngineRemoved() {
  std::lock_guard<std::mutex> lock(mutex_);
  if (live_engines_) --live_engines_;
}

bool SharedEglTermination::Release() {
  Terminate terminate = nullptr;
  Display display = nullptr;
  bool complete;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!installed_) return true;
    complete = live_engines_ == 0 && deferred_ >= engines_seen_ &&
               *dispatch_ == Dispatch;
    // Never leave our callback installed, and never overwrite another owner.
    if (*dispatch_ == Dispatch) *dispatch_ = previous_;
#ifdef RAFT_MULTIWINDOW_QA
    std::fprintf(stderr, "RAFT_EGL_LIFETIME event=restore_dispatch restored=%d live=%zu deferred=%zu complete=%d\n",
                 *dispatch_ == previous_, live_engines_, deferred_, complete);
#endif
    retired_forward_ = original_;
    owner_ = nullptr;
    installed_ = false;
    if (complete && deferred_) {
      terminate = original_;
      display = display_;
    }
  }
  if (terminate) {
    const bool success = terminate(display) != 0;
    std::lock_guard<std::mutex> lock(mutex_);
    terminated_ = success ? 1 : 0;
#ifdef RAFT_MULTIWINDOW_QA
    std::fprintf(stderr, "RAFT_EGL_LIFETIME event=terminate display=%p success=%d count=%zu live=%zu\n",
                 display, success, terminated_, live_engines_);
#endif
    return success;
  }
  return complete;
}

size_t SharedEglTermination::live_engines() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return live_engines_;
}
size_t SharedEglTermination::deferred() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return deferred_;
}
size_t SharedEglTermination::terminated() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return terminated_;
}
bool SharedEglTermination::ReadyToRelease() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return !installed_ || (live_engines_ == 0 && deferred_ >= engines_seen_);
}
size_t SharedEglTermination::engines_seen() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return engines_seen_;
}
