import 'package:dio/dio.dart';
import 'models.dart';
import 'excel_repository.dart';

class ApiMedidasRepository implements MedidasRepository {
  final Dio _dio;
  ApiMedidasRepository(this._dio);

  @override
  Future<List<MedidaItem>> buscar(String partNumber, String operacao) async {
    final resp = await _dio.get('/api/medidas', queryParameters: {
      'part': partNumber.trim(),
      'op': operacao.trim(),
    });
    final list = (resp.data['medidas'] as List).cast<Map<String, dynamic>>();
    return list.map((e) => MedidaItem.fromMap(e)).toList();
  }
}