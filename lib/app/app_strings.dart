import 'package:flutter/widgets.dart';

// Textos do app em pt-BR e en, sem codegen: menos partes móveis no CI,
// tipagem direta e troca de idioma instantânea pelo MaterialApp.
class L10n {
  const L10n(this.locale);

  final Locale locale;

  bool get isEn => locale.languageCode == 'en';

  String _t(String pt, String en) => isEn ? en : pt;

  // ---------------------------------------------------------------- marca
  String get appName => 'PORTIX';
  String get tagline =>
      _t('Seus consoles. No seu bolso.', 'Your consoles. In your pocket.');

  // ------------------------------------------------------------ navegação
  String get navHome => _t('Início', 'Home');

  // ------------------------------------------------------------------ home
  String get sectionClassics => _t('Clássicos eternos', 'Timeless classics');
  String get sectionFree => _t('Grátis e aberto', 'Free and open');
  String get sectionPlatforms => _t('Por plataforma', 'By platform');
  String get sectionGenres => _t('Por gênero', 'By genre');
  String get seeAll => _t('Ver tudo', 'See all');

  // ---------------------------------------------------------------- busca
  String get searchHint =>
      _t('Buscar jogos, gêneros, devs', 'Search games, genres, devs');
  String get filters => _t('Filtros', 'Filters');
  String get filterPlatform => _t('Plataforma', 'Platform');
  String get filterGenre => _t('Gênero', 'Genre');
  String get filterFree => _t('Somente grátis', 'Free only');
  String get filterRom => _t('Precisa de arquivos', 'Needs game files');
  String get sortLabel => _t('Ordenar', 'Sort');
  String get sortTrending => _t('Em alta', 'Trending');
  String get sortRecent => _t('Recentes', 'Recent');
  String get sortAz => 'A–Z';
  String get sortYear => _t('Mais novos', 'Newest');
  String get apply => _t('Aplicar', 'Apply');
  String get reset => _t('Limpar', 'Reset');
  String get all => _t('Tudo', 'All');
  String get noResultsTitle => _t('Nada por aqui', 'Nothing here');
  String get noResultsBody => _t(
    'Nenhum port combina com esses filtros. Tente outra busca.',
    'No port matches these filters. Try another search.',
  );
  String get recentSearches => _t('Buscas recentes', 'Recent searches');
  String get clearHistory => _t('Limpar histórico', 'Clear history');

  // -------------------------------------------------------------- detalhes
  String get install => _t('Instalar', 'Install');
  String get continueAction => _t('Continuar', 'Continue');
  String get open => _t('Abrir', 'Open');
  String get installedLabel => _t('Instalado', 'Installed');
  String get openApp => _t('Abrir o app', 'Open app');
  String get addToLibrary => _t('Biblioteca', 'Library');
  String get inLibrary => _t('Na biblioteca', 'In library');
  String get favoriteTooltip => _t('Favoritar', 'Add to wishlist');
  String get share => _t('Compartilhar', 'Share');
  String get linkCopied => _t('Link copiado', 'Link copied');
  String get portsTitle => _t('Ports disponíveis', 'Available ports');
  String get readMore => _t('Ler mais', 'Read more');
  String get readLess => _t('Ler menos', 'Show less');
  String get releaseYear => _t('Ano', 'Year');
  String get developer => _t('Desenvolvedor', 'Developer');
  String get genreLabel => _t('Gênero', 'Genre');
  String get platformsLabel => _t('Plataformas', 'Platforms');
  String get portUpdated => _t('Atualizado', 'Updated');
  String get openSource => _t('Abrir fonte', 'Open source');
  String get noLink => _t('Sem link', 'No link');
  String get needsFiles => _t('Arquivos do jogo', 'Game files');
  String get needsFilesYes => _t('Necessários', 'Required');
  String get needsFilesNo => _t('Não precisa', 'Not required');
  String get controllerSupport => _t('Controle', 'Controller');
  String get notInformed => _t('Não informado', 'Not informed');
  String get worksYes => _t('Funciona', 'Works');
  String get worksNo => _t('Não funciona', 'Broken');
  String get worksUntested => _t('Não testado', 'Untested');
  String get worksBug => _t('Com bugs', 'Bugs');
  String get worksPartial => _t('Parcial', 'Partial');
  String get relatedTitle => _t('Você também pode gostar', 'You may also like');
  String get reviewHint => _t(
    'Conte como o port roda (opcional)',
    'Tell us how the port runs (optional)',
  );
  String get send => _t('Enviar', 'Send');
  String get reviewSent => _t('Avaliação publicada', 'Review published');
  String get newGame => _t('Novo', 'New');

