import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Growbox Monitor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String temperature = 'Loading...';
  String humidity = 'Loading...';
  String state = 'OFF';
  bool isAutomatic = false;
  String startTime = '';
  String endTime = '';

  @override
  void initState() {
    super.initState();
    fetchSensorData();
    fetchControlData();
  }

  Future<void> fetchSensorData() async {
    final response = await http.get(Uri.parse('http://10.0.2.2:5000/api/sensor-data'));
    final data = json.decode(response.body);
    setState(() {
      temperature = '${data['temperature']} °C';
      humidity = '${data['humidity']} %';
    });
  }

  Future<void> fetchControlData() async {
    final response = await http.get(Uri.parse('http://10.0.2.2:5000/api/control'));
    final data = json.decode(response.body);
    setState(() {
      state = data['state'];
      isAutomatic = data['mode'] == 'automatic';
      startTime = data['start_time'] ?? '';
      endTime = data['end_time'] ?? '';
    });
  }

  Future<void> setControlData() async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:5000/api/control'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: json.encode({
        'state': state,
        'mode': isAutomatic ? 'automatic' : 'manual',
        'start_time': startTime,
        'end_time': endTime,
      }),
    );
    fetchControlData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Growbox Monitor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Temperature: $temperature'),
            Text('Humidity: $humidity'),
            SizedBox(height: 20),
            Text('State: $state'),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  state = state == 'ON' ? 'OFF' : 'ON';
                });
                setControlData();
              },
              child: Text(state == 'ON' ? 'Turn Off' : 'Turn On'),
            ),
            SizedBox(height: 20),
            Row(
              children: <Widget>[
                Text('Mode: ${isAutomatic ? 'Automatic' : 'Manual'}'),
                Switch(
                  value: isAutomatic,
                  onChanged: (value) {
                    setState(() {
                      isAutomatic = value;
                    });
                    setControlData();
                  },
                ),
              ],
            ),
            if (isAutomatic) ...[
              TextField(
                decoration: InputDecoration(labelText: 'Start Time (HH:MM:SS)'),
                onChanged: (value) {
                  startTime = value;
                },
                controller: TextEditingController(text: startTime),
              ),
              TextField(
                decoration: InputDecoration(labelText: 'End Time (HH:MM:SS)'),
                onChanged: (value) {
                  endTime = value;
                },
                controller: TextEditingController(text: endTime),
              ),
              ElevatedButton(
                onPressed: setControlData,
                child: Text('Set Schedule'),
              ),
            ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: fetchSensorData,
              child: Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
