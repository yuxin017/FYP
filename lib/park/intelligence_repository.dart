import '../services/application_api.dart';

abstract class ParkIntelligenceRepository {
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  );
}

class FirebaseParkIntelligenceRepository implements ParkIntelligenceRepository {
  final ApplicationApi api;
  FirebaseParkIntelligenceRepository({ApplicationApi? service})
    : api = service ?? ApplicationApi();
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) => api.post('/v1/ai/$action', data);
}