  // ------------------------------------------------------------ downloads
  String get downloadEmpty => _t('Nada na fila', 'Queue is empty');
  String get downloadEmptyBody => _t(
    'Abra um jogo e toque em Instalar para começar.',
    'Open a game and tap Install to start.',
  );
  String get pause => _t('Pausar', 'Pause');
  String get resume => _t('Retomar', 'Resume');
  String get cancel => _t('Cancelar', 'Cancel');
  String get remove => _t('Remover', 'Remove');
  String get clearCompleted => _t('Limpar concluídos', 'Clear completed');
  String get downloadDone => _t('Download concluído', 'Download complete');
  String get downloadStarted => _t('Download iniciado', 'Download started');
  String get viewDownloads => _t('Ver downloads', 'View downloads');
  String get statusQueued => _t('Na fila', 'Queued');
  String get statusConnecting => _t('Conectando', 'Connecting');
  String get statusVerifying => _t('Verificando', 'Verifying');
  String get statusPaused => _t('Pausado', 'Paused');
  String get statusDone => _t('Concluído', 'Done');
  String get statusFailed => _t('Falhou', 'Failed');

  // Filtros da fila de downloads (Hub).
  String get filterAll => _t('Todos', 'All');
  String get filterActive => _t('Ativos', 'Active');
  String get filterDone => _t('Concluídos', 'Done');
  String get filterFailed => _t('Falhos', 'Failed');
  String get filterEmptyTitle =>
      _t('Nada neste filtro', 'Nothing in this filter');
  String get filterEmptyBody => _t(
    'Ajuste os filtros para ver outros downloads.',
    'Adjust the filters to see other downloads.',
  );
  String get downloadRemoved => _t('Download removido', 'Download removed');
  String get undo => _t('Desfazer', 'Undo');

  /// Rótulo composto "Seção · N" com o separador no dicionário de i18n.
  String segmentCount(String label, int count) =>
      isEn ? '$label · $count' : '$label · $count';

  // Mensagens humanas para os códigos estáveis do motor (ver engine::error).
  String get dlErrNetwork => _t(
    'A conexão caiu. Toque em retomar para continuar de onde parou.',
    'Connection lost. Tap resume to continue where it stopped.',
  );
  String get dlErrHttp => _t(
    'O servidor recusou o download agora. Tente novamente mais tarde.',
    'The server refused the download. Try again later.',
  );
  String get dlErrDiskFull => _t(
    'Espaço insuficiente no celular. Libere espaço e toque em retomar.',
    'Not enough storage. Free up space and tap resume.',
  );
  String get dlErrNotApk => _t(
    'O link não apontava para um arquivo válido. Tente abrir a fonte.',
    "The link did not point to a valid file. Try opening the source.",
  );
  String get dlErrTruncated => _t(
    'O download foi interrompido no meio. Toque em retomar.',
    'The download was cut off. Tap resume.',
  );
  String get dlErrIo => _t(
    'Erro de leitura ou escrita no armazenamento.',
    'Storage read or write error.',
  );
  String get dlErrCancelled => _t('Download cancelado.', 'Download cancelled.');
  String get dlErrGeneric => _t(
    'Não foi possível baixar agora. Tente novamente.',
    'Could not download now. Try again.',
  );

  /// ETA no formato relógio: “restam 3:14” / “3:14 left”.
  String timeLeft(String clock) => clock.isEmpty
      ? ''
      : isEn
      ? '$clock left'
      : 'restam $clock';

  /// Traduz a mensagem do motor (`"<code>|<detalhe>"`) para texto humano.
  /// Códigos desconhecidos caem no texto genérico — nunca mostramos o cru.
  String downloadErrorLabel(String? raw) {
    if (raw == null || raw.isEmpty) {
      return dlErrGeneric;
    }
    final int sep = raw.indexOf('|');
    final String code = sep > 0 ? raw.substring(0, sep) : raw;
    switch (code) {
      case 'network':
      case 'truncated':
        if (code == 'network') {
          return dlErrNetwork;
        }
        return dlErrTruncated;
      case 'http_status':
        return dlErrHttp;
      case 'disk_full':
        return dlErrDiskFull;
      case 'not_apk':
        return dlErrNotApk;
      case 'io':
        return dlErrIo;
      case 'cancelled':
        return dlErrCancelled;
      case 'invalid_url':
      case 'invalid_destination':
      case 'file_changed':
      case 'range_not_satisfiable':
      case 'internal':
      default:
        return dlErrGeneric;
    }
  }

  // ------------------------------------------------------------- biblioteca
  String get addedToLibrary =>
      _t('Adicionado à biblioteca', 'Added to library');
  String get removedFromLibrary =>
      _t('Removido da biblioteca', 'Removed from library');
  String get ratingRequired =>
      _t('Escolha uma nota de 1 a 5', 'Pick a rating from 1 to 5');
  String get freeBadge => _t('Grátis', 'Free');
  String get libraryEmpty =>
      _t('Sua biblioteca está vazia', 'Your library is empty');
  String get libraryEmptyBody => _t(
    'Adicione jogos pela página de detalhes ou instale um port.',
    'Add games from detail pages or install a port.',
  );
  String get explore => _t('Explorar catálogo', 'Explore catalog');
  String get wishlistEmpty => _t('Nenhum favorito ainda', 'No favorites yet');
  String get wishlistEmptyBody => _t(
    'Toque no coração de um jogo para guardar aqui.',
    "Tap a game's heart to save it here.",
  );

  // ---------------------------------------------------------------- perfil
  String get player => _t('Jogador', 'Player');
  String get anonymousHint => _t(
    'Favoritos e biblioteca ficam ligados a este dispositivo.',
    'Favorites and library are tied to this device.',
  );
  String get language => _t('Idioma', 'Language');
  String get languagePtBr => 'Português (BR)';
  String get languageEn => 'English';
  String get notifications => _t('Notificações', 'Notifications');
  String get notificationsHint =>
      _t('Avisos de novos ports dentro do app', 'In-app alerts for new ports');

  // ----------------------------------------------- configurações (categorias)
  String get settingsTitle => _t('Configurações', 'Settings');
  String get settingsSubtitle =>
      _t('Ajuste o PORTIX do seu jeito', 'Tune PORTIX your way');
  String get settingsSearchHint =>
      _t('Buscar configurações', 'Search settings');
  String get settingsSearchEmpty =>
      _t('Nenhuma configuração encontrada', 'No settings found');
  String get settingsSearchClear => _t('Limpar busca', 'Clear search');
  String get settingsSelectHint => _t(
    'Selecione uma categoria para ver as opções',
    'Pick a category to see its options',
  );
  String get settingsCatAccount => _t('Conta e Perfil', 'Account & profile');
  String get settingsCatAccountDesc =>
      _t('Login, foto, nome e sair da conta', 'Sign in, photo, name, sign out');
  String get settingsCatAppearance =>
      _t('Aparência e Temas', 'Appearance & themes');
  String get settingsCatAppearanceDesc =>
      _t('Temas claros, escuros e coloridos', 'Light, dark and colorful');
  String get settingsReloading =>
      _t('Recarregando catálogo…', 'Reloading catalog…');
  String get settingsCatNotifications => _t('Notificações', 'Notifications');
  String get settingsCatNotificationsDesc =>
      _t('Avisos de novos ports', 'New port alerts');
  String get settingsCatLanguage => _t('Idioma e Região', 'Language & region');
  String get settingsCatLanguageDesc =>
      _t('Português (BR) ou English', 'Portuguese (BR) or English');
  String get settingsCatData => _t('Dados e Armazenamento', 'Data & storage');
  String get settingsCatDataDesc =>
      _t('Catálogo e cache local', 'Catalog and local cache');
  String get settingsCatNetwork => _t('Rede e Malha', 'Network & mesh');
  String get settingsCatNetworkDesc => _t(
    'Dispositivos conectados e relays',
    'Connected devices and relays',
  );
  String get settingsCatAbout => _t('Ajuda e Sobre', 'Help & about');
  String get settingsCatAboutDesc =>
      _t('Versão, legal e créditos', 'Version, legal and credits');
  String get settingsClearCacheConfirm => _t(
    'O cache local (dados do catálogo, perfil e imagens) será apagado e baixado de novo quando necessário.',
    'The local cache (catalog data, profile and images) will be cleared and re-downloaded when needed.',
  );

  /// Valor atual do alvo de FPS: "30 FPS".
  String fpsValue(Object value) => _t('$value FPS', '$value FPS');

  /// Contador de downloads de um jogo: "12,3 mil baixados".
  String downloadsCount(Object count) =>
      _t('$count baixados', '$count downloads');

  /// Badge de versão: "v1.2.3".
  String versionBadge(Object version) => _t('v$version', 'v$version');
  String get profileEmailLabel => _t('E-mail', 'Email');

  // ----------------------------------------------------------------- temas
  String get theme => _t('Tema', 'Theme');
  String get themeHint => _t(
    'Aparência do app, aplicada na hora',
    'App appearance, applied instantly',
  );
  String get themeSystem => _t('Sistema', 'System');
  String get themeSystemHint =>
      _t('Segue o claro/escuro do aparelho', 'Follows your device light/dark');
  String get themeLight => _t('Claro', 'Light');
  String get themeDark => _t('Escuro', 'Dark');
  String get themeMidnight => 'Midnight';
  String get themeMidnightHint =>
      _t('AMOLED: preto puro', 'AMOLED: pure black');
  String get themeOcean => _t('Oceano', 'Ocean');
  String get themeForest => _t('Floresta', 'Forest');
  String get themeVice => _t('Vice', 'Vice');
  String get themeViceHint => _t('Inspirado no GTA VI', 'GTA VI inspired');
  String get themeCitrus => _t('Cítrico', 'Citrus');
  String get themeGold => _t('Dourado', 'Gold');
  String get themeSelected => _t('Selecionado', 'Selected');
  String get themePreviewLabel => _t('Prévia do tema', 'Theme preview');
  String themeOptionSemantic(String name) =>
      _t('Selecionar o tema $name', 'Select the $name theme');
  String get about => _t('Sobre o PORTIX', 'About PORTIX');
  String get activity => _t('Atividade', 'Activity');
  String get dataSource => _t(
    'Catálogo público de ports (fe2rr) com capas do LaunchBox Games Database. Todos os créditos aos projetos originais.',
    'Public port catalog (fe2rr) with covers from LaunchBox Games Database. All credits to the original projects.',
  );
  String get dataSection => _t('Dados', 'Data');
  String get legalSection => _t('Legal', 'Legal');
  String get termsOfUse => _t('Termos de uso', 'Terms of use');
  String get privacyPolicy => _t('Política de privacidade', 'Privacy policy');
  String get reloadCatalog => _t('Recarregar catálogo', 'Reload catalog');
  String get catalogReloaded => _t('Catálogo atualizado', 'Catalog refreshed');
  String get catalogReloadFailed =>
      _t('Não foi possível atualizar agora', 'Could not refresh right now');
  String get clearCache => _t('Limpar cache local', 'Clear local cache');
  String get cacheCleared => _t('Cache limpo', 'Cache cleared');
  String get madeWith =>
      _t('Feito com Flutter · dados abertos', 'Built with Flutter · open data');

