import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Identidade local do dispositivo na malha.
///
/// Não existe servidor de contas: a identidade é gerada e guardada no próprio
/// aparelho. É o `device` usado no protocolo do relay e a chave local dos
/// dados do usuário (favoritos, biblioteca, relatos).
class MeshIdentity {
  const MeshIdentity({required this.deviceId, required this.displayName});

  final String deviceId;
  final String displayName;

  MeshIdentity copyWith({String? displayName}) => MeshIdentity(
    deviceId: deviceId,
    displayName: displayName ?? this.displayName,
  );
}

class MeshIdentityStore {
  MeshIdentityStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _idKey = 'mesh.device_id';
  static const String _nameKey = 'mesh.display_name';

  /// Carrega a identidade ou cria uma na primeira execução.
  MeshIdentity loadOrCreate() {
    String? id = _prefs.getString(_idKey);
    if (id == null || id.isEmpty) {
      id = newDeviceId();
      _prefs.setString(_idKey, id);
    }
    return MeshIdentity(
      deviceId: id,
      displayName: _prefs.getString(_nameKey) ?? '',
    );
  }

  Future<void> saveDisplayName(String name) =>
      _prefs.setString(_nameKey, name.trim());

  /// Gera um id opaco de 128 bits (hex) — nunca um dado pessoal.
  static String newDeviceId() {
    final Random random = Random.secure();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
