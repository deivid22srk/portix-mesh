// Fixtures e fakes compartilhados entre o teste da página e os goldens.
import 'package:portix/core/github_releases.dart';
import 'package:portix/models/game.dart';
import 'package:portix/models/game_detail.dart';
import 'package:portix/models/compat_summary.dart';

const Game kSporeGame = Game(
  id: 'spore-1',
  slug: 'spore',
  title: 'Spore',
  genre: 'Sandbox',
  platforms: <String>['Android'],
  downloadCount: 1200,
  rating: 4.6,
  ratingCount: 132,
  description: 'Port de Spore para Android. Build Vulkan 1.3 recomendada.',
);

const GamePort kSporePort = GamePort(
  id: 'p1',
  portKey: 'spore-re',
  platformName: 'Android',
  platformSlug: 'android',
  url: 'https://github.com/VinTeRuS/spore-re',
);

const GameDetail kSporeDetail = GameDetail(
  game: kSporeGame,
  ports: <GamePort>[kSporePort],
  compat: CompatSummary(),
);

ApkAsset kApk(String name) => ApkAsset(
  name: name,
  url: 'https://github.com/VinTeRuS/spore-re/releases/download/v1/$name',
  sizeBytes: 98818871,
  downloadCount: 106,
);

// Dados REAIS capturados de GET /repos/VinTeRuS/spore-re/releases (17/11/2026).
final List<GithubRelease> kSporeReleases = <GithubRelease>[
  GithubRelease(
    tag: 'v0.1.4',
    publishedAt: DateTime(2026, 11, 16, 19, 45),
    body:
        'Early build, expect bugs.\n- `spore.apk` is for **Vulkan 1.3 GPUs** (most phones)\n- `spore-vk11.apk` for older ones with Vulkan 1.1',
    assets: <ApkAsset>[kApk('spore.apk'), kApk('spore-vk11.apk')],
  ),
  GithubRelease(
    tag: 'v0.1.3',
    publishedAt: DateTime(2026, 11, 15, 17, 59),
    body: 'Early build, expect bugs.',
    assets: <ApkAsset>[kApk('spore-v0.1.3.apk')],
  ),
  GithubRelease(
    tag: 'v0.1.2-beta',
    prerelease: true,
    publishedAt: DateTime(2026, 11, 15, 8, 32),
    assets: const <ApkAsset>[], // caso de borda: release sem APK
  ),
];

const GithubUser kSporeUser = GithubUser(
  login: 'VinTeRuS',
  name: 'VinTeRuS404',
  avatarUrl: '', // fallback de iniciais nos renders (sem rede em teste)
  htmlUrl: 'https://github.com/VinTeRuS',
  type: 'User',
  publicRepos: 13,
  followers: 37,
);