  // ------------------------------------------------------------- estados
  String get errorGeneric => _t('Algo deu errado.', 'Something went wrong.');
  String get errorNetwork => _t(
    'Sem conexão com o catálogo. Verifique sua internet.',
    'No connection to the catalog. Check your internet.',
  );
  String get errorServer => _t(
    'O catálogo não respondeu como esperado.',
    'The catalog did not respond as expected.',
  );
  String get errorAuth => _t(
    'Não foi possível criar sua sessão anônima.',
    'Could not create your anonymous session.',
  );
  String get errorNotFound => _t('Jogo não encontrado.', 'Game not found.');
  String get tryAgain => _t('Tentar de novo', 'Try again');
  String get configTitle => _t('Configuração ausente', 'Missing configuration');
  String get configBody => _t(
    'Sem catálogo local disponível. Reinstale o app para restaurar os dados embutidos.',
    'No local catalog available. Reinstall the app to restore the bundled data.',
  );
  String get close => _t('Fechar', 'Close');
  String get loading => _t('Carregando', 'Loading');

  // -------------------------------------------------------------- navegação+
  String get navExplore => _t('Explorar', 'Explore');
  String get navNews => _t('Notícias', 'News');
  String get navHub => _t('Meu Hub', 'My Hub');
  String get navMenu => _t('Menu', 'Menu');

  // ------------------------------------------------------------------ home+
  String get homeIntroTitle =>
      _t('Seu próximo jogo começa aqui.', 'Your next game starts here.');
  String get homeIntroBody => _t(
    'Um catálogo aberto de ports para Android, curado por popularidade e avaliado pela comunidade. Explore, favorite e acompanhe suas instalações.',
    'An open catalog of Android ports, curated by popularity and rated by the community. Explore, favorite and track your installs.',
  );
  String get sectionExploreBy => _t('Explorar por seção', 'Explore by section');
  String get sectionNews => _t('Novidades', 'What\'s new');
  String get sectionTopRated => _t('Mais bem avaliados', 'Top rated');
  String get sectionPopular => _t('Mais populares', 'Most popular');

  // ------------------------------------------------- feed algorítmico (Início)
  String get sectionFeatured => _t('Destaques', 'Featured');
  String get sectionForYou => _t('Para você', 'For you');
  String get sectionTrending => _t('Em alta', 'Trending');
  String get sectionNewReleases => _t('Novidades', 'New releases');
  String get sectionRecentlyUpdated =>
      _t('Atualizados recentemente', 'Recently updated');
  String get sectionDiscover => _t('Descubra', 'Discover');
  String get sectionByCategory => _t('Por categoria', 'By category');

  /// Microcopy personalizada da seção "Para você".
  String sectionForYouReason(String genre) =>
      _t('Porque você curte $genre', 'Because you like $genre');

  String get badgeNew => _t('NOVO', 'NEW');
  String get badgeUpdated => _t('ATUALIZADO', 'UPDATED');

  // Estados do feed (vazio / offline / limite).
  String get feedEmptyTitle => _t('Nada por aqui ainda', 'Nothing here yet');
  String get feedEmptyBody =>
      _t('Puxe para baixo para tentar de novo.', 'Pull down to try again.');
  String get feedOfflineTitle => _t('Sem conexão', 'No connection');
  String get feedRateLimitTitle =>
      _t('Muitas requisições', 'Too many requests');
  String get feedRateLimitBody => _t(
    'O catálogo está ocupado agora. Tente novamente em instantes.',
    'The catalog is busy right now. Try again in a moment.',
  );
  String get errorRateLimited => _t(
    'O catálogo está temporariamente sobrecarregado.',
    'The catalog is temporarily overloaded.',
  );

