// Bundled-path adapter for upstream WPE WebKit 2.54.2. This file is copied into
// Source/WebKit/Shared/glib by wpe-relocation.patch's preparation instructions.
// No environment variable or PATH fallback selects executable code. WPE helpers
// are bundled; Bubblewrap uses its fixed, protected distribution path.
#pragma once

#include <dlfcn.h>
#include <fcntl.h>
#include <glib.h>
#include <limits.h>
#include <stdlib.h>
#include <string>
#include <sys/stat.h>
#include <unistd.h>

namespace RaftWPE {

inline std::string canonicalPath(const std::string& path)
{
    char* resolved = realpath(path.c_str(), nullptr);
    if (!resolved)
        return {};
    std::string result(resolved);
    free(resolved);
    return result;
}

inline std::string parentPath(const std::string& path)
{
    auto slash = path.find_last_of('/');
    return slash == std::string::npos ? std::string() : path.substr(0, slash);
}

inline const char* architecture()
{
#if defined(__x86_64__)
    return "x86_64";
#elif defined(__aarch64__)
    return "aarch64";
#else
#error Unsupported architecture for the bundled WPE runtime
#endif
}

inline std::string expectedMarker()
{
    return std::string("raft-html-wpe-runtime-v1\n"
        "wpewebkit=2.54.2\n"
        "source-sha256=f3284e19e47fcb5ac8c63c2e1c113dbd65b2423eb8a545f5b345707829004f56\n"
        "relocation=raft-v1\n"
        "arch=") + architecture() + "\n";
}

// AppArmor's distribution profile can attach to /usr/bin/bwrap specifically.
// Relocating that executable can remove its permission to create a sandbox.
// This checks the fixed system path's filesystem trust, not an environment or
// PATH candidate. The deployment probe separately records package provenance.
inline bool trustedSystemExecutable(const std::string& path)
{
    if (path.empty() || path.front() != '/' || canonicalPath(path) != path)
        return false;
    struct stat info { };
    for (size_t end = 1; ; end = path.find('/', end + 1)) {
        bool final = end == std::string::npos;
        auto part = final ? path : path.substr(0, end);
        if (lstat(part.c_str(), &info) || info.st_uid || (info.st_mode & 0022)
            || (final ? !S_ISREG(info.st_mode) : !S_ISDIR(info.st_mode)))
            return false;
        if (final)
            break;
    }
    if ((info.st_mode & (S_ISUID | S_ISGID)) || access(path.c_str(), R_OK | X_OK))
        return false;
    int fd = open(path.c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    if (fd < 0)
        return false;
    struct stat opened { };
    if (fstat(fd, &opened) || opened.st_dev != info.st_dev || opened.st_ino != info.st_ino
        || opened.st_uid || (opened.st_mode & (0022 | S_ISUID | S_ISGID))) {
        close(fd);
        return false;
    }
    unsigned char header[20] { };
    auto count = read(fd, header, sizeof(header));
    close(fd);
#if defined(__x86_64__)
    constexpr unsigned machine = 62;
#else
    constexpr unsigned machine = 183;
#endif
    return count == static_cast<ssize_t>(sizeof(header)) && header[0] == 0x7f && header[1] == 'E'
        && header[2] == 'L' && header[3] == 'F' && header[4] == 2 && header[5] == 1
        && (static_cast<unsigned>(header[18]) | (header[19] << 8)) == machine;
}

class __attribute__((visibility("hidden"))) Runtime {
public:
    static const Runtime& current()
    {
        static const Runtime runtime;
        return runtime;
    }

    std::string path(const char* relative) const
    {
        if (!valid_ || !relative || !*relative || *relative == '/')
            return {};
        std::string value(relative);
        size_t start = 0;
        while (start <= value.size()) {
            auto end = value.find('/', start);
            auto part = value.substr(start, end - start);
            if (part.empty() || part == "." || part == "..")
                return {};
            if (end == std::string::npos)
                break;
            start = end + 1;
        }
        return prefix_ + "/" + value;
    }

    std::string bubblewrap() const
    {
        return valid_ ? "/usr/bin/bwrap" : std::string();
    }

private:
    Runtime()
    {
        valid_ = validate();
        if (!valid_)
            g_warning("Raft HTML runtime bundle identity/layout is invalid; WebKit helpers are disabled");
    }

    bool contains(const std::string& canonical) const
    {
        return canonical.compare(0, prefix_.size() + 1, prefix_ + "/") == 0;
    }

    bool regularFile(const char* relative, bool executable) const
    {
        auto canonical = canonicalPath(prefix_ + "/" + relative);
        struct stat info { };
        return contains(canonical) && !stat(canonical.c_str(), &info)
            && S_ISREG(info.st_mode)
            && !access(canonical.c_str(), executable ? R_OK | X_OK : R_OK);
    }

    bool directory(const char* relative) const
    {
        auto canonical = canonicalPath(prefix_ + "/" + relative);
        struct stat info { };
        return contains(canonical) && !stat(canonical.c_str(), &info)
            && S_ISDIR(info.st_mode);
    }

    bool markerMatches() const
    {
        auto marker = prefix_ + "/share/raft-html-webview/runtime.marker";
        int fd = open(marker.c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
        if (fd < 0)
            return false;
        auto expected = expectedMarker();
        struct stat info { };
        bool regular = !fstat(fd, &info) && S_ISREG(info.st_mode)
            && info.st_size == static_cast<off_t>(expected.size());
        std::string actual(expected.size(), '\0');
        auto count = regular ? read(fd, actual.data(), actual.size()) : -1;
        close(fd);
        return regular && count == static_cast<ssize_t>(expected.size())
            && actual == expected;
    }

    bool validate()
    {
        Dl_info library { };
        if (!dladdr(reinterpret_cast<const void*>(&Runtime::current), &library)
            || !library.dli_fname)
            return false;
        auto loadedLibrary = canonicalPath(library.dli_fname);
        auto libraryDirectory = parentPath(loadedLibrary);
        prefix_ = parentPath(libraryDirectory);
        if (prefix_.empty() || libraryDirectory != prefix_ + "/lib")
            return false;
        if (canonicalPath(prefix_ + "/lib/libWPEWebKit-2.0.so.1") != loadedLibrary)
            return false;
        if (!directory("lib") || !directory("share")
            || !directory("share/raft-html-webview") || !markerMatches())
            return false;
        if (!directory("libexec/wpe-webkit-2.0")
            || !directory("libexec/raft-html-webview")
            || !directory("lib/wpe-webkit-2.0/injected-bundle")
            || !trustedSystemExecutable("/usr/bin/bwrap"))
            return false;
        return regularFile("libexec/wpe-webkit-2.0/WPEWebProcess", true)
            && regularFile("libexec/wpe-webkit-2.0/WPENetworkProcess", true)
            && regularFile("libexec/wpe-webkit-2.0/WPEGPUProcess", true)
            && regularFile("libexec/raft-html-webview/xdg-dbus-proxy", true)
            && regularFile("lib/wpe-webkit-2.0/injected-bundle/libWPEInjectedBundle.so", false);
    }

    std::string prefix_;
    bool valid_ { false };
};

} // namespace RaftWPE
