import 'package:material_ui/material_ui.dart' show IconData, Icons;

import '../../app/app_strings.dart';

// ============================================================================
// Definições das categorias de configurações — ponto de verdade único para
// o hub, o master-detail e as rotas. Tabela "configuração antiga → categoria"
// registrada em .ralph/SETTINGS_MISSION.md (nada fica órfão).
// ============================================================================

/// Ids persistidos nas rotas (`/menu/<id>`).
const String kSettingsAccount = 'conta';
const String kSettingsAppearance = 'aparencia';
const String kSettingsNotifications = 'notificacoes';
const String kSettingsLanguage = 'idioma';
const String kSettingsData = 'dados';
const String kSettingsNetwork = 'rede';
const String kSettingsAbout = 'sobre';

/// Uma categoria: rota, ícone, título e descrição curta.
class SettingsCategory {
  const SettingsCategory({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String id;
  final IconData icon;
  final String Function(L10n l10n) title;
  final String Function(L10n l10n) description;
}

/// Lista na ordem do hub. Sem categorias vazias: tudo abaixo tem configuração.
final List<SettingsCategory> kSettingsCategories = <SettingsCategory>[
  SettingsCategory(
    id: kSettingsAccount,
    icon: Icons.person_rounded,
    title: (L10n l10n) => l10n.settingsCatAccount,
    description: (L10n l10n) => l10n.settingsCatAccountDesc,
  ),
  SettingsCategory(
    id: kSettingsAppearance,
    icon: Icons.palette_rounded,
    title: (L10n l10n) => l10n.settingsCatAppearance,
    description: (L10n l10n) => l10n.settingsCatAppearanceDesc,
  ),
  SettingsCategory(
    id: kSettingsNotifications,
    icon: Icons.notifications_rounded,
    title: (L10n l10n) => l10n.settingsCatNotifications,
    description: (L10n l10n) => l10n.settingsCatNotificationsDesc,
  ),
  SettingsCategory(
    id: kSettingsLanguage,
    icon: Icons.language_rounded,
    title: (L10n l10n) => l10n.settingsCatLanguage,
    description: (L10n l10n) => l10n.settingsCatLanguageDesc,
  ),
  SettingsCategory(
    id: kSettingsData,
    icon: Icons.storage_rounded,
    title: (L10n l10n) => l10n.settingsCatData,
    description: (L10n l10n) => l10n.settingsCatDataDesc,
  ),
  SettingsCategory(
    id: kSettingsNetwork,
    icon: Icons.hub_rounded,
    title: (L10n l10n) => l10n.settingsCatNetwork,
    description: (L10n l10n) => l10n.settingsCatNetworkDesc,
  ),
  SettingsCategory(
    id: kSettingsAbout,
    icon: Icons.info_rounded,
    title: (L10n l10n) => l10n.settingsCatAbout,
    description: (L10n l10n) => l10n.settingsCatAboutDesc,
  ),
];

/// Categoria por id (null se não existir → rota desconhecida vira 404).
SettingsCategory? settingsCategoryById(String id) {
  for (final SettingsCategory category in kSettingsCategories) {
    if (category.id == id) {
      return category;
    }
  }
  return null;
}
