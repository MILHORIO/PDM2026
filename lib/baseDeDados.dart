import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class BaseDeDados {
  static final BaseDeDados _instance = BaseDeDados._internal();
  factory BaseDeDados() => _instance;
  BaseDeDados._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'expenso.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Utilizadores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        logotipo TEXT,
        utilizador_id INTEGER,
        FOREIGN KEY (utilizador_id) REFERENCES Utilizadores (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Despesas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        valor REAL NOT NULL,
        data TEXT NOT NULL,
        descricao TEXT,
        categoria_id INTEGER,
        utilizador_id INTEGER,
        FOREIGN KEY (categoria_id) REFERENCES Categorias (id) ON DELETE SET NULL,
        FOREIGN KEY (utilizador_id) REFERENCES Utilizadores (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Receitas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        valor REAL NOT NULL,
        data TEXT NOT NULL,
        descricao TEXT,
        utilizador_id INTEGER,
        FOREIGN KEY (utilizador_id) REFERENCES Utilizadores (id) ON DELETE CASCADE
      )
    ''');
  }

  // --- Operações de Utilizador ---

  Future<int> inserirUtilizador(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('Utilizadores', row);
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'Utilizadores',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  // --- Operações de Categorias ---

  Future<int> inserirCategoria(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('Categorias', row);
  }

  Future<List<Map<String, dynamic>>> getCategorias(int utilizadorId) async {
    Database db = await database;
    return await db.query('Categorias', where: 'utilizador_id = ?', whereArgs: [utilizadorId]);
  }

  Future<int> atualizarCategoria(Map<String, dynamic> row) async {
    Database db = await database;
    int id = row['id'];
    return await db.update('Categorias', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> eliminarCategoria(int id) async {
    Database db = await database;
    return await db.delete('Categorias', where: 'id = ?', whereArgs: [id]);
  }

  // --- Operações de Despesas ---

  Future<int> inserirDespesa(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('Despesas', row);
  }

  Future<List<Map<String, dynamic>>> getDespesas(int utilizadorId) async {
    Database db = await database;
    return await db.query('Despesas', where: 'utilizador_id = ?', whereArgs: [utilizadorId]);
  }

  Future<int> atualizarDespesa(Map<String, dynamic> row) async {
    Database db = await database;
    int id = row['id'];
    return await db.update('Despesas', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> eliminarDespesa(int id) async {
    Database db = await database;
    return await db.delete('Despesas', where: 'id = ?', whereArgs: [id]);
  }

  // --- Operações de Receitas ---

  Future<int> inserirReceita(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('Receitas', row);
  }

  Future<List<Map<String, dynamic>>> getReceitas(int utilizadorId) async {
    Database db = await database;
    return await db.query('Receitas', where: 'utilizador_id = ?', whereArgs: [utilizadorId]);
  }

  Future<int> atualizarReceita(Map<String, dynamic> row) async {
    Database db = await database;
    int id = row['id'];
    return await db.update('Receitas', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> eliminarReceita(int id) async {
    Database db = await database;
    return await db.delete('Receitas', where: 'id = ?', whereArgs: [id]);
  }

  // --- Limpeza de Dados ---

  Future<void> limparDadosUtilizador(int utilizadorId) async {
    Database db = await database;
    await db.delete('Despesas', where: 'utilizador_id = ?', whereArgs: [utilizadorId]);
    await db.delete('Receitas', where: 'utilizador_id = ?', whereArgs: [utilizadorId]);
  }

  Future<void> eliminarBaseDeDadosCompleta() async {
    String path = join(await getDatabasesPath(), 'expenso.db');
    await deleteDatabase(path);
    _database = null;
  }

  Future<void> inicializarCategoriasPadrao(int utilizadorId) async {
    Database db = await database;
    
    List<Map<String, dynamic>> padrao = [
      {'nome': 'Alimentação', 'icon': 'restaurant'},
      {'nome': 'Supermercado', 'icon': 'shopping_cart'},
      {'nome': 'Transporte', 'icon': 'directions_bus'},
      {'nome': 'Combustível', 'icon': 'local_gas_station'},
      {'nome': 'Casa', 'icon': 'home'},
      {'nome': 'Contas', 'icon': 'receipt_long'},
      {'nome': 'Lazer', 'icon': 'movie'},
      {'nome': 'Saúde', 'icon': 'medical_services'},
      {'nome': 'Educação', 'icon': 'school'},
      {'nome': 'Compras', 'icon': 'shopping_bag'},
      {'nome': 'Viagens', 'icon': 'flight'},
    ];

    for (var item in padrao) {
      List<Map<String, dynamic>> existe = await db.query(
        'Categorias', 
        where: 'nome = ? AND utilizador_id = ?', 
        whereArgs: [item['nome'], utilizadorId]
      );

      if (existe.isEmpty) {
        await inserirCategoria({
          'nome': item['nome'],
          'logotipo': item['icon'],
          'utilizador_id': utilizadorId,
        });
      } else {
        await db.update(
          'Categorias', 
          {'logotipo': item['icon']}, 
          where: 'id = ?', 
          whereArgs: [existe.first['id']]
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> getDespesasPorCategoria(int utilizadorId, int mes, int ano) async {
    Database db = await database;
    String mesStr = mes.toString().padLeft(2, '0');
    String anoStr = ano.toString();

    return await db.rawQuery('''
      SELECT c.nome, SUM(d.valor) as total, c.logotipo 
      FROM Despesas d
      JOIN Categorias c ON d.categoria_id = c.id
      WHERE d.utilizador_id = ? 
      AND strftime('%m', d.data) = ? 
      AND strftime('%Y', d.data) = ?
      GROUP BY c.id
    ''', [utilizadorId, mesStr, anoStr]);
  }

  Future<List<Map<String, dynamic>>> getTodasTransacoesPorMes(int utilizadorId, int mes, int ano) async {
    Database db = await database;
    String mesStr = mes.toString().padLeft(2, '0');
    String anoStr = ano.toString();

    return await db.rawQuery('''
      SELECT 'Despesa' as tipo, d.id, d.valor, d.data, d.descricao, c.nome as categoria
      FROM Despesas d
      LEFT JOIN Categorias c ON d.categoria_id = c.id
      WHERE d.utilizador_id = ? AND strftime('%m', d.data) = ? AND strftime('%Y', d.data) = ?
      UNION ALL
      SELECT 'Depósito' as tipo, r.id, r.valor, r.data, r.descricao, 'N/A' as categoria
      FROM Receitas r
      WHERE r.utilizador_id = ? AND strftime('%m', r.data) = ? AND strftime('%Y', r.data) = ?
      ORDER BY data DESC
    ''', [utilizadorId, mesStr, anoStr, utilizadorId, mesStr, anoStr]);
  }

  // --- Balanço ---

  Future<double> getBalancoMensal(int utilizadorId, int mes, int ano) async {
    Database db = await database;
    String mesStr = mes.toString().padLeft(2, '0');
    String anoStr = ano.toString();

    var resReceitas = await db.rawQuery(
      'SELECT SUM(valor) as total FROM Receitas WHERE utilizador_id = ? AND strftime("%m", data) = ? AND strftime("%Y", data) = ?', 
      [utilizadorId, mesStr, anoStr]
    );
    var resDespesas = await db.rawQuery(
      'SELECT SUM(valor) as total FROM Despesas WHERE utilizador_id = ? AND strftime("%m", data) = ? AND strftime("%Y", data) = ?', 
      [utilizadorId, mesStr, anoStr]
    );

    double totalReceitas = (resReceitas.first['total'] as num?)?.toDouble() ?? 0.0;
    double totalDespesas = (resDespesas.first['total'] as num?)?.toDouble() ?? 0.0;

    return totalReceitas - totalDespesas;
  }

  Future<double> getBalancoGlobal(int utilizadorId) async {
    Database db = await database;
    
    var resReceitas = await db.rawQuery('SELECT SUM(valor) as total FROM Receitas WHERE utilizador_id = ?', [utilizadorId]);
    var resDespesas = await db.rawQuery('SELECT SUM(valor) as total FROM Despesas WHERE utilizador_id = ?', [utilizadorId]);

    double totalReceitas = (resReceitas.first['total'] as num?)?.toDouble() ?? 0.0;
    double totalDespesas = (resDespesas.first['total'] as num?)?.toDouble() ?? 0.0;

    return totalReceitas - totalDespesas;
  }
}
