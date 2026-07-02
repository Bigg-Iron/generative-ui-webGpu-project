import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const _endpoint =
    'http://127.0.0.1:7839/ingest/744d721e-27fa-4e45-b406-706d6919c4f3';
const _sessionId = 'd535ca';

void writeAgentLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, Object?> data = const {},
  String runId = 'pre-fix',
}) {
  final payload = jsonEncode({
    'sessionId': _sessionId,
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  });

  try {
    html.HttpRequest.request(
      _endpoint,
      method: 'POST',
      sendData: payload,
      requestHeaders: {
        'Content-Type': 'application/json',
        'X-Debug-Session-Id': _sessionId,
      },
    );
  } catch (_) {}
}

void agentLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, Object?> data = const {},
  String runId = 'pre-fix',
}) {
  writeAgentLog(
    location: location,
    message: message,
    hypothesisId: hypothesisId,
    data: data,
    runId: runId,
  );
}