  // --------------------------------------------------------------- explore+
  String get exploreTitle => _t('Explorar', 'Explore');
  String get exploreSubtitle => _t(
    'Busque ports e navegue por categorias.',
    'Search ports and browse by category.',
  );
  String get searchFieldHint => _t(
    'Buscar jogos, categorias ou desenvolvedores',
    'Search games, categories or developers',
  );
  String get suggestionsLabel => _t('Sugestões', 'Suggestions');
  String get suggestGames => _t('Jogos', 'Games');
  String get suggestGenres => _t('Categorias', 'Categories');
  String get suggestDevelopers => _t('Desenvolvedores', 'Developers');
  String get suggestPlatforms => _t('Plataformas', 'Platforms');
  String get noSuggestions => _t(
    'Sem sugestões para esse texto. Toque em buscar para ver os resultados.',
    'No suggestions for this text. Tap search to see the results.',
  );
  String get didYouMean => _t('Você quis dizer…?', 'Did you mean…?');
  String get clearFilters => _t('Limpar filtros', 'Clear filters');
  String get gridLabel => _t('Grade', 'Grid');
  String get listLabel => _t('Lista', 'List');
  String get categoriesTitle => _t('Categorias', 'Categories');
  String get categoriesSubtitle =>
      _t('Navegue por gênero do catálogo', 'Browse the catalog by genre');
  String get trendingSearches => _t('Em alta nas buscas', 'Trending searches');
  String get removeSearch => _t('Remover da lista', 'Remove from list');
  String get sortRelevance => _t('Relevância', 'Relevance');
  String get sortRating => _t('Melhor avaliados', 'Top rated');
  String get sortDownloads => _t('Mais baixados', 'Most downloaded');
  String get filterMinRating => _t('Avaliação mínima', 'Minimum rating');
  String get staleNotice => _t(
    'Mostrando dados salvos — podem estar desatualizados.',
    'Showing saved data — it may be out of date.',
  );
  String get emptySearchTitle => _t('Nada encontrado', 'Nothing found');
  String get emptySearchBody => _t(
    'Não achamos nada para essa busca. Tente outro termo, limpe os filtros ou navegue pelas categorias.',
    'We found nothing for that search. Try another term, clear the filters or browse the categories.',
  );
  String get searchOfflineTitle =>
      _t('Busca indisponível offline', 'Search unavailable offline');
  String get searchOfflineBody => _t(
    'Sem conexão com o catálogo agora. Suas buscas recentes continuam disponíveis.',
    'No connection to the catalog right now. Your recent searches stay available.',
  );
  String get exploreDiscoverTitle => _t('Descubra', 'Discover');
  String get seeCategory => _t('Ver categoria', 'View category');
  String get searchTitle => _t('Buscar', 'Search');
  String get clearSearch => _t('Limpar busca', 'Clear search');
  String get genreEmptyTitle =>
      _t('Nenhum jogo nesta categoria ainda', 'No games in this category yet');
  String get genreEmptyBody => _t(
    'O catálogo está sempre crescendo — volte mais tarde para novidades.',
    'The catalog keeps growing — check back later for new additions.',
  );
  String get loadingSuggestions =>
      _t('Buscando sugestões…', 'Fetching suggestions…');
  String get resultsAnnounce =>
      _t('resultados disponíveis', 'results available');

  /// Anúncio do live region: "128 resultados disponíveis".
  String resultsLiveRegion(int n) => _t(
    '$n ${n == 1 ? 'resultado' : 'resultados'} $resultsAnnounce',
    '$n ${n == 1 ? 'result' : 'results'} $resultsAnnounce',
  );

  /// Contador de filtros aplicados no botão: "Filtros (2)".
  String filtersBadge(int n) => _t('Filtros ($n)', 'Filters ($n)');

  String get suggestionSelected => _t('Sugestão', 'Suggestion');

  // ---------------------------------------------------------------- notícias
  String get newsTitle => _t('Notícias', 'News');
  String get newsSubtitle => _t(
    'Ports, lançamentos e novidades para Android.',
    'Android ports, releases and news.',
  );
  String get newsEmpty => _t('Sem notícias por enquanto', 'No news yet');
  String get newsEmptyBody => _t(
    'Assim que houver uma novidade, ela aparece aqui.',
    'As soon as there is news, it shows up here.',
  );
  String get readOnSource => _t('Ler na fonte', 'Read at source');
  String get viewProject => _t('Ver projeto', 'View project');
  String get keyPointsTitle => _t('Principais pontos', 'Key points');
  String get byAuthor => _t('Por', 'By');

  // ------------------------------------------------------------------- hub
  String get hubTitle => _t('Meu Hub', 'My Hub');
  String get hubFavorites => _t('Favoritos', 'Favorites');
  String get hubInstalled => _t('Instalados', 'Installed');
  String get hubDownloads => _t('Downloads', 'Downloads');

  // ------------------------------------------------------------------ menu
  String get menuTitle => _t('Menu', 'Menu');
  String get account => _t('Conta', 'Account');
  String get appearanceSection => _t('Preferências', 'Preferences');

  // -------------------------------------------------------------- detalhes+
  String get installedAction =>
      _t('Marcar como instalado', 'Mark as installed');
  String get infoTitle => _t('Informações', 'Information');
  String get descriptionTitle => _t('Descrição', 'Description');
  String get compatTitle =>
      _t('Roda no seu celular?', 'Does it run on your phone?');
  String get compatSubtitle => _t(
    'Relatos da comunidade, aparelho por aparelho.',
    'Community reports, device by device.',
  );
  String get compatReport => _t('Relatar', 'Report');
  String compatReports(int n) => _t(
    '$n ${n == 1 ? 'relato' : 'relatos'}',
    '$n ${n == 1 ? 'report' : 'reports'}',
  );
  String get downloadsLabel => _t('baixados', 'downloads');
  String get sourceOnly => _t(
    'Este port não tem um APK direto. Abrindo a fonte para você baixar.',
    'This port has no direct APK. Opening the source so you can download it.',
  );

