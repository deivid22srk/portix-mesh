import '../../app/app_strings.dart';

// ============================================================================
// Dicionário do vocabulário das fichas técnicas (dados vindos da API, que
// publica em inglês). Tradução de CONTEÚDO dos aparelhos — o chrome do app
// (títulos, botões, estados) continua nas strings do L10n.
// ============================================================================

/// Títulos das seções da ficha (ex.: `Display` → `Tela`).
const Map<String, String> _specSectionPt = <String, String>{
  'Network': 'Rede',
  'Launch': 'Lançamento',
  'Body': 'Corpo',
  'Display': 'Tela',
  'Platform': 'Plataforma',
  'Memory': 'Memória',
  'Main Camera': 'Câmera principal',
  'Selfie camera': 'Câmera frontal',
  'Sound': 'Som',
  'Comms': 'Conexões',
  'Features': 'Recursos',
  'Battery': 'Bateria',
  'Misc': 'Diversos',
  'Tests': 'Testes',
};

/// Rótulos das linhas dentro de cada seção (ex.: `Resolution` → `Resolução`).
const Map<String, String> _specRowPt = <String, String>{
  'Technology': 'Tecnologia',
  '2G bands': 'Bandas 2G',
  '3G bands': 'Bandas 3G',
  '4G bands': 'Bandas 4G',
  '5G bands': 'Bandas 5G',
  'Speed': 'Velocidade',
  'Announced': 'Anunciado',
  'Status': 'Disponibilidade',
  'Dimensions': 'Dimensões',
  'Weight': 'Peso',
  'Build': 'Construção',
  'SIM': 'SIM',
  'Type': 'Tipo',
  'Size': 'Tamanho',
  'Resolution': 'Resolução',
  'Protection': 'Proteção',
  'OS': 'Sistema',
  'Chipset': 'Chipset',
  'CPU': 'CPU',
  'GPU': 'GPU',
  'Card slot': 'Cartão de memória',
  'Internal': 'Armazenamento',
  'Single': 'Principal',
  'Triple': 'Tripla',
  'Quad': 'Quádrupla',
  'Dual': 'Dupla',
  'Features': 'Recursos',
  'Video': 'Vídeo',
  'Loudspeaker': 'Alto-falante',
  '3.5mm jack': 'Saída 3,5 mm',
  'WLAN': 'Wi-Fi',
  'Bluetooth': 'Bluetooth',
  'Positioning': 'Localização',
  'NFC': 'NFC',
  'Radio': 'Rádio FM',
  'USB': 'USB',
  'Sensors': 'Sensores',
  'Other': 'Outros',
  'Colors': 'Cores',
  'Models': 'Modelos',
  'SAR EU': 'SAR (UE)',
  'SAR': 'SAR',
  'Price': 'Preço',
  'Charging': 'Carregamento',
  'Stand-by': 'Em espera',
  'Talk time': 'Conversa',
  'Music play': 'Música',
  'Sound': 'Som',
  'Camera': 'Câmera',
  'Games': 'Jogos',
  'Java': 'Java',
  'Browser': 'Navegador',
  'Alert types': 'Alertas',
  'Messaging': 'Mensagens',
  'Clock': 'Relógio',
  'Alarm': 'Alarme',
  'Languages': 'Idiomas',
  'Performance': 'Desempenho',
};

/// Título de seção localizado: em inglês devolve o original da API; em
/// português aplica o dicionário (caí no `raw` quando não mapeado).
String specSectionLabel(L10n l10n, String raw) {
  if (l10n.isEn) {
    return raw;
  }
  return _specSectionPt[raw] ?? raw;
}

/// Rótulo de linha localizado (mesma regra da seção).
String specRowLabel(L10n l10n, String raw) {
  if (l10n.isEn) {
    return raw;
  }
  return _specRowPt[raw] ?? raw;
}
