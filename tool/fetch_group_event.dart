import 'dart:convert';
import 'dart:io';

void main() async {
  final ws = await WebSocket.connect('wss://groups.fiatjaf.com');
  // Fetch chat messages from a known active group
  ws.add(json.encode(["REQ", "msgs", {"kinds": [9, 11, 12], "#h": ["e1cc34"], "limit": 3}]));
  ws.listen((data) {
    stdout.writeln(data);
  });
  await Future.delayed(const Duration(seconds: 5));
  await ws.close();
  exit(0);
}
