import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows window starts maximized', () async {
    final source = await File('lib/main.dart').readAsString();
    final nativeSource =
        await File('windows/runner/win32_window.cpp').readAsString();

    final readyIndex = source.indexOf('windowManager.waitUntilReadyToShow');
    final maximizeIndex = source.indexOf('await windowManager.maximize();');

    expect(readyIndex, greaterThanOrEqualTo(0));
    expect(maximizeIndex, greaterThan(readyIndex));
    expect(nativeSource, contains('ShowWindow(window_handle_, SW_MAXIMIZE)'));
  });

  test('Windows exit hides the window before session cleanup', () async {
    final source = await File('lib/app.dart').readAsString();
    final hideIndex = source.indexOf('await windowManager.hide();');
    final logoutIndex = source.indexOf(
      'await ref.read(authProvider.notifier).logout();',
    );

    expect(hideIndex, greaterThanOrEqualTo(0));
    expect(logoutIndex, greaterThan(hideIndex));
  });

  test('settings groups use downward expandable sections', () async {
    final source = await File(
      'lib/presentation/screens/settings/settings_screen.dart',
    ).readAsString();

    expect(source, contains('class _SettingsSection'));
    expect(source, contains('ExpansionTile('));
    expect(RegExp(r'_SettingsSection\(').allMatches(source).length,
        greaterThanOrEqualTo(6));
  });
}