  // --------------------------------------------------------- contas / perfil
  String get authTitle => _t('Entrar no PORTIX', 'Sign in to PORTIX');
  String get authSubtitle => _t(
    'Crie uma conta para avaliar jogos e montar seu perfil.',
    'Create an account to rate games and build your profile.',
  );
  String get signIn => _t('Entrar', 'Sign in');
  String get signUp => _t('Criar conta', 'Create account');
  String get signOut => _t('Sair', 'Sign out');
  String get email => _t('E-mail', 'Email');
  String get password => _t('Senha', 'Password');
  String get yourName => _t('Seu nome', 'Your name');
  String get continueWithGoogle =>
      _t('Continuar com Google', 'Continue with Google');
  String get loginRequired => _t('Entre para avaliar.', 'Sign in to rate.');
  String get editProfile => _t('Editar perfil', 'Edit profile');
  String get coverUrlLabel =>
      _t('URL da capa (opcional)', 'Cover URL (optional)');
  String get coverHint => _t('https://...', 'https://...');
  String get saveChanges => _t('Salvar', 'Save');
  String get profileSaved => _t('Perfil atualizado', 'Profile updated');
  String get guestLabel => _t('Convidado', 'Guest');
  String get accountSection => _t('Conta', 'Account');
  String get passwordShort =>
      _t('A senha precisa de 6+ caracteres', 'Password needs 6+ characters');
  String get emailRequired =>
      _t('Informe um e-mail válido', 'Enter a valid email');
  String get authCheckEmail => _t(
    'Confira seu e-mail para confirmar a conta.',
    'Check your email to confirm the account.',
  );
  String get googleUnavailable => _t(
    'Login com Google ainda não está configurado neste projeto.',
    'Google sign-in is not configured in this project yet.',
  );

  // ------------------------------------------------------------ compat v2
  String get compatPerfect => _t('Roda perfeito', 'Runs perfectly');
  String get compatGood => _t('Roda bem', 'Runs well');
  String get compatStutter => _t('Com travadas', 'Stutters');
  String get compatUnplayable => _t('Injogável', 'Unplayable');
  String get compatNotRun => _t('Não roda', 'Does not run');
  String get compatCommunity =>
      _t('Como roda por aparelho', 'How it runs by device');
  String get compatNoReports =>
      _t('Ainda sem relatos da comunidade.', 'No community reports yet.');
  String get compatYourDevice => _t('Seu aparelho', 'Your device');
  String get compatSameSoc => _t('Mesmo processador', 'Same chipset');
  String get feedbackTitle => _t('Avaliar e relatar', 'Rate and report');
  String get ratingLabel => _t('Sua nota', 'Your rating');
  String get verdictLabel => _t('Como roda', 'How it runs');

  // ---------------------------------------------------------- ficha técnica
  String get specsTitle => _t('Ficha técnica', 'Spec sheet');
  String get specsSearchTitle =>
      _t('Especificações do aparelho', 'Device specifications');
  String get specsSearchHint => _t(
    'Buscar aparelho (ex.: Poco X6 Pro)',
    'Search a device (e.g. Poco X6 Pro)',
  );
  String get specsSearchEmptyTitle => _t('Nada encontrado', 'Nothing found');
  String get specsSearchEmptyBody => _t(
    'Não achamos esse aparelho na base de fichas técnicas. Confira o nome ou tente outro termo.',
    'No spec sheet matches that device name. Check it or try another term.',
  );
  String get specsOpenAction => _t('Ver ficha técnica', 'View spec sheet');
  String get specsOverview => _t('Visão geral', 'Overview');
  String get specsGallery => _t('Imagens', 'Images');
  String get specsSourceNote =>
      _t('Dados da ficha técnica: GSMArena', 'Spec data: GSMArena');
  String get fpsOptional => _t('Informar FPS médio', 'Report average FPS');
  String get seeAllReports => _t('Ver todos', 'See all');
  String get reportsTitle => _t('Relatos da comunidade', 'Community reports');
  String get reportDetails => _t('Relato da comunidade', 'Community report');
  String get reportDevice => _t('Aparelho', 'Device');
  String get reportBodyLabel =>
      _t('O que o jogador relatou', 'What the player reported');
  String get reportsSearchHint => _t(
    'Buscar por aparelho, chipset ou autor',
    'Search by device, chipset or author',
  );
  String get searchTabGames => _t('Jogos', 'Games');
  String get searchTabUsers => _t('Usuários', 'Users');
  String get searchUsersHint =>
      _t('Buscar por @ ou nome', 'Search by @ or name');
  String get usersEmpty => _t('Nenhum usuário encontrado', 'No users found');
  String get userLibraryTitle => _t('Biblioteca', 'Library');
  String get userLibraryEmpty =>
      _t('Biblioteca pública vazia', 'Empty public library');
  String get noHandle => _t('Sem @', 'No handle');
  String get handleLabel => _t('Seu @ (nome de usuário)', 'Your @ (username)');
  String get handleHint => _t('hailgames', 'hailgames');
  String get handleInvalid =>
      _t('Use 3 a 20 letras, números ou _', 'Use 3-20 letters, numbers or _');
  String get handleTaken =>
      _t('Esse @ já está em uso', 'That @ is already taken');
  String get openProfile => _t('Ver perfil', 'View profile');
  String get admRootLabel => _t('ADM raiz', 'Root ADM');
  String get admAdminLabel => _t('Administrador', 'Admin');
  String get admModLabel => _t('Moderador', 'Moderator');
  String get updateAvailable =>
      _t('Atualização disponível', 'Update available');
  String get downloadStartFailed => _t(
    'Não foi possível iniciar o download.',
    'Could not start the download.',
  );
  String get updateNow => _t('Atualizar', 'Update now');
  String get later => _t('Depois', 'Later');
  String get chooseApk => _t('Escolha o APK', 'Choose the APK');
  String get searchingRelease =>
      _t('Buscando a release…', 'Looking up the release…');

