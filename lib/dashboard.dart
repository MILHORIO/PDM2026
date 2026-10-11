import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'baseDeDados.dart';
import 'servico_cambio.dart';
import 'servico_sincronizacao.dart';

void main() {
  runApp(const Dashboard());
}

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DashboardPage(title: ''),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.title});
  final String title;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final BaseDeDados _db = BaseDeDados();
  final ServicoSincronizacao _sync = ServicoSincronizacao();

  List<PieChartSectionData> _secoesGrafico = [];
  List<Map<String, dynamic>> _transacoes = [];
  double _balancoMensal = 0.0;
  double _balancoGlobal = 0.0;
  bool _carregando = true;
  int userId = 1;

  int mesSelecionado = DateTime.now().month;
  int anoSelecionado = DateTime.now().year;

  Map<String, double> _taxasCambio = {'EUR': 1.0};
  String _moedaSelecionada = 'EUR';
  bool _online = true;
  int _pendentesSync = 0;

  @override
  void initState() {
    super.initState();
    _iniciarComSync();
  }

  Future<void> _iniciarComSync() async {
    final resultado = await _sync.sincronizar();
    final taxas = await _sync.obterTaxasValidas();
    final pendentes = await _sync.contarPendentes();
    if (mounted) {
      setState(() {
        _online = resultado.online;
        _taxasCambio = taxas;
        _pendentesSync = pendentes;
      });
    }
    await _carregarDados();
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'restaurant':        return Icons.restaurant;
      case 'shopping_cart':     return Icons.shopping_cart;
      case 'directions_bus':    return Icons.directions_bus;
      case 'local_gas_station': return Icons.local_gas_station;
      case 'home':              return Icons.home;
      case 'receipt_long':      return Icons.receipt_long;
      case 'movie':             return Icons.movie;
      case 'medical_services':  return Icons.medical_services;
      case 'school':            return Icons.school;
      case 'shopping_bag':      return Icons.shopping_bag;
      case 'flight':            return Icons.flight;
      default:                  return Icons.category;
    }
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    await _db.inicializarCategoriasPadrao(userId);

    final dadosGrafico       = await _db.getDespesasPorCategoria(userId, mesSelecionado, anoSelecionado);
    final balancoMensalAtual = await _db.getBalancoMensal(userId, mesSelecionado, anoSelecionado);
    final balancoGlobalAtual = await _db.getBalancoGlobal(userId);
    final transacoesAtuais   = await _db.getTodasTransacoesPorMes(userId, mesSelecionado, anoSelecionado);

    double totalGeral = 0;
    for (var item in dadosGrafico) {
      totalGeral += (item['total'] as num).toDouble();
    }

    final List<Color> cores = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple,
      Colors.cyan, Colors.indigo, Colors.teal, Colors.pink, Colors.amber, Colors.deepOrange,
    ];

    setState(() {
      _balancoMensal = balancoMensalAtual;
      _balancoGlobal = balancoGlobalAtual;
      _transacoes    = transacoesAtuais;
      _secoesGrafico = List.generate(dadosGrafico.length, (i) {
        final valor       = (dadosGrafico[i]['total'] as num).toDouble();
        final percentagem = totalGeral > 0 ? (valor / totalGeral * 100).toStringAsFixed(1) : '0';
        final iconName    = dadosGrafico[i]['logotipo'];
        return PieChartSectionData(
          color: cores[i % cores.length],
          value: valor,
          title: '$percentagem%',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          badgeWidget: _Badge(
            _getIconData(iconName),
            size: 30,
            borderColor: cores[i % cores.length],
          ),
          badgePositionPercentageOffset: 0.98,
        );
      });
      _carregando = false;
    });
  }

  void _mudarMes(int delta) {
    final agora = DateTime.now();
    int novoMes = mesSelecionado + delta;
    int novoAno = anoSelecionado;

    if (novoMes > 12)     { novoMes = 1;  novoAno++; }
    else if (novoMes < 1) { novoMes = 12; novoAno--; }

    if (novoAno > agora.year || (novoAno == agora.year && novoMes > agora.month)) return;

    setState(() {
      mesSelecionado = novoMes;
      anoSelecionado = novoAno;
    });
    _carregarDados();
  }

  String getNomeMes() {
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];
    return '${meses[mesSelecionado - 1]} $anoSelecionado';
  }

  String formatarData(String isoData) {
    final data = DateTime.parse(isoData);
    final d = data.day.toString().padLeft(2, '0');
    final m = data.month.toString().padLeft(2, '0');
    final h = data.hour.toString().padLeft(2, '0');
    final min = data.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }

  String _formatarValor(double valorEur) {
    final convertido = ServicoCambio.converter(valorEur, _moedaSelecionada, _taxasCambio);
    return '${convertido.toStringAsFixed(2)} $_moedaSelecionada';
  }

  Future<void> _sincronizarManualmente() async {
    setState(() => _carregando = true);
    final resultado = await _sync.sincronizar();
    final taxas     = await _sync.obterTaxasValidas();
    final pendentes = await _sync.contarPendentes();
    setState(() {
      _online        = resultado.online;
      _taxasCambio   = taxas;
      _pendentesSync = pendentes;
    });
    await _carregarDados();
    if (!mounted) return;
    final mensagem = resultado.online
        ? (resultado.pendentesEnviados > 0
            ? '${resultado.pendentesEnviados} operacao(oes) sincronizada(s)!'
            : resultado.taxasAtualizadas
                ? 'Taxas de cambio atualizadas.'
                : 'Ja sincronizado.')
        : 'Sem internet. A usar dados locais.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _guardarDespesa(Map<String, dynamic> dados) async {
    await _db.inserirDespesa(dados);
    if (!_online) {
      await _sync.adicionarFilaSync(
        operacao: TipoOperacao.inserir,
        entidade: TipoEntidade.despesa,
        payload: dados,
      );
      setState(() => _pendentesSync++);
    }
  }

  Future<void> _guardarReceita(Map<String, dynamic> dados) async {
    await _db.inserirReceita(dados);
    if (!_online) {
      await _sync.adicionarFilaSync(
        operacao: TipoOperacao.inserir,
        entidade: TipoEntidade.receita,
        payload: dados,
      );
      setState(() => _pendentesSync++);
    }
  }

  void _mostrarDialogoEditarTransacao(Map<String, dynamic> transacao) async {
    final isDespesa           = transacao['tipo'] == 'Despesa';
    final categorias          = await _db.getCategorias(userId);
    final valorController     = TextEditingController(text: transacao['valor'].toString());
    final descricaoController = TextEditingController(text: transacao['descricao'] ?? '');

    int? categoriaSelecionadaId;
    if (isDespesa) {
      final cat = categorias.firstWhere(
        (c) => c['nome'] == transacao['categoria'],
        orElse: () => {},
      );
      categoriaSelecionadaId = cat['id'];
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Editar ${transacao['tipo']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: valorController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor (€)'),
                ),
                TextField(
                  controller: descricaoController,
                  decoration: const InputDecoration(labelText: 'Descricao'),
                ),
                if (isDespesa) ...[
                  const SizedBox(height: 20),
                  _dropdownCategorias(
                    categorias: categorias,
                    value: categoriaSelecionadaId,
                    onChanged: (v) => setDialogState(() => categoriaSelecionadaId = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final confirmar = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar'),
                    content: const Text('Deseja apagar esta transacao?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nao')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sim', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmar == true) {
                  if (isDespesa) {
                    await _db.eliminarDespesa(transacao['id']);
                  } else {
                    await _db.eliminarReceita(transacao['id']);
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                  _carregarDados();
                }
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (valorController.text.isNotEmpty) {
                  final Map<String, dynamic> dados = {
                    'id':        transacao['id'],
                    'valor':     double.tryParse(valorController.text) ?? 0.0,
                    'descricao': descricaoController.text,
                  };
                  if (isDespesa) {
                    dados['categoria_id'] = categoriaSelecionadaId;
                    await _db.atualizarDespesa(dados);
                  } else {
                    await _db.atualizarReceita(dados);
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                  _carregarDados();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoNovaDespesa() async {
    final categorias          = await _db.getCategorias(userId);
    final valorController     = TextEditingController();
    final descricaoController = TextEditingController();
    int? categoriaSelecionadaId;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova Despesa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: valorController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor (€)'),
                ),
                TextField(
                  controller: descricaoController,
                  decoration: const InputDecoration(labelText: 'Descricao'),
                ),
                const SizedBox(height: 20),
                _dropdownCategorias(
                  categorias: categorias,
                  value: categoriaSelecionadaId,
                  onChanged: (v) => setDialogState(() => categoriaSelecionadaId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (valorController.text.isNotEmpty && categoriaSelecionadaId != null) {
                  final dataRegisto =
                      (mesSelecionado == DateTime.now().month && anoSelecionado == DateTime.now().year)
                          ? DateTime.now()
                          : DateTime(anoSelecionado, mesSelecionado, 1);
                  await _guardarDespesa({
                    'valor':         double.tryParse(valorController.text) ?? 0.0,
                    'data':          dataRegisto.toIso8601String(),
                    'descricao':     descricaoController.text,
                    'categoria_id':  categoriaSelecionadaId,
                    'utilizador_id': userId,
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  _carregarDados();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoNovoDeposito() async {
    final valorController     = TextEditingController();
    final descricaoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Depositar (Receita)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valorController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Valor (€)'),
            ),
            TextField(
              controller: descricaoController,
              decoration: const InputDecoration(labelText: 'Descricao'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (valorController.text.isNotEmpty) {
                final dataRegisto =
                    (mesSelecionado == DateTime.now().month && anoSelecionado == DateTime.now().year)
                        ? DateTime.now()
                        : DateTime(anoSelecionado, mesSelecionado, 1);
                await _guardarReceita({
                  'valor':         double.tryParse(valorController.text) ?? 0.0,
                  'data':          dataRegisto.toIso8601String(),
                  'descricao':     descricaoController.text,
                  'utilizador_id': userId,
                });
                if (!mounted) return;
                Navigator.pop(context);
                _carregarDados();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _dropdownCategorias({
    required List<Map<String, dynamic>> categorias,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    final List<Color> cores = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple,
      Colors.cyan, Colors.indigo, Colors.teal, Colors.pink, Colors.amber, Colors.deepOrange,
    ];
    return DropdownButton<int>(
      isExpanded: true,
      hint: const Text('Selecionar Categoria'),
      value: value,
      items: categorias.asMap().entries.map((entry) {
        final cor = cores[entry.key % cores.length];
        final cat = entry.value;
        return DropdownMenuItem<int>(
          value: cat['id'],
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIconData(cat['logotipo']), size: 20, color: cor),
              ),
              const SizedBox(width: 15),
              Text(cat['nome']),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EXPENSO', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _online
                ? 'Online - Sincronizar'
                : 'Offline - $_pendentesSync pendente(s)',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _online ? Icons.cloud_done : Icons.cloud_off,
                  color: _online ? Colors.green : Colors.orange,
                ),
                if (_pendentesSync > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        '$_pendentesSync',
                        style: const TextStyle(fontSize: 9, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _sincronizarManualmente,
          ),
          PopupMenuButton<String>(
            tooltip: 'Moeda: $_moedaSelecionada',
            icon: Text(
              _moedaSelecionada,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onSelected: (moeda) => setState(() => _moedaSelecionada = moeda),
            itemBuilder: (_) => ServicoCambio.moedasDisponiveis
                .map((m) => PopupMenuItem(value: m, child: Text(m)))
                .toList(),
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregarDados,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _mudarMes(-1),
                          ),
                          Container(
                            width: 180,
                            alignment: Alignment.center,
                            child: Text(
                              getNomeMes(),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.chevron_right,
                              color: (anoSelecionado == DateTime.now().year &&
                                      mesSelecionado == DateTime.now().month)
                                  ? Colors.grey.withValues(alpha: 0.3)
                                  : null,
                            ),
                            onPressed: (anoSelecionado == DateTime.now().year &&
                                    mesSelecionado == DateTime.now().month)
                                ? null
                                : () => _mudarMes(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Saldo Global: ${_formatarValor(_balancoGlobal)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 220,
                        width: 320,
                        child: _secoesGrafico.isEmpty
                            ? const Center(child: Text('Sem despesas para este periodo'))
                            : PieChart(
                                PieChartData(
                                  sections: _secoesGrafico,
                                  centerSpaceRadius: 40,
                                  sectionsSpace: 2,
                                ),
                              ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _botaoAcao(Icons.attach_money, 'Depositar', _mostrarDialogoNovoDeposito),
                          _displayBalancoMensal(),
                          _botaoAcao(Icons.shopping_cart, 'Despesas', _mostrarDialogoNovaDespesa),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Historico em ${getNomeMes()}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _tabelaTransacoes(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _tabelaTransacoes() {
    if (_transacoes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Nenhuma transacao encontrada.'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('Tipo',      style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Valor',     style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Categoria', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Data',      style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _transacoes.map((t) {
          final isDespesa = t['tipo'] == 'Despesa';
          return DataRow(
            onSelectChanged: (selected) {
              if (selected == true) _mostrarDialogoEditarTransacao(t);
            },
            cells: [
              DataCell(Text(t['tipo'], style: TextStyle(color: isDespesa ? Colors.red : Colors.green))),
              DataCell(Text(_formatarValor((t['valor'] as num).toDouble()))),
              DataCell(Text(t['categoria'] ?? 'N/A')),
              DataCell(Text(formatarData(t['data']))),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _botaoAcao(IconData icon, String label, VoidCallback onPressed) {
    return SizedBox(
      height: 75,
      width: 75,
      child: TextButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(const Color.fromARGB(197, 170, 172, 171)),
          shape: WidgetStateProperty.all(const CircleBorder()),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black, size: 20),
            Text(label, style: const TextStyle(color: Colors.black, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _displayBalancoMensal() {
    return SizedBox(
      height: 50,
      width: 180,
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(198, 1, 122, 32),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          'Saldo do Mes : ${_formatarValor(_balancoMensal)}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color borderColor;

  const _Badge(this.icon, {required this.size, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Center(child: Icon(icon, size: size * .6, color: borderColor)),
    );
  }
}