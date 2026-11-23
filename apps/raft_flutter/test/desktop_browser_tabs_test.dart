import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/desktop_browser_tabs.dart';

void main() {
  late DesktopBrowserTabs tabs;

  setUp(() {
    tabs = DesktopBrowserTabs();
    addTearDown(tabs.dispose);
  });

  Uri page(int number) => Uri.parse('https://example.test/$number');

  test('reopening a redirected address selects the original tab', () {
    tabs.open('first', page(1));
    final original = tabs.forConversation('first')!.active;
    tabs.report('first', original.id, (
      url: page(2),
      title: 'Redirected',
      back: true,
      forward: false,
      loading: false,
    ));
    tabs.open('first', page(3));
    tabs.open('first', page(1));
    expect(tabs.forConversation('first')!.tabs, hasLength(2));
    expect(tabs.forConversation('first')!.active.id, original.id);
    expect(tabs.forConversation('first')!.active.url, page(2));
    expect(tabs.forConversation('first')!.active.title, 'Redirected');
    tabs.open('first', page(2));
    expect(tabs.forConversation('first')!.tabs, hasLength(2));
  });

  test('the cap preserves the selected tab and disables empty tabs', () {
    for (var number = 0; number < 12; number++) {
      tabs.open('first', page(number));
    }
    final selected = tabs.forConversation('first')!.active;
    tabs.newTab('first');
    expect(tabs.forConversation('first')!.active, same(selected));
    tabs.open('first', page(12));
    final replaced = tabs.forConversation('first')!.active;
    expect(tabs.forConversation('first')!.tabs, hasLength(12));
    expect(replaced.id, selected.id);
    expect(replaced.url, page(12));
    expect(replaced.navigation, selected.navigation + 1);
  });

  test('closing selects the right neighbor, then the left, then closes', () {
    tabs.open('first', page(1));
    tabs.open('first', page(2));
    tabs.newTab('first');
    final all = tabs.forConversation('first')!.tabs;
    expect(all.last.url, isNull);
    tabs.activate('first', all[1].id);
    tabs.closeTab('first', all[1].id);
    expect(tabs.forConversation('first')!.active.id, all.last.id);
    tabs.closeTab('first', all.last.id);
    expect(tabs.forConversation('first')!.active.id, all.first.id);
    tabs.closeTab('first', all.first.id);
    expect(tabs.forConversation('first'), isNull);
  });

  test('parking keeps tabs, and closing affects only that conversation', () {
    tabs.open('first', page(1));
    tabs.open('other', page(2));
    final first = tabs.forConversation('first')!.active;
    var returnedFocus = false;
    tabs.open('first', page(1), onClose: () => returnedFocus = true);
    tabs.park('first');
    expect(tabs.forConversation('first')!.active, same(first));
    expect(tabs.forConversation('first')!.inFrontOf(0), isFalse);
    tabs.raise('first');
    expect(tabs.forConversation('first')!.inFrontOf(0), isTrue);
    tabs.close('first');
    expect(returnedFocus, isTrue);
    expect(tabs.forConversation('other')!.active.url, page(2));
    tabs.open('first', page(3));
    expect(tabs.forConversation('first')!.tabs, hasLength(1));
  });

  test('typing an address updates only that tab and clears its old title', () {
    tabs.open('first', page(1));
    final original = tabs.forConversation('first')!.active;
    tabs.newTab('first');
    final empty = tabs.forConversation('first')!.active;
    tabs.navigate('first', empty.id, page(2));
    final changed = tabs.forConversation('first')!.active;
    expect(tabs.forConversation('first')!.tabs.first, same(original));
    expect(changed.url, page(2));
    expect(changed.title, isEmpty);
    expect(changed.loading, isTrue);
    expect(changed.navigation, 1);
  });
}
