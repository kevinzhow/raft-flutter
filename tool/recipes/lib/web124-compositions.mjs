// Product compositions mounted by Web v1.24. Read class expressions from TSX;
// primitive surfaces remain references to the published component recipes.
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';

export function extractWeb124Compositions(web, ts) {
  const read = (path) => {
    const text = readFileSync(join(web, path), 'utf8');
    const ast = ts.createSourceFile(path, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
    if (ast.parseDiagnostics.length) throw Error(`Cannot parse ${path}`);
    return {path, text, ast};
  };
  const nodes = (root, predicate) => {
    const out = [];
    const visit = (n) => {if (predicate(n)) out.push(n); ts.forEachChild(n, visit);};
    visit(root); return out;
  };
  const one = (list, label) => {
    if (list.length !== 1) throw Error(`Expected one ${label}, got ${list.length}`);
    return list[0];
  };
  const opening = (n) => ts.isJsxElement(n) ? n.openingElement : n;
  const elements = (root, tag) => nodes(root, n =>
    (ts.isJsxElement(n) || ts.isJsxSelfClosingElement(n)) && opening(n).tagName.getText() === tag);
  function value(n, env = {}) {
    if (!n) return '';
    if (ts.isStringLiteral(n) || ts.isNoSubstitutionTemplateLiteral(n)) return n.text;
    if (ts.isNumericLiteral(n)) return Number(n.text);
    if (ts.isCallExpression(n) && ts.isIdentifier(n.expression) && n.arguments.length === 0 && n.expression.text in env)
      return env[n.expression.text];
    if (ts.isArrayLiteralExpression(n)) return n.elements.map(x => value(x, env));
    if (ts.isCallExpression(n) && ts.isPropertyAccessExpression(n.expression) && n.expression.name.text === 'join' && n.arguments.length === 1)
      return value(n.expression.expression, env).join(value(n.arguments[0], env));
    if (ts.isIdentifier(n) && n.text in env) return env[n.text];
    if (ts.isBinaryExpression(n) && n.operatorToken.kind === ts.SyntaxKind.EqualsEqualsEqualsToken)
      return value(n.left, env) === value(n.right, env);
    if (ts.isConditionalExpression(n)) return value(value(n.condition, env) ? n.whenTrue : n.whenFalse, env);
    if (ts.isTemplateExpression(n)) return n.head.text + n.templateSpans.map(p => String(value(p.expression, env)) + p.literal.text).join('');
    throw Error(`Unsupported Web class expression: ${n.getText().slice(0, 120)}`);
  }
  const attr = (n, name, env) => {
    const a = opening(n).attributes.properties.find(p => ts.isJsxAttribute(p) && p.name.text === name)?.initializer;
    return value(a && ts.isJsxExpression(a) ? a.expression : a, env);
  };
  const cls = (n, env) => attr(n, 'className', env);
  const fn = (src, name) => one(nodes(src.ast, n => ts.isFunctionDeclaration(n) && n.name?.text === name), name);
  const metadata = (name, sources, components, slots) => ({name, line: 1,
    region: 'Web ' + sources.map(s => `${s.path} sha256:${createHash('sha256').update(s.text).digest('hex')}`).join('; '),
    exported: [], directUsers: [], exportedComponents: components, options: {slots}, nonLiteral: [], resolvedIdentifiers: []});
  const recipeSlot = (recipe, slot, props = {}) => ({$recipeSlot: recipe, slot, props});

  const selection = read('src/components/ui/SelectionPopover.tsx');
  const sections = fn(selection, 'SelectionPopoverSections');
  const divs = elements(sections, 'div');
  if (divs.length !== 2) throw Error('SelectionPopover header/empty structure changed');
  const scroll = one(elements(sections, 'ScrollArea'), 'selection ScrollArea');
  const search = one(elements(sections, 'Search'), 'selection Search');
  const surface = one(elements(fn(selection, 'SelectionPopover'), 'PopoverContent'), 'selection surface');
  const sectionSlots = {root: [recipeSlot('popover', 'content')],
    header: cls(divs[0]), list: cls(scroll), content: attr(scroll, 'contentClassName'), empty: cls(divs[1]),
    title: cls(one(elements(sections, 'span'), 'selection title')),
    clear: [recipeSlot('textLinkVariants', 'base'), cls(one(elements(sections, 'TextLink'), 'selection clear'))],
    search: cls(one(elements(sections, 'label'), 'selection search row')),
    input: cls(one(elements(sections, 'input'), 'selection input')),
    searchIcon: `${cls(search)} size-[${attr(search, 'size')}px]`};
  const row = fn(selection, 'SelectionPopoverOptionRow');
  const rowButton = one(elements(row, 'button'), 'selection option');
  const spans = elements(rowButton, 'span');
  if (spans.length !== 3) throw Error('SelectionPopover option structure changed');
  const check = one(elements(row, 'Check'), 'selection check');
  const combinations = [];
  for (const checked of [false, true]) for (const disabled of [false, true]) for (const italic of [false, true]) {
    const env = {checked, disabled, italic};
    for (const decl of nodes(row.body, n => ts.isVariableDeclaration(n) && ['labelClassName', 'rowTone'].includes(n.name.getText())))
      env[decl.name.getText()] = value(decl.initializer, env);
    combinations.push({checked, disabled, italic, class: {root: cls(rowButton, env), leading: cls(spans[1], env), label: cls(spans[2], env)}});
  }
  const selectionRow = metadata('webSelectionRow', [selection], ['SelectionPopoverOptionRow'], {
    root: [], leading: [], label: [], indicator: `${cls(check)} size-[${attr(check, 'size')}px]`});
  selectionRow.options.variants = Object.fromEntries(['checked', 'disabled', 'italic'].map(k => [k, {true: {}, false: {}}]));
  selectionRow.options.defaultVariants = {checked: false, disabled: false, italic: false};
  selectionRow.options.compoundVariants = combinations;
  const action = read('src/components/ui/MenuItem.tsx');
  const actionClass = one(nodes(action.ast, n => ts.isVariableDeclaration(n) && n.name.getText() === 'MENU_ITEM_CLASS'), 'MENU_ITEM_CLASS');
  const help = read('src/components/layout/HelpMenu.tsx');
  const helpSurface = one(elements(fn(help, 'HelpMenu'), 'PopoverContent'), 'help surface');
  const helpDivs = elements(helpSurface, 'div');
  if (helpDivs.length !== 2) throw Error('HelpMenu header/list structure changed');
  const sort = read('src/components/layout/SidebarSortMenu.tsx');
  const sortSelection = one(elements(sort.ast, 'SelectionPopover'), 'sort selection');

  const dialog = read('src/components/ui/DialogCard.tsx');
  const edges = read('src/components/ui/headEdges.ts');
  const narrow = read('src/components/ui/NarrowDialog.tsx');
  const narrowSheet = read('src/components/ui/narrowSheet.ts');
  const env = {description: false};
  for (const decl of nodes(edges.ast, n => ts.isVariableDeclaration(n))) env[decl.name.getText()] = value(decl.initializer, env);
  const width = one(nodes(dialog.ast, n => ts.isBindingElement(n) && n.name.getText() === 'maxWidthClass' && n.initializer), 'dialog default width');
  env.maxWidthClass = value(width.initializer);
  const close = one(elements(dialog.ast, 'CloseButton'), 'dialog close');
  const glyph = one(elements(dialog.ast, 'X'), 'dialog close glyph');
  if (attr(close, 'size') !== 'icon-md') throw Error('Dialog close Button axis changed');
  const cardContent = one(elements(dialog.ast, 'NarrowDialogContent'), 'dialog content');
  const cardHeader = one(elements(dialog.ast, 'div'), 'dialog header');
  const cardScroll = one(elements(dialog.ast, 'ScrollArea'), 'dialog scroller');
  const descriptions = elements(dialog.ast, 'DialogDescription');
  if (descriptions.length !== 2) throw Error('DialogCard sheet/centered description branches changed');
  for (const decl of nodes(narrow.ast, n => ts.isVariableDeclaration(n) &&
    ['NARROW_BODY_CLASS', 'NARROW_BODY_CONTENT_CLASS', 'NARROW_SHEET_NO_LIFT_CLASS'].includes(n.name.getText())))
    env[decl.name.getText()] = value(decl.initializer, env);
  const narrowReturn = one(nodes(fn(narrowSheet, 'narrowSurfaceClass'), n => ts.isReturnStatement(n)), 'narrow surface return');
  env.narrowSurfaceClass = value(narrowReturn.expression, env);
  const narrowContents = elements(fn(narrow, 'NarrowDialogContent'), 'DialogContent');
  if (narrowContents.length !== 2) throw Error('NarrowDialog centered/sheet surface branches changed');
  const narrowScroll = one(elements(fn(narrow, 'NarrowDialogLayout'), 'ScrollArea'), 'narrow body scroller');
  const dialogSlots = {root: [], header: [], scrollArea: [], body: [], description: [],
    title: [recipeSlot('dialog', 'title'), cls(one(elements(dialog.ast, 'DialogTitle'), 'dialog title'))],
    close: cls(close, env), defaultWidth: env.maxWidthClass, glyph: `size-[${attr(glyph, 'size')}px]`};
  const dialogRecipe = metadata('webDialogCard', [dialog, edges, narrow, narrowSheet], ['DialogCard'], dialogSlots);
  dialogRecipe.options.variants = {presentation: {centered: {}, sheet: {}}, description: {true: {}, false: {}}};
  dialogRecipe.options.defaultVariants = {presentation: 'centered', description: false};
  dialogRecipe.options.compoundVariants = [];
  for (const presentation of ['centered', 'sheet']) for (const description of [false, true]) {
    const sheet = presentation === 'sheet';
    const context = {...env, description};
    dialogRecipe.options.compoundVariants.push({presentation, description, class: {
      root: [recipeSlot('dialog', 'content'), sheet ? cls(narrowContents[1], context) : cls(cardContent, context)],
      header: sheet ? recipeSlot('panelHeader', 'header') : cls(cardHeader, context),
      scrollArea: sheet ? cls(narrowScroll, context) : cls(cardScroll, context),
      body: sheet ? attr(narrowScroll, 'contentClassName', context) : attr(cardScroll, 'contentClassName', context),
      description: description ? [recipeSlot('dialog', 'description'), cls(descriptions[sheet ? 0 : 1], context)] : [],
    }});
  }
  const selectionRecipe = metadata('webSelectionPanel', [selection], ['SelectionPopoverSections'], sectionSlots);
  selectionRecipe.options.variants = {width: Object.fromEntries(['content', 'trigger'].map(width => [width,
    {root: cls(surface, {width, className: ''})}]))};
  selectionRecipe.options.defaultVariants = {width: 'content'};

  const member = read('src/components/channel/MemberChoiceList.tsx');
  const choice = one(elements(member.ast, 'ChoiceList'), 'member ChoiceList');
  if (attr(choice, 'search') !== 'always') throw Error('MemberChoiceList search policy changed');
  const memberSpans = elements(member.ast, 'span');
  if (memberSpans.length !== 2) throw Error('MemberChoiceList badge/label structure changed');
  const memberSlots = {root: recipeSlot('choiceList', 'frame'), group: recipeSlot('choiceList', 'heading'),
    row: recipeSlot('choiceList', 'item'), label: [recipeSlot('choiceList', 'label'), cls(memberSpans[1])],
    empty: recipeSlot('choiceList', 'note'), badge: cls(memberSpans[0]),
    scroller: recipeSlot('choiceList', 'scroller'), rows: recipeSlot('choiceList', 'rows')};
  const memberRecipe = metadata('webMemberPicker', [member], ['MemberChoiceList'], memberSlots);
  // MemberChoiceList has search="always". Published ChoiceList selects
  // scroll: searchable && !fill; its max-height belongs to the scroller,
  // not the surrounding frame. Preserve the alternate fill branch as well.
  memberRecipe.options.variants = {fill: {false: {}, true: {}}};
  memberRecipe.options.defaultVariants = {fill: false};
  memberRecipe.options.compoundVariants = [false, true].map(fill => ({fill, class: {
    root: recipeSlot('choiceList', 'frame', {scroll: !fill, fill}),
    scroller: recipeSlot('choiceList', 'scroller', {scroll: !fill, fill}),
  }}));
  return [selectionRecipe, selectionRow,
    metadata('webMenuAction', [action], ['MenuItem'], {root: value(actionClass.initializer)}),
    metadata('webHelpMenu', [help], ['HelpMenu'], {root: cls(helpSurface), header: cls(helpDivs[0])}),
    metadata('webSidebarSortMenu', [selection, sort], ['SidebarSortMenu'], {root: [recipeSlot('webSelectionPanel', 'root'), cls(sortSelection)]}),
    dialogRecipe,
    memberRecipe];
}
