// lib/features/preparacao/data/api_medidas_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'medidas_repository.dart';
import 'models.dart';

class ApiMedidasRepository implements MedidasRepository {
  final String baseUrl;
  final http.Client _client;

  /// Endpoints (ajuste se sua API usar outros caminhos)
  final String medidasPath;
  final String resultadoPath;

  ApiMedidasRepository({
    http.Client? client,
    String? overrideBaseUrl,
    this.medidasPath = '/medidas',     // <- correto
    this.resultadoPath = '/resultado',
  })  : _client = client ?? http.Client(),
        baseUrl = overrideBaseUrl ?? (dotenv.env['API_BASE_URL'] ?? '') {
    if (baseUrl.isEmpty) {
      throw StateError('API_BASE_URL não configurada no .env e nenhum override foi passado');
    }
  }

  /// Monta a URI usando **apenas** scheme/host/port do baseUrl (ignora path).
  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final root = Uri.parse(baseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return Uri(
      scheme: root.scheme,
      host: root.host,
      port: root.hasPort ? root.port : null,
      path: normalizedPath, // <- nunca prefixa com caminho do baseUrl
      queryParameters:
      query?.map((k, v) => MapEntry(k, v?.toString())),
    );
  }

  @override
  Future<List<MedidaItem>> getMedidas({
    required String partnumber,
    required String operacao,
  }) async {
    // Se seu Flask espera "peca" em vez de "partnumber", troque a chave abaixo.
    final uri = _buildUri(medidasPath, {
      'partnumber': partnumber,
      'operacao': operacao,
    });

    if (kDebugMode) debugPrint('GET $uri');

    final resp = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Falha ao buscar medidas (${resp.statusCode}): ${resp.body}');
    }

    final body = resp.body.isEmpty ? '[]' : resp.body;
    final data = jsonDecode(body);

    if (data is List) {
      return data
          .map<MedidaItem>((e) => MedidaItem.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
    }

    return <MedidaItem>[];
  }

  @override
  Future<void> enviarResultado(PreparacaoResultado resultado) async {
    final uri = _buildUri(resultadoPath);

    if (kDebugMode) debugPrint('POST $uri');

    final resp = await _client
        .post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(resultado.toMap()),
    )
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Falha ao enviar resultado (${resp.statusCode}): ${resp.body}');
    }
  }
}
