import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/providers.dart';
import '../core/theme/themes.dart';

// Preferências do app. O tema é escolhido pelo usuário (ids em themes.dart);
// idioma e notificações completam as preferências simples.
class AppSettings {
  const AppSettings({
    this.locale = const Locale('pt', 'BR'),
    this.notifications = true,
    this.themeId = kThemeDark,
  });

  final Locale locale;
  final bool notifications;

  /// Id do tema escolhido (ver appThemePairFor em themes.dart).
  final String themeId;

  bool get isEnglish => locale.languageCode == 'en';

  AppSettings copyWith({
    Locale? locale,
    bool? notifications,
    String? themeId,
  }) => AppSettings(
    locale: locale ?? this.locale,
    notifications: notifications ?? this.notifications,
    themeId: themeId ?? this.themeId,
  );
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  static const String _localeKey = 'settings.locale';
  static const String _notificationsKey = 'settings.notifications';
  static const String _themeKey = 'settings.themeId';

  /// Ids de tema válidos — qualquer outro valor (dado antigo/corrompido) cai
  /// no tema padrão (escuro Aurora).
  static const Set<String> _validThemeIds = <String>{
    kThemeSystem,
    kThemeLight,
    kThemeDark,
    kThemeMidnight,
    kThemeOcean,
    kThemeForest,
    kThemeVice,
    kThemeCitrus,
    kThemeGold,
  };

  @override
  AppSettings build() {
    final SharedPreferences prefs = ref.watch(sharedPreferencesProvider);
    final String rawLocale = prefs.getString(_localeKey) ?? 'pt';
    final String? rawTheme = prefs.getString(_themeKey);
    return AppSettings(
      locale: rawLocale == 'en' ? const Locale('en') : const Locale('pt', 'BR'),
      notifications: prefs.getBool(_notificationsKey) ?? true,
      themeId: rawTheme != null && _validThemeIds.contains(rawTheme)
          ? rawTheme
          : kThemeDark,
    );
  }

  void setLocale(Locale locale) {
    state = state.copyWith(locale: locale);
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(_localeKey, locale.languageCode),
    );
  }

  void setNotifications(bool enabled) {
    state = state.copyWith(notifications: enabled);
    unawaited(
      ref.read(sharedPreferencesProvider).setBool(_notificationsKey, enabled),
    );
  }

  /// Troca o tema e persiste. O MaterialApp anima a transição (AppMotion.base) —
  /// troca instantânea e sutil, sem reconstruir navegação.
  void setThemeId(String id) {
    if (id == state.themeId) {
      return;
    }
    state = state.copyWith(themeId: id);
    unawaited(ref.read(sharedPreferencesProvider).setString(_themeKey, id));
  }
}
