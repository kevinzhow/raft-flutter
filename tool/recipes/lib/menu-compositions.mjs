import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const hash = (text) => createHash('sha256').update(text).digest('hex');

export function extractMenuCompositions(web, ts) {
  function source(name, section = 'ui') {
    const path = `src/components/${section}/${name}.tsx`;
    const text = readFileSync(join(web, path), 'utf8');
    const ast = ts.createSourceFile(path, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
    if (ast.parseDiagnostics.length) throw new Error(`Cannot parse ${path}`);
    return { path, text, ast, sha: hash(text) };
  }
  function nodes(root, predicate) {
    const out = [];
    function visit(node) {
      if (predicate(node)) out.push(node);
      ts.forEachChild(node, visit);
    }
    visit(root);
    return out;
  }
  function evaluate(node, env) {
    if (ts.isNumericLiteral(node)) return Number(node.text);
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
    if (ts.isIdentifier(node) && env.has(node.text)) return env.get(node.text);
    if (ts.isConditionalExpression(node)) return evaluate(evaluate(node.condition, env) ? node.whenTrue : node.whenFalse, env);
    if (ts.isTemplateExpression(node)) return node.head.text + node.templateSpans.map((part) =>
      String(evaluate(part.expression, env)) + part.literal.text).join('');
    if (ts.isArrayLiteralExpression(node)) return node.elements.map((entry) => evaluate(entry, env));
    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) &&
        node.expression.name.text === 'join' && node.arguments.length === 1) {
      return evaluate(node.expression.expression, env).join(evaluate(node.arguments[0], env));
    }
    throw new Error(`Unsupported menu class expression: ${node.getText().slice(0, 100)}`);
  }
  function className(element, env) {
    const opening = ts.isJsxElement(element) ? element.openingElement : element;
    const attribute = opening.attributes.properties.find((attr) => ts.isJsxAttribute(attr) && attr.name.text === 'className');
    if (!attribute?.initializer) throw new Error('Expected a className');
    return evaluate(ts.isJsxExpression(attribute.initializer) ? attribute.initializer.expression : attribute.initializer, env);
  }
  const action = source('MenuItem');
  const declaration = nodes(action.ast, (node) => ts.isVariableDeclaration(node) && node.name.getText() === 'MENU_ITEM_CLASS');
  if (declaration.length !== 1) throw new Error('Expected one MENU_ITEM_CLASS');
  const actionClasses = evaluate(declaration[0].initializer, new Map());
  const selection = source('SelectionPopover');
  const functions = nodes(selection.ast, (node) => ts.isFunctionDeclaration(node) && node.name?.text === 'SelectionPopoverOptionRow');
  if (functions.length !== 1) throw new Error('Expected SelectionPopoverOptionRow');
  const fn = functions[0];
  const buttons = nodes(fn.body, (node) => ts.isJsxElement(node) && node.openingElement.tagName.getText() === 'button');
  if (buttons.length !== 1) throw new Error('Expected one selection button');
  const spans = nodes(buttons[0], (node) => ts.isJsxElement(node) && node.openingElement.tagName.getText() === 'span');
  if (spans.length !== 3) throw new Error('Selection leading/label structure changed');
  const checks = nodes(buttons[0], (node) => ts.isJsxSelfClosingElement(node) && node.tagName.getText() === 'Check');
  if (checks.length !== 1) throw new Error('Expected one source check glyph');
  const sizeAttribute = checks[0].attributes.properties.find((attr) => ts.isJsxAttribute(attr) && attr.name.text === 'size');
  if (!sizeAttribute?.initializer || !ts.isJsxExpression(sizeAttribute.initializer)) throw new Error('Expected source check size');
  const checkSize = evaluate(sizeAttribute.initializer.expression, new Map());
  if (!Number.isFinite(checkSize) || checkSize <= 0) throw new Error('Invalid source check size');
  const indicator = `${className(checks[0], new Map())} size-[${checkSize}px]`;
  const combinations = [];
  for (const checked of [false, true]) for (const disabled of [false, true]) for (const italic of [false, true]) {
    const env = new Map(Object.entries({ checked, disabled, italic }));
    for (const statement of fn.body.statements) {
      if (!ts.isVariableStatement(statement)) continue;
      for (const decl of statement.declarationList.declarations) {
        // Only resolve the class expressions; other values own user content.
        if (['labelClassName', 'rowTone'].includes(decl.name.getText())) {
          env.set(decl.name.getText(), evaluate(decl.initializer, env));
        }
      }
    }
    combinations.push({ checked, disabled, italic, root: className(buttons[0], env),
      leading: className(spans[1], env), label: className(spans[2], env) });
  }
  const sections = nodes(selection.ast, (node) => ts.isFunctionDeclaration(node) && node.name?.text === 'SelectionPopoverSections');
  if (sections.length !== 1) throw new Error('Expected SelectionPopoverSections');
  const elements = (tag, count) => {
    const found = nodes(sections[0], (node) =>
      (ts.isJsxElement(node) && node.openingElement.tagName.getText() === tag) ||
      (ts.isJsxSelfClosingElement(node) && node.tagName.getText() === tag));
    if (found.length !== count) throw new Error(`Selection section ${tag} structure changed`);
    return found.map((entry) => className(entry, new Map()));
  };
  const divs = elements('div', 3);
  const surfaceDecl = nodes(selection.ast, (node) => ts.isVariableDeclaration(node) && node.name.getText() === 'SELECTION_POPOVER_SURFACE');
  if (surfaceDecl.length !== 1) throw new Error('Expected SELECTION_POPOVER_SURFACE');
  const searchGlyphs = nodes(sections[0], (node) => ts.isJsxSelfClosingElement(node) && node.tagName.getText() === 'Search');
  if (searchGlyphs.length !== 1) throw new Error('Expected one source Search glyph');
  const searchSize = searchGlyphs[0].attributes.properties.find((attr) => ts.isJsxAttribute(attr) && attr.name.text === 'size');
  if (!searchSize?.initializer || !ts.isJsxExpression(searchSize.initializer)) throw new Error('Expected source Search size');
  const searchPixels = evaluate(searchSize.initializer.expression, new Map());
  if (!Number.isFinite(searchPixels) || searchPixels <= 0) throw new Error('Invalid source Search size');
  const sectionSlots = {
    root: evaluate(surfaceDecl[0].initializer, new Map()),
    header: divs[0], list: divs[1], empty: divs[2],
    title: elements('span', 1)[0], clear: elements('button', 1)[0],
    search: elements('label', 1)[0], input: elements('input', 1)[0],
    searchIcon: `${className(searchGlyphs[0], new Map())} size-[${searchPixels}px]`,
  };
  const metadata = (name, src, components, options) => ({
    name, line: 1, region: `Web ${src.path} sha256:${src.sha}`,
    exported: [], directUsers: [], exportedComponents: components,
    options, nonLiteral: [], resolvedIdentifiers: [],
  });
  const help = source('LeftRail', 'layout');
  const helpFunctions = nodes(help.ast, (node) => ts.isFunctionDeclaration(node) && node.name?.text === 'HelpMenu');
  if (helpFunctions.length !== 1) throw new Error('Expected one HelpMenu');
  const helpPopovers = nodes(helpFunctions[0].body, (node) =>
    ts.isJsxElement(node) && node.openingElement.tagName.getText() === 'PopoverContent');
  if (helpPopovers.length !== 1) throw new Error('Help popup structure changed');
  const helpHeaders = nodes(helpPopovers[0], (node) =>
    ts.isJsxElement(node) && node.openingElement.tagName.getText() === 'div');
  if (helpHeaders.length !== 1 || nodes(helpHeaders[0], (node) =>
    ts.isJsxElement(node) && node.openingElement.tagName.getText() === 'SectionEyebrow').length !== 1) {
    throw new Error('Help header structure changed');
  }
  const sort = source('SidebarSortMenu', 'layout');
  const sortFunctions = nodes(sort.ast, (node) => ts.isFunctionDeclaration(node) && node.name?.text === 'SidebarSortMenu');
  if (sortFunctions.length !== 1) throw new Error('Expected one SidebarSortMenu');
  const sortSelections = nodes(sortFunctions[0].body, (node) =>
    ts.isJsxSelfClosingElement(node) && node.tagName.getText() === 'SelectionPopover');
  if (sortSelections.length !== 1) throw new Error('Sidebar sort selection structure changed');
  const recipes = [
    metadata('webSelectionPanel', selection, ['SelectionPopoverSections'], { slots: sectionSlots }),
    metadata('webMenuAction', action, ['MenuItem'], { slots: { root: actionClasses } }),
    metadata('webSelectionRow', selection, ['SelectionPopoverOptionRow'], {
      slots: { root: [], leading: [], label: [], indicator },
      variants: Object.fromEntries(['checked', 'disabled', 'italic'].map((key) => [key, { true: {}, false: {} }])),
      defaultVariants: { checked: false, disabled: false, italic: false },
      compoundVariants: combinations.map(({ checked, disabled, italic, root, leading, label }) => ({
        checked, disabled, italic, class: { root, leading, label },
      })),
    }),
    metadata('webSidebarSortMenu', sort, ['SidebarSortMenu'], { slots: {
      root: `${sectionSlots.root} ${className(sortSelections[0], new Map())}`,
    } }),
    metadata('webHelpMenu', help, ['HelpMenu'], { slots: {
      root: className(helpPopovers[0], new Map()),
      header: className(helpHeaders[0], new Map()),
    } }),
  ];
  return recipes;

}