  // ------------------------------------------------------- acessibilidade
  // Rótulos semânticos de controles só-ícone (TalkBack) — nunca deixe um
  // GlassCircleButton sem tooltip: o ícone é invisível para leitores de tela.
  String get tooltipBack => _t('Voltar', 'Back');
  String get tooltipSearch => _t('Buscar', 'Search');
  String get moreActions => _t('Mais ações', 'More actions');
  String get navExpand => _t('Expandir navegação', 'Expand navigation');
  String get navCollapse => _t('Recolher navegação', 'Collapse navigation');
  String navBadgeCount(int n) => _t('$n em andamento', '$n in progress');
  String get tooltipPrevious => _t('Anterior', 'Previous');
  String get tooltipNext => _t('Próximo', 'Next');
  String get tooltipPauseCarousel => _t('Pausar destaques', 'Pause highlights');
  String get tooltipPlayCarousel =>
      _t('Reproduzir destaques', 'Play highlights');
  String starSemantic(int n) => _t('$n de 5 estrelas', '$n out of 5 stars');
  String starPickerSummary(int value) =>
      _t('Avaliação: $value de 5 estrelas', 'Rating: $value out of 5 stars');

  // ------------------------------------------------- confirmação / feedback
  String get clearHistoryConfirm =>
      _t('Apagar todas as buscas recentes?', 'Delete all recent searches?');
  String get historyCleared => _t('Histórico limpo', 'History cleared');
  String get signOutConfirm =>
      _t('Sair da sua conta neste dispositivo?', 'Sign out on this device?');
  String get confirm => _t('Confirmar', 'Confirm');

