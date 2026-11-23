import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mesh/mesh_store.dart';
import 'providers.dart';

// ============================================================================
// "Conta" sem servidor de contas.
//
// No PORTIX não existe login central: a identidade é LOCAL (um id opaco gerado
// no aparelho) mais um nome/@ público que o usuário escolhe. Os dados ficam no
// dispositivo e viajam entre aparelhos pela malha (ver lib/core/mesh/).
// ============================================================================

/// Estado de identidade exibido no app.
class AccountState {
  const AccountState({
    this.id,
    this.displayName = '',
    this.email,
    this.handle,
    this.signedIn = false,
  });

  final String? id;
  final String displayName;

  /// Mantido por compatibilidade de UI; a identidade local não usa e-mail.
  final String? email;
  final String? handle;

  /// `true` quando o usuário já definiu um nome/@ (perfil público ativo).
  final bool signedIn;

  bool get hasSession => signedIn;
  bool get isAnonymous => !signedIn;
  bool get isSignedIn => signedIn;
}

final accountProvider = NotifierProvider<AccountController, AccountState>(
  AccountController.new,
);

class AccountController extends Notifier<AccountState> {
  @override
  AccountState build() {
    final MeshStore store = ref.watch(meshStoreProvider);
    // Qualquer mudança local ou vinda da malha reavalia o estado da conta.
    ref.listen<AsyncValue<int>>(meshRevisionProvider, (
      AsyncValue<int>? _,
      AsyncValue<int> __,
    ) {
      state = _stateFrom(ref.read(meshStoreProvider));
    });
    return _stateFrom(store);
  }

  AccountState _stateFrom(MeshStore store) {
    final String name = store.displayName;
    final String? handle = store.handle;
    final bool signedIn =
        name.isNotEmpty || (handle != null && handle.isNotEmpty);
    return AccountState(
      id: store.deviceId,
      displayName: name,
      handle: handle,
      signedIn: signedIn,
    );
  }

  /// Cria/atualiza a identidade local (nome + @handle opcional).
  Future<void> createIdentity({
    required String displayName,
    String? handle,
  }) async {
    ref
        .read(meshStoreProvider)
        .saveProfile(displayName: displayName, handle: handle);
  }

  /// Encerra o perfil público sem apagar os dados locais do aparelho.
  Future<void> signOut() async {
    ref.read(meshStoreProvider).saveProfile(displayName: '', handle: '');
  }
}

/// Nível de administrador. Sem painel ADM no backend local, nunca há ADM.
final adminLevelProvider = FutureProvider<String?>((ref) async => null);
