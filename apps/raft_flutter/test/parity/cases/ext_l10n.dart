import '../parity_harness.dart';
import 'ext_shell.dart';
import 'ext_wp6.dart';

final Map<String, ParityCase> extL10nCases = {
  for (final platform in ['desktop', 'mobile'])
    for (final locale in ['en', 'es', 'pt-br', 'ru', 'ko', 'ja', 'zh-tw'])
      for (final theme in ['brutal', 'elegant-dark']) ...{
        if (locale == 'ru' || locale == 'ja')
          for (final surface in ['home', 'channel'])
            'components.shell.$platform.home.index.l10n-$surface-$locale.$theme':
                extShellCases['components.shell.$platform.home.index.$theme']!,
        for (final surface in ['settings', 'picker'])
          'components.wp6.${_settings(platform)}.l10n-$surface-$locale.$theme':
              extWp6Cases['components.wp6.${_settings(platform)}.$theme']!,
      },
};

String _settings(String platform) =>
    platform == 'mobile' ? 'settings.language-mobile' : 'settings.language';
