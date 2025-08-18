// lib/features/preparacao/data/api_medidas_repository.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'medidas_repository.dart';
import 'models.dart';

class ApiMedidasRepository implements MedidasRepository {
  final String baseUrl;
  final http.Client _client;

  ApiMedidasRepository({
    http.Client? client,
    String? overrideBaseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = overrideBaseUrl ??
            (dotenv.maybeGet('API_BASE_URL') ?? 'http://192.168.0.82:5005');

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse(baseUrl).replace(path: path, queryParameters: q);

  @override
  Future<List<MedidaItem>> getMedidas({
    required String partnumber,
    required String operacao,
  }) async {
    // Endpoint esperado do microserviço Flask:
    // GET /medidas?partnumber=000000000373&operacao=010
    final uri = _u('/medidas', {
      'partnumber': partnumber,
      'operacao': operacao,
    });

    final resp = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Falha ao buscar medidas (${resp.statusCode})');
    }

    final body = resp.body.isEmpty ? '[]' : resp.body;
    final data = jsonDecode(body);

    if (data is List) {
      return data.map<MedidaItem>((e) => MedidaItem.fromMap(e)).toList();
    }

    // Também aceitamos um envelope {items:[...]}
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .map<MedidaItem>((e) => MedidaItem.fromMap(e))
          .toList();
    }

    throw Exception('Formato de resposta inválido do endpoint /medidas');
  }

  @override
  Future<void> enviarResultado(PreparacaoResultado resultado) async {
    // Endpoint esperado:
    // POST /medidas/resultado  body: { re, partnumber, operacao, timestamp, itens:[...] }
    final uri = _u('/medidas/resultado');

    final resp = await _client
        .post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: resultado.toJson(),
    )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          'Falha ao enviar resultado (${resp.statusCode}): ${resp.body}');
    }
  }
}
