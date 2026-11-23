import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portix/app/app_strings.dart';

void main() {
  test('português é o padrão do produto', () {
    const L10n pt = L10n(Locale('pt', 'BR'));
    expect(pt.install, 'Instalar');
    expect(pt.tagline, contains('consoles'));
    expect(pt.gameCount(1), '1 jogo');
    expect(pt.gameCount(3), '3 jogos');
    expect(pt.portCount(1), '1 port');
    expect(pt.platformCount(26), '26 plataformas');
  });

  test('inglês cobre navegação e plural', () {
    const L10n en = L10n(Locale('en'));
    expect(en.navHome, 'Home');
    expect(en.install, 'Install');
    expect(en.resultsCount(0), '0 results');
    expect(en.resultsCount(1), '1 result');
    expect(en.libraryEmpty, 'Your library is empty');
  });

  test('percentual localizado', () {
    const L10n pt = L10n(Locale('pt', 'BR'));
    const L10n en = L10n(Locale('en'));
    expect(pt.progressPercent(42), '42%');
    expect(en.progressPercent(7), '7%');
  });
}