  // -------------------------------------------------------- versões / GitHub
  String get versionsTitle => _t('Versões', 'Versions');
  String get versionsSubtitle =>
      _t('3 releases mais recentes', '3 latest releases');
  String get latestBadge => _t('Mais recente', 'Latest');
  String get betaBadge => _t('Beta', 'Beta');
  String get installedBadge => _t('Instalada', 'Installed');
  String get otherVersions => _t('Outras versões', 'Other versions');
  String chooseVersionTitle(String tag) => _t('Versão $tag', 'Version $tag');
  String get versionSheetHint => _t(
    'Selecione a versão que você quer baixar.',
    'Pick the version you want to download.',
  );
  String downloadVersion(String tag) => _t('Baixar v$tag', 'Download v$tag');
  String get noReleases =>
      _t('Sem versões publicadas', 'No published releases');
  String get noReleasesBody => _t(
    'Este projeto ainda não publicou releases com APK.',
    'This project has not published any releases with APKs yet.',
  );
  String get noCompatibleApk => _t('Sem APK compatível', 'No compatible APK');
  String get noCompatibleApkBody => _t(
    'Nenhum arquivo .apk nesta release. Abra a fonte para pegar o build.',
    'No .apk file attached to this release. Open the source to grab the build.',
  );
  String get oldVersionTitle => _t('Versão mais antiga', 'Older version');
  String oldVersionBody(String installed) => _t(
    'A v$installed já está instalada no seu aparelho. Você pode manter a atual ou baixar esta versão mesmo assim.',
    'v$installed is already installed on your device. You can keep it or still download this version.',
  );
  String get downloadAnyway => _t('Baixar assim mesmo', 'Download anyway');
  String get whatsNewTitle =>
      _t('Novidades desta versão', "What's new in this version");
  String get releasesEmptyNotes => _t(
    'Esta release não tem notas publicadas.',
    'This release has no release notes.',
  );
  String get developerSection => _t('Desenvolvedor', 'Developer');
  String get viewGithubProfile =>
      _t('Ver perfil no GitHub', 'View GitHub profile');
  String get organizationLabel => _t('Organização', 'Organization');
  String get userLabel => _t('Usuário', 'User');
  String get repositoriesLabel => _t('repositórios', 'repos');
  String get followersLabel => _t('seguidores', 'followers');
  String get developerFallback => _t(
    'Não foi possível carregar o perfil no GitHub agora.',
    'Could not load the GitHub profile right now.',
  );
  String get rateLimitTitle =>
      _t('Limite do GitHub atingido', 'GitHub rate limit reached');
  String get rateLimitBody => _t(
    'O acesso público ao GitHub está temporariamente esgotado. Tentaremos novamente em alguns minutos.',
    'Public GitHub access is temporarily exhausted. We will retry in a few minutes.',
  );
  String get githubOfflineBody => _t(
    'Sem conexão com o GitHub agora. Os dados salvos continuam visíveis.',
    'No connection to GitHub right now. Saved data stays visible.',
  );
  String get repoNotFoundTitle =>
      _t('Repositório indisponível', 'Repository unavailable');
  String get repoNotFoundBody => _t(
    'O repositório do port ficou privado, foi movido ou removido do GitHub.',
    'The port repository became private, moved or was removed from GitHub.',
  );
  String get statsVersion => _t('Versão', 'Version');
  String get statsSize => _t('Tamanho', 'Size');
  String get statsDownloads => _t('Downloads', 'Downloads');
  String get statsRating => _t('Avaliação', 'Rating');
  String get statsRatingEmpty => _t('Sem notas', 'No ratings');
  // -------------------------------------------------------------- contagens
  String gameCount(int n) =>
      _t('$n ${n == 1 ? 'jogo' : 'jogos'}', '$n ${n == 1 ? 'game' : 'games'}');
  String portCount(int n) =>
      _t('$n ${n == 1 ? 'port' : 'ports'}', '$n ${n == 1 ? 'port' : 'ports'}');
  String platformCount(int n) => _t(
    '$n ${n == 1 ? 'plataforma' : 'plataformas'}',
    '$n ${n == 1 ? 'platform' : 'platforms'}',
  );
  String resultsCount(int n) => _t(
    '$n ${n == 1 ? 'resultado' : 'resultados'}',
    '$n ${n == 1 ? 'result' : 'results'}',
  );
  String progressPercent(int value) => '$value%';

  // ------------------------------------------------------------ malha (P2P)
  String get meshSection => _t('Malha P2P', 'P2P mesh');
  String get meshStatusTitle =>
      _t('Dispositivos conectados', 'Connected devices');
  String get meshStatusBody => _t(
    'Sem servidor central: os aparelhos se encontram direto. Este número conta quem está online agora.',
    'No central server: devices find each other directly. This number counts who is online right now.',
  );
  String meshDevicesOnline(int n) => _t(
    '$n ${n == 1 ? 'dispositivo conectado' : 'dispositivos conectados'}',
    '$n ${n == 1 ? 'device connected' : 'devices connected'}',
  );
  String meshCountShort(int n) => _t('$n', '$n');
  String get meshOnlyYou => _t('Só você agora', 'Only you right now');
  String get meshRelaysTitle =>
      _t('Servidores da malha (relays)', 'Mesh servers (relays)');
  String get meshRelaysBody => _t(
    'Qualquer pessoa pode hospedar um relay. Cole a URL do seu (Railway, VPS...).',
    'Anyone can host a relay. Paste your URL (Railway, VPS...).',
  );
  String get meshRelayHint => _t(
    'https://seu-relay.up.railway.app',
    'https://your-relay.up.railway.app',
  );
  String get meshRelayAdd => _t('Adicionar', 'Add');
  String get meshRelayInvalid => _t('Endereço inválido.', 'Invalid address.');
  String get meshRelayAdded => _t('Relay adicionado', 'Relay added');
  String get meshRelayRemoved => _t('Relay removido', 'Relay removed');
  String get meshRelaysEmpty => _t(
    'Nenhum relay. Por enquanto, só descoberta na rede local.',
    'No relay. For now, local network discovery only.',
  );
  String get meshLanBadge => _t('rede local', 'local network');
  String get meshEnabledLabel => _t('Malha ligada', 'Mesh on');
  String get meshDisabledLabel => _t('Malha desligada', 'Mesh off');
  String get meshYourId => _t('Seu ID de dispositivo', 'Your device ID');
  String get meshIdentityTitle =>
      _t('Crie sua identidade', 'Create your identity');
  String get meshIdentitySubtitle => _t(
    'Um nome e um @ para os outros dispositivos te verem na malha. Nada é enviado a um servidor.',
    'A name and a @ so other devices can see you on the mesh. Nothing is sent to a server.',
  );
  String get meshHandleHint => _t('@ (opcional)', '@ (optional)');
  String get meshCreateIdentity => _t('Criar identidade', 'Create identity');
  String get meshNameRequired => _t('Informe um nome.', 'Enter a name.');
}

extension L10nContext on BuildContext {
  L10n get l10n => L10n(Localizations.localeOf(this));
}
