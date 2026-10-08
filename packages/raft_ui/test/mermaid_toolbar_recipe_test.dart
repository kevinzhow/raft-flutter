import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  RaftMermaidToolbarRecipe recipe(
    double viewport,
    double available, {
    RaftDensity density = RaftDensity.desktop,
    bool source = false,
  }) => RaftMermaidToolbarRecipe(
    viewportWidth: viewport,
    availableWidth: available,
    density: density,
    showSource: source,
    diagramTabWidth: 88,
    sourceTabWidth: 64,
  );
  test('compact source geometry and actual touch budget stay distinct', () {
    final mouse = recipe(412, 227.4);
    expect(mouse.desktop, false);
    expect(mouse.gap, 8);
    expect(mouse.compactBudget, 188);
    expect(mouse.wrap, false);
    final touch = recipe(412, 227.4, density: RaftDensity.touch);
    expect(touch.compactBudget, 288);
    expect(touch.wrap, true);
    expect(touch.targetSize(28), 48);
    expect(recipe(412, 288, density: RaftDensity.touch).wrap, false);
    expect(recipe(412, 287.9, density: RaftDensity.touch).wrap, true);
    expect(
      recipe(412, 227.4, density: RaftDensity.touch, source: true).wrap,
      true,
    );
    expect(
      recipe(412, 232, density: RaftDensity.touch, source: true).wrap,
      false,
    );
    expect(
      recipe(412, 232, density: RaftDensity.touch, source: true).compactBudget,
      232,
    );
  });
  test(
    'desktop variant needs both source breakpoint and fitted translated tabs',
    () {
      final source = recipe(640, 332);
      expect(source.desktopBudget, 332);
      expect(source.desktop, true);
      expect(source.gap, 4);
      expect(source.tabVisualHeight, 24);
      expect(recipe(639.9, 800).desktop, false);
      expect(recipe(800, 331.9).desktop, false);
      expect(recipe(800, 500, density: RaftDensity.touch).desktop, true);
      expect(recipe(800, 227.4, density: RaftDensity.touch).desktop, false);
      final largeText = RaftMermaidToolbarRecipe(
        viewportWidth: 1000,
        availableWidth: 500,
        density: RaftDensity.desktop,
        showSource: false,
        diagramTabWidth: 240,
        sourceTabWidth: 200,
      );
      expect(largeText.desktop, false);
      expect(largeText.wrap, false);
    },
  );
}
