"""Derive packages/raft_ui/assets/fonts/Inter.ttf from the pinned google/fonts
Inter[opsz,wght].ttf the way Google Fonts serves it to Web: raft-ui requests
`Inter:wght@400;500;600;700`, and Google's response files carry only the wght
axis (opsz pinned at its default 14). Run with fontTools:
  python derive_inter.py <Inter[opsz,wght].ttf> <out Inter.ttf>"""
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

font = TTFont(sys.argv[1])
assert [a.axisTag for a in font['fvar'].axes] == ['opsz', 'wght'], 'unexpected axes'
instancer.instantiateVariableFont(font, {'opsz': 14}, inplace=True, updateFontNames=False)
font.save(sys.argv[2])
