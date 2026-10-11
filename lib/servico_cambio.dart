import 'dart:convert';
import 'package:http/http.dart' as http;

/// Serviço que consome a API REST pública frankfurter.app
/// para obter taxas de câmbio em tempo real.
class ServicoCambio {
  static const String _baseUrl = 'https://api.frankfurter.app';

  // Moedas suportadas para conversão
  static const List<String> moedasDisponiveis = ['EUR', 'USD', 'GBP', 'CHF', 'JPY', 'BRL'];

  /// Obtém as taxas de câmbio a partir de EUR para todas as moedas suportadas.
  /// Retorna um mapa { 'USD': 1.08, 'GBP': 0.85, ... } ou null em caso de erro.
  static Future<Map<String, double>?> obterTaxasDeCambio() async {
    try {
      final moedas = moedasDisponiveis.where((m) => m != 'EUR').join(',');
      final uri = Uri.parse('$_baseUrl/latest?from=EUR&to=$moedas');
      final resposta = await http.get(uri).timeout(const Duration(seconds: 10));

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body) as Map<String, dynamic>;
        final taxas = Map<String, double>.from(
          (dados['rates'] as Map<String, dynamic>).map(
            (chave, valor) => MapEntry(chave, (valor as num).toDouble()),
          ),
        );
        // EUR para EUR é sempre 1.0
        taxas['EUR'] = 1.0;
        return taxas;
      }
    } catch (_) {
      // Sem internet ou erro de rede — retorna null
    }
    return null;
  }

  /// Converte um valor de EUR para a moeda destino usando as taxas fornecidas.
  static double converter(double valorEmEuro, String moedaDestino, Map<String, double> taxas) {
    final taxa = taxas[moedaDestino] ?? 1.0;
    return valorEmEuro * taxa;
  }
}
