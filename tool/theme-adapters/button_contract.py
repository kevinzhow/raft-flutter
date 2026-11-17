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


def component_geometry(column):
    """Actual current size variants, re-expressed as component values.

    ChannelFooter lg, Login/Register xl, denied page lg in v1.21.23.
    """
    profiles = {
        'channelJoin': (44, 16, 15, 20, 18, 8),
        'authSubmit': (52, 20, 16, 24, 18, 8),
        'standaloneContinue': (44, 16, 15, 20, 18, 8),
    }
    values = {}
    for name, (height, padding, size, line, glyph, gap) in profiles.items():
        values.update({f'size.{name}': height, f'space.{name}Inline': padding,
                       f'type.{name}.size': size, f'type.{name}.line': line,
                       f'size.{name}Glyph': glyph, f'space.{name}Gap': gap})
    return values
