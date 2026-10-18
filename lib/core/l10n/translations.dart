// File: lib/core/l10n/translations.dart
// Description: Multi-language localization engine for UI strings in Persian and English.
// Combines language dictionaries and provides lookup helpers for application widgets.

import 'en_translations.dart';
import 'fa_translations.dart';

/// Central accessor for localized strings in English and Persian.
class AppStrings {
  static const Map<String, Map<String, String>> _values = {
    "en": enTranslations,
    "fa": faTranslations,
  };

  /// Retrieves the localized string corresponding to the specified key.
  static String get(String key, {String locale = "en"}) {
    return _values[locale]?[key] ?? _values["en"]?[key] ?? key;
  }

  /// Checks whether a localized translation exists for the given key.
  static bool has(String key, {String locale = "en"}) {
    return _values[locale]?.containsKey(key) ?? false;
  }
}
