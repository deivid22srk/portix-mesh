import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Especificações do aparelho usadas no feedback de compatibilidade.
class DeviceSpecs {
  const DeviceSpecs({
    this.brand,
    this.model,
    this.device,
    this.hardware,
    this.soc,
    this.gpu,
    this.ramGb,
    this.cores,
    this.sdk,
  });

  final String? brand;
  final String? model;
  final String? device;
  final String? hardware;
  final String? soc;
  final String? gpu;
  final int? ramGb;
  final int? cores;
  final int? sdk;

  static const DeviceSpecs unknown = DeviceSpecs();

  factory DeviceSpecs.fromMap(Map<Object?, Object?> map) {
    String? text(Object? value) {
      final String value2 = value?.toString().trim() ?? '';
      return value2.isEmpty ? null : value2;
    }

    int? number(Object? value) => value is num ? value.toInt() : null;

    return DeviceSpecs(
      brand: text(map['brand']),
      model: text(map['model']),
      device: text(map['device']),
      hardware: text(map['hardware']),
      soc: text(map['soc']),
      gpu: text(map['gpu']),
      ramGb: number(map['ramGb']),
      cores: number(map['cores']),
      sdk: number(map['sdk']),
    );
  }
}

/// Lê os dados do aparelho no Android (canal `portix/device`).
class DeviceInfo {
  const DeviceInfo._();

  static const MethodChannel _channel = MethodChannel('portix/device');
  static DeviceSpecs? _cached;

  static Future<DeviceSpecs> load() async {
    final DeviceSpecs? cached = _cached;
    if (cached != null) {
      return cached;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _cached = DeviceSpecs.unknown;
      return _cached!;
    }
    try {
      final Map<Object?, Object?>? map = await _channel
          .invokeMethod<Map<Object?, Object?>>('info');
      _cached = DeviceSpecs.fromMap(map ?? const <Object?, Object?>{});
    } on Object {
      _cached = DeviceSpecs.unknown;
    }
    return _cached!;
  }
}
