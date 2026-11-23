import 'parsing.dart';

/// Resumo de compatibilidade de um jogo (5 vereditos).
class CompatSummary {
  const CompatSummary({
    this.perfect = 0,
    this.good = 0,
    this.stutter = 0,
    this.unplayable = 0,
    this.notRun = 0,
    this.total = 0,
  });

  final int perfect;
  final int good;
  final int stutter;
  final int unplayable;
  final int notRun;
  final int total;

  bool get isEmpty => total == 0;

  factory CompatSummary.fromMap(Map<String, dynamic> map) => CompatSummary(
    perfect: asInt(map['perfect']),
    good: asInt(map['good']),
    stutter: asInt(map['stutter']),
    unplayable: asInt(map['unplayable']),
    notRun: asInt(map['not_run']),
    total: asInt(map['total']),
  );
}
