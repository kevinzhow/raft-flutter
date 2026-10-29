"""Approved shared Button roles, from actual source paint values."""
import json
from pathlib import Path

_DATA = json.loads(Path(__file__).with_suffix('.json').read_text())


def button_colors(column, current):
    result = {}
    for name, value in _DATA['roles'][column].items():
        # Role aliases are flattened; private palette references stay symbolic.
        result[name] = (value if value.startswith('{palette.')
                        else current[value[1:-1]])
    return result


def button_palette(column):
    return _DATA['palette'][column]


def component_geometry(column):
    """Actual current size variants, re-expressed as component values.

    Raft: ChannelFooter lg, Login/Register xl, denied page lg in v1.21.23.
    Families: frozen md / lg / md. The recipe join button was probed separately
    (32px, 12px inline, 14/20 label, 14px glyph, explicit gap 6).
    """
    raft = column.startswith('raft')
    brutal = column == 'brutal'
    profiles = {
        'channelJoin': (44, 16, 15, 20, 18, 8) if raft else (32, 12, 14, 20, 14, 6),
        'authSubmit': (52, 20, 16, 24, 18, 8) if raft else
                      (40, 16, 14, 20, 16, 6) if brutal else (36, 14, 16, 24, 16, 6),
        'standaloneContinue': (44, 16, 15, 20, 18, 8) if raft else (32, 12, 14, 20, 16, 5.5),
    }
    values = {}
    for name, (height, padding, size, line, glyph, gap) in profiles.items():
        values.update({f'size.{name}': height, f'space.{name}Inline': padding,
                       f'type.{name}.size': size, f'type.{name}.line': line,
                       f'size.{name}Glyph': glyph, f'space.{name}Gap': gap})
    return values
