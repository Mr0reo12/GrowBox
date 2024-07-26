import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000';

  static Future<Map<String, dynamic>> fetchSensorData() async {
    final response = await http.get(Uri.parse('$baseUrl/api/sensor-data'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch sensor data');
    }
  }

  static Future<void> sendSensorData(double temperature, double humidity) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/sensor-data'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'temperature': temperature, 'humidity': humidity}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send sensor data');
    }
  }

  static Future<Map<String, dynamic>> fetchControlData() async {
    final response = await http.get(Uri.parse('$baseUrl/api/control'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch control data');
    }
  }

  static Future<void> setControlData(String state, bool isAutomatic, String startTime, String endTime) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/control'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'state': state,
        'mode': isAutomatic ? 'automatic' : 'manual',
        'start_time': startTime,
        'end_time': endTime,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to set control data');
    }
  }
}
