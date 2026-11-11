import '../services/application_api.dart';

abstract class ParkLocationRepository {
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  );
}

class FirebaseParkLocationRepository implements ParkLocationRepository {
  final ApplicationApi api;
  FirebaseParkLocationRepository({ApplicationApi? api})
    : api = api ?? ApplicationApi();
  @override
  Future<Map<String, dynamic>> request(
    String action,
    Map<String, dynamic> data,
  ) => api.post('/v1/location/$action', data);
}
