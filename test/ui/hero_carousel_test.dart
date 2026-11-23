import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portix/models/game.dart';
import 'package:portix/shared/widgets/hero_carousel.dart';

import 'ui_test_helpers.dart';

// O carrossel da Início mostra o BANNER horizontal (`banner_url`, mantido no
// Supabase para os jogos destacados) em vez da capa recortada; sem banner,
// cai para a capa. Nunca há botão de download sobre a arte: o card inteiro
// abre a ficha do jogo.

Game _game(String id, {String? cover, String? banner}) => Game(
  id: id,
  slug: 'jogo-$id',
  title: 'Jogo de Teste $id',
  coverUrl: cover,
  bannerUrl: banner,
  platforms: const <String>['Xbox 360'],
);

void main() {
  testWidgets('carrossel usa o banner do jogo quando ele existe', (
    WidgetTester tester,
  ) async {
    final Game comBanner = _game(
      '1',
      cover: 'https://exemplo.test/capa-1.jpg',
      banner: 'https://exemplo.test/banner-1.jpg',
    );
    await pumpUi(tester, child: HeroCarousel(games: <Game>[comBanner]));
    await tester.pump();

    final Set<String?> urls = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((CachedNetworkImage image) => image.imageUrl)
        .toSet();
    expect(urls, contains('https://exemplo.test/banner-1.jpg'));
    expect(urls, isNot(contains('https://exemplo.test/capa-1.jpg')));

    // Descarta o widget (cancela o timer do autoplay) para o teste não
    // terminar com Timer pendente.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sem banner, o carrossel cai para a capa', (
    WidgetTester tester,
  ) async {
    final Game semBanner = _game('2', cover: 'https://exemplo.test/capa-2.jpg');
    final Game semArte = _game('3');
    await pumpUi(
      tester,
      child: HeroCarousel(games: <Game>[semBanner, semArte]),
    );
    await tester.pump();

    final Set<String?> urls = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((CachedNetworkImage image) => image.imageUrl)
        .toSet();
    expect(urls, contains('https://exemplo.test/capa-2.jpg'));

    // Descarta o widget (cancela o timer do autoplay).
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('não há botão de download/ver sobre o banner', (
    WidgetTester tester,
  ) async {
    final Game comBanner = _game(
      '4',
      cover: 'https://exemplo.test/capa-4.jpg',
      banner: 'https://exemplo.test/banner-4.jpg',
    );
    await pumpUi(tester, child: HeroCarousel(games: <Game>[comBanner]));
    await tester.pump();

    expect(find.text('Baixar'), findsNothing);
    expect(find.text('Ver'), findsNothing);

    // Descarta o widget (cancela o timer do autoplay).
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('legenda não colide com o selo de plataforma em fonte grande', (
    WidgetTester tester,
  ) async {
    final Game comBanner = _game(
      '5',
      cover: 'https://exemplo.test/capa-5.jpg',
      banner: 'https://exemplo.test/banner-5.jpg',
    );
    // Regressão do layout antigo (OverflowBox sem limite): a legenda crescia
    // para cima e o título entrava por cima do selo "Xbox 360".
    await pumpUi(
      tester,
      size: const Size(360, 640),
      textScale: 2.0,
      child: HeroCarousel(games: <Game>[comBanner], showMeta: true),
    );
    await tester.pump();

    final Rect selo = tester.getRect(find.text('Xbox 360'));
    final Rect titulo = tester.getRect(find.text('Jogo de Teste 5'));
    // A legenda é limitada à caixa do card: abaixo do selo, sem invasão.
    expect(titulo.top, greaterThanOrEqualTo(selo.bottom));

    // Descarta o widget (cancela o timer do autoplay).
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mostra desenvolvedor e nota quando há espaço (showMeta)', (
    WidgetTester tester,
  ) async {
    final Game comNota = Game(
      id: '6',
      slug: 'jogo-6',
      title: 'Jogo de Teste 6',
      coverUrl: 'https://exemplo.test/capa-6.jpg',
      bannerUrl: 'https://exemplo.test/banner-6.jpg',
      developer: 'PortStudio',
      rating: 4.5,
      ratingCount: 120,
      platforms: const <String>['Switch'],
    );
    await pumpUi(
      tester,
      child: HeroCarousel(games: <Game>[comNota], showMeta: true),
    );
    await tester.pump();

    expect(find.text('PortStudio'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);

    // Descarta o widget (cancela o timer do autoplay).
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
