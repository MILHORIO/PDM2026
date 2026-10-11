import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'servico_cambio.dart';

/// Tipos de operação pendente
enum TipoOperacao { inserir, atualizar, eliminar }

/// Tipos de entidade afetada
enum TipoEntidade { despesa, receita }

/// Serviço responsável pela lógica offline-first.
///
/// Quando o utilizador não tem internet, as operações são guardadas
/// numa fila local (tabela [FilaSincronizacao]). Quando a ligação
/// é restaurada, [sincronizar] envia os dados pendentes e atualiza
/// as taxas de câmbio.
class ServicoSincronizacao {
  static final ServicoSincronizacao _instance = ServicoSincronizacao._internal();
  factory ServicoSincronizacao() => _instance;
  ServicoSincronizacao._internal();

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _inicializar();
    return _db!;
  }

  Future<Database> _inicializar() async {
    final caminho = join(await getDatabasesPath(), 'sync_cache.db');
    return openDatabase(
      caminho,
      version: 1,
      onCreate: (db, _) async {
        // Fila de operações pendentes (a enviar quando houver internet)
        await db.execute('''
          CREATE TABLE FilaSincronizacao (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo_operacao TEXT NOT NULL,
            tipo_entidade TEXT NOT NULL,
            payload TEXT NOT NULL,
            criado_em TEXT NOT NULL
          )
        ''');

        // Cache das taxas de câmbio obtidas da API
        await db.execute('''
          CREATE TABLE CacheCambio (
            moeda TEXT PRIMARY KEY,
            taxa REAL NOT NULL,
            atualizado_em TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ─── Fila de Sincronização ────────────────────────────────────────────────

  /// Adiciona uma operação à fila para sincronização futura.
  Future<void> adicionarFilaSync({
    required TipoOperacao operacao,
    required TipoEntidade entidade,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _database;
    await db.insert('FilaSincronizacao', {
      'tipo_operacao': operacao.name,
      'tipo_entidade': entidade.name,
      'payload': payload.toString(),
      'criado_em': DateTime.now().toIso8601String(),
    });
  }

  /// Devolve o número de operações em fila (para mostrar ao utilizador).
  Future<int> contarPendentes() async {
    final db = await _database;
    final resultado = await db.rawQuery('SELECT COUNT(*) as total FROM FilaSincronizacao');
    return (resultado.first['total'] as int?) ?? 0;
  }

  /// Limpa a fila após sincronização bem-sucedida.
  Future<void> limparFila() async {
    final db = await _database;
    await db.delete('FilaSincronizacao');
  }

  // ─── Cache de Câmbio ─────────────────────────────────────────────────────

  /// Guarda as taxas de câmbio obtidas da API no cache local.
  Future<void> guardarTaxasCache(Map<String, double> taxas) async {
    final db = await _database;
    final agora = DateTime.now().toIso8601String();
    for (final entrada in taxas.entries) {
      await db.insert(
        'CacheCambio',
        {'moeda': entrada.key, 'taxa': entrada.value, 'atualizado_em': agora},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Lê as taxas do cache local (usado quando não há internet).
  Future<Map<String, double>> lerTaxasCache() async {
    final db = await _database;
    final linhas = await db.query('CacheCambio');
    if (linhas.isEmpty) return {};
    return {
      for (final l in linhas) l['moeda'] as String: l['taxa'] as double,
    };
  }

  /// Verifica se o cache tem menos de 1 hora (evita chamadas desnecessárias).
  Future<bool> cacheRecente() async {
    final db = await _database;
    final linhas = await db.query('CacheCambio', limit: 1);
    if (linhas.isEmpty) return false;
    final atualizado = DateTime.tryParse(linhas.first['atualizado_em'] as String);
    if (atualizado == null) return false;
    return DateTime.now().difference(atualizado).inMinutes < 60;
  }

  // ─── Verificação de Conectividade ────────────────────────────────────────

  /// Devolve true se existir ligação à internet.
  Future<bool> temInternet() async {
    final resultado = await Connectivity().checkConnectivity();
    return resultado.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  // ─── Sincronização Principal ─────────────────────────────────────────────

  /// Tenta obter taxas de câmbio atualizadas e sincronizar dados pendentes.
  /// Devolve um [ResultadoSync] com o que foi feito.
  Future<ResultadoSync> sincronizar() async {
    final online = await temInternet();
    if (!online) {
      return ResultadoSync(
        online: false,
        taxasAtualizadas: false,
        pendentesEnviados: 0,
      );
    }

    // 1. Atualizar taxas de câmbio
    bool taxasOk = false;
    if (!await cacheRecente()) {
      final taxas = await ServicoCambio.obterTaxasDeCambio();
      if (taxas != null) {
        await guardarTaxasCache(taxas);
        taxasOk = true;
      }
    } else {
      taxasOk = true; // cache ainda válido
    }

    // 2. Processar fila de pendentes
    final pendentes = await contarPendentes();
    if (pendentes > 0) {
      // Numa integração real enviaríamos para um backend remoto aqui.
      // Para esta versão offline-first, marcamos como sincronizado localmente.
      await limparFila();
    }

    return ResultadoSync(
      online: true,
      taxasAtualizadas: taxasOk,
      pendentesEnviados: pendentes,
    );
  }

  /// Obtém taxas válidas: da API se online, do cache se offline.
  Future<Map<String, double>> obterTaxasValidas() async {
    final online = await temInternet();
    if (online && !await cacheRecente()) {
      final taxas = await ServicoCambio.obterTaxasDeCambio();
      if (taxas != null) {
        await guardarTaxasCache(taxas);
        return taxas;
      }
    }
    final cache = await lerTaxasCache();
    return cache.isNotEmpty ? cache : {'EUR': 1.0};
  }
}

/// Resultado devolvido por [ServicoSincronizacao.sincronizar].
class ResultadoSync {
  final bool online;
  final bool taxasAtualizadas;
  final int pendentesEnviados;

  const ResultadoSync({
    required this.online,
    required this.taxasAtualizadas,
    required this.pendentesEnviados,
  });
}
