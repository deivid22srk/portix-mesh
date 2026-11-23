import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portix/core/formatters.dart';

void main() {
  group('compactNumber', () {
    test('mantém números pequenos', () {
      expect(compactNumber(0), '0');
      expect(compactNumber(999), '999');
    });

    test('usa sufixo k com uma casa decimal', () {
      expect(compactNumber(1200), '1,2k');
      expect(compactNumber(1500), '1,5k');
    });

    test('arredonda milhares grandes e milhões', () {
      expect(compactNumber(150000), '150k');
      expect(compactNumber(2500000), '2,5M');
    });
  });

  group('texto', () {
    test('iniciais ignoram artigos', () {
      expect(initialsOf('Super Mario 64'), 'SM');
      expect(initialsOf('The Legend of Zelda'), 'LZ');
      expect(initialsOf('   '), 'P');
    });

    test('truncate adiciona reticências', () {
      expect(truncate('PORTIX', 10), 'PORTIX');
      expect(truncate('abcdefgh', 5), 'abcd…');
    });

    test('datas em pt e en', () {
      final DateTime date = DateTime(2024, 3, 7);
      expect(formatMonthYear(date, en: true), 'Mar 2024');
      expect(formatMonthYear(date, en: false), 'mar 2024');
      expect(formatDate(date, en: false), '07 mar 2024');
      expect(monthShort(13, en: false), '');
    });

    test('dias relativos', () {
      final DateTime now = DateTime.now();
      expect(
        relativeDay(now.subtract(const Duration(days: 1)), en: false),
        'ontem',
      );
      expect(
        relativeDay(now.subtract(const Duration(days: 1)), en: true),
        'yesterday',
      );
    });

    test('saudação por horário', () {
      expect(greetingFor(DateTime(2024, 1, 1, 7), en: false), 'Bom dia');
      expect(greetingFor(DateTime(2024, 1, 1, 14), en: false), 'Boa tarde');
      expect(greetingFor(DateTime(2024, 1, 1, 21), en: true), 'Good evening');
    });
  });

  group('números e cores', () {
    test('nota formatada com vírgula', () {
      expect(formatRating(0), '—');
      expect(formatRating(4.5), '4,5');
    });

    test('percentual arredondado', () {
      expect(formatPercent(0.42), '42%');
      expect(formatPercent(1.4), '100%');
    });

    test('hash e gradiente estáveis', () {
      expect(stableHash('portix'), stableHash('portix'));
      final List<Color> first = coverColorsFor('Super Mario 64');
      final List<Color> second = coverColorsFor('Super Mario 64');
      expect(first.length, 2);
      expect(first[0], second[0]);
      expect(first[1], second[1]);
    });
  });

  group('formatBytes', () {
    test('unidades e vírgula decimal', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(131072), '128,0 KB');
      expect(formatBytes(1048576), '1,0 MB');
      expect(formatBytes(-5), '0 B');
    });
  });

  group('formatSpeed', () {
    test('zero e velocidades comuns', () {
      expect(formatSpeed(0), '0 B/s');
      expect(formatSpeed(1048576.0), '1,0 MB/s');
    });
  });

  group('formatEta', () {
    test('relógio e desconhecido', () {
      expect(formatEta(-1), isNull);
      expect(formatEta(0), '0:00');
      expect(formatEta(194), '3:14');
      expect(formatEta(4500), '1:15:00');
    });
  });
}
