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
            (dotenv.maybeGet('API_BASE_URL') ?? 'http://192.168.0.241:5005');

  // Constrói a URL final a partir do [baseUrl].
  // Usa [Uri.resolve] para preservar qualquer subcaminho presente no
  // `API_BASE_URL` (ex.: http://host:5005/api) e então aplica os
  // parâmetros de consulta.
  Uri _u(String path, [Map<String, String>? q]) {
    final base = Uri.parse(baseUrl);
    final resolved = base.resolve(path);
    return resolved.replace(queryParameters: q);
  }

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
