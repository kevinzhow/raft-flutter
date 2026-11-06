#!/usr/bin/env python3
"""Generate a build-local registrant without eager WebKit/mpv registration."""
import argparse
from pathlib import Path
import re

PLUGINS = {
    'media_kit_video': ('MediaKitVideoPlugin', 'media_kit_video_plugin', 'media_kit_video_plugin.h'),
    'raft_system_webview': ('RaftSystemWebviewPlugin', 'raft_system_webview_plugin', 'raft_system_webview_plugin.h'),
}


def generate(text):
    for name, (klass, function, header) in PLUGINS.items():
        include = f'#include <{name}/{header}>\n'
        if text.count(include) != 1:
            raise ValueError(f'Generated optional plugin include drifted: {name}')
        text = text.replace(include, '')
        pattern = (r'  g_autoptr\(FlPluginRegistrar\) ' + re.escape(name) +
                   r'_registrar =\s*fl_plugin_registry_get_registrar_for_plugin\(registry, "' +
                   klass + r'"\);\s*' + function +
                   r'_register_with_registrar\(' + name + r'_registrar\);\n')
        text, count = re.subn(pattern, '', text)
        if count != 1:
            raise ValueError(f'Generated optional plugin registration drifted: {name}')
    text = text.replace('#include "generated_plugin_registrant.h"',
                        '#include "flutter/generated_plugin_registrant.h"\n'
                        '#include "runner/linux_optional_plugins.h"')
    anchor = 'void fl_register_plugins(FlPluginRegistry* registry) {\n'
    if text.count(anchor) != 1:
        raise ValueError('Generated plugin registration entrypoint drifted')
    return text.replace(anchor, anchor + '  raft_register_optional_linux_plugins(registry);\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.write_text(generate(args.source.read_text()))
