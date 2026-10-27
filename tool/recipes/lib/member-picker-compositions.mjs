import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

// Read the real product composition, including the canonical SectionEyebrow
// base/tone and option-row constants. Never restate its class list in Dart.
export function extractMemberPickerCompositions(web, ts) {
  function source(path) {
    const text = readFileSync(join(web, path), 'utf8');
    const ast = ts.createSourceFile(path, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
    if (ast.parseDiagnostics.length) throw Error(`Cannot parse member picker source ${path}`);
    return {path, text, ast};
  }
  function nodes(root, predicate) {
    const out = [];
    function walk(n) { if (predicate(n)) out.push(n); ts.forEachChild(n, walk); }
    walk(root);
    return out;
  }
  function only(xs, label) {
    if (xs.length !== 1) throw Error(`Member picker: expected one ${label}, got ${xs.length}`);
    return xs[0];
  }
  function literal(node, label) {
    if (!node || !(ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node))) {
      throw Error(`Member picker ${label} must be a literal`);
    }
    return node.text;
  }
  function declaration(src, name) {
    return only(nodes(src.ast, n => ts.isVariableDeclaration(n) && n.name.getText(src.ast) === name), name).initializer;
  }
  const opening = n => ts.isJsxElement(n) ? n.openingElement : n;
  const tag = n => opening(n).tagName.getText();
  const elements = (root, name) => nodes(root, n =>
    (ts.isJsxElement(n) || ts.isJsxSelfClosingElement(n)) && tag(n) === name);
  function attr(n, name) {
    return opening(n).attributes.properties.find(a => ts.isJsxAttribute(a) && a.name.getText() === name)?.initializer;
  }
  function knownAttributes(n, allowed) {
    for (const a of opening(n).attributes.properties) {
      if (!ts.isJsxAttribute(a) || !allowed.includes(a.name.getText())) {
        throw Error(`Member picker ${tag(n)} attribute needs an explicit binding`);
      }
    }
  }
  function identifierClass(n, expected) {
    const value = attr(n, 'className');
    if (!value || !ts.isJsxExpression(value) || !value.expression ||
        !ts.isIdentifier(value.expression) || value.expression.text !== expected) {
      throw Error(`Member picker className must bind ${expected}`);
    }
  }
  const product = source('src/components/channel/CreateChannelDialog.tsx');
  const constants = source('src/components/channel/memberPickerClasses.ts');
  const eyebrow = source('src/components/ui/SectionEyebrow.tsx');
  const card = only(elements(product.ast, 'Card'), 'member Card');
  knownAttributes(card, ['className']);
  const root = literal(attr(card, 'className'), 'Card className');
  const rows = elements(card, 'button');
  const groups = elements(card, 'SectionEyebrow');
  if (rows.length !== 2 || groups.length !== 2) throw Error('Member picker agent/human group structure changed');
  let label;
  for (const row of rows) {
    knownAttributes(row, ['key', 'type', 'onClick', 'className']);
    identifierClass(row, 'PICKER_ROW_CLASS');
    const children = row.children.filter(n => ts.isJsxElement(n) || ts.isJsxSelfClosingElement(n));
    if (children.length !== 3 || tag(children[0]) !== 'CheckboxIndicator' || tag(children[1]) !== 'AvatarSlot' || tag(children[2]) !== 'span') {
      throw Error('Member picker leading checkbox/avatar/label structure changed');
    }
    knownAttributes(children[0], ['checked']);
    knownAttributes(children[2], ['className']);
    const current = literal(attr(children[2], 'className'), 'label className');
    if (label !== undefined && label !== current) throw Error('Member picker label variants need an explicit axis');
    label = current;
  }
  for (const group of groups) {
    knownAttributes(group, ['as', 'className']);
    identifierClass(group, 'PICKER_GROUP_LABEL_CLASS');
    if (attr(group, 'tone')) throw Error('Member picker eyebrow tone override needs a binding');
  }
  const toneDefault = only(nodes(eyebrow.ast, n => ts.isBindingElement(n) && n.name.getText() === 'tone' && n.initializer), 'eyebrow tone default');
  const tone = literal(toneDefault.initializer, 'eyebrow tone');
  let tones = declaration(eyebrow, 'TONE_CLASS');
  if (tones && ts.isAsExpression(tones)) tones = tones.expression;
  if (!tones || !ts.isObjectLiteralExpression(tones)) throw Error('Member picker TONE_CLASS must be a literal object');
  const toneValue = only(tones.properties.filter(p => ts.isPropertyAssignment(p) && p.name.getText() === tone), 'eyebrow tone class');
  const group = [literal(declaration(eyebrow, 'BASE_CLASS'), 'eyebrow base'),
    literal(toneValue.initializer, 'eyebrow tone class'),
    literal(declaration(constants, 'PICKER_GROUP_LABEL_CLASS'), 'group class')].join(' ');
  const row = literal(declaration(constants, 'PICKER_ROW_CLASS'), 'row class');
  const empty = literal(attr(only(elements(card, 'div'), 'empty label'), 'className'), 'empty className');
  const region = [product, constants, eyebrow].map(s =>
    `${s.path} sha256:${createHash('sha256').update(s.text).digest('hex')}`).join('; ');
  return [{name: 'webMemberPicker', line: 1, region: `Web ${region}`,
    exported: [], directUsers: [], exportedComponents: ['CreateChannelDialogMemberPicker'],
    options: {slots: {root, group, row, label, empty}}, nonLiteral: [], resolvedIdentifiers: []}];
}
