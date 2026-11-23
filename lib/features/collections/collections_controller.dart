import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/collections.dart';
import '../../models/game.dart';

final collectionsProvider =
    AsyncNotifierProvider<CollectionsNotifier, Collections>(
      CollectionsNotifier.new,
    );

class CollectionsNotifier extends AsyncNotifier<Collections> {
  @override
  Future<Collections> build() =>
      ref.watch(catalogRepositoryProvider).fetchCollections();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(catalogRepositoryProvider).fetchCollections(),
    );
  }

  Future<bool> toggleFavorite(Game game) async {
    final Collections current = state.value ?? Collections.empty;
    final bool wasFavorite = current.isFavorite(game.id);
    state = AsyncData(
      wasFavorite
          ? current.withoutFavorite(game.id)
          : current.withFavorite(game),
    );
    try {
      final bool nowFavorite = await ref
          .read(catalogRepositoryProvider)
          .toggleFavorite(game.id);
      if (nowFavorite == wasFavorite) {
        await refresh();
      }
      return true;
    } on Object {
      state = AsyncData(current);
      return false;
    }
  }

  Future<bool> toggleLibrary(Game game) async {
    final Collections current = state.value ?? Collections.empty;
    final bool wasInLibrary = current.isInLibrary(game.id);
    state = AsyncData(
      wasInLibrary
          ? current.withoutLibraryGame(game.id)
          : current.withLibraryGame(game),
    );
    try {
      final bool nowInLibrary = await ref
          .read(catalogRepositoryProvider)
          .toggleLibrary(game.id);
      if (nowInLibrary == wasInLibrary) {
        await refresh();
      }
      return true;
    } on Object {
      state = AsyncData(current);
      return false;
    }
  }
}
