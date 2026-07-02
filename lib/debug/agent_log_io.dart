import 'dart:convert';
import 'dart:io';

const _logPath =
    '/Users/lorenzobartolo/Documents/computing/generative-ui-webGpu-project/.cursor/debug-d535ca.log';
const _sessionId = 'd535ca';

void writeAgentLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, Object?> data = const {},
  String runId = 'pre-fix',
}) {
  final payload = {
    'sessionId': _sessionId,
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };

  try {
    File(_logPath).writeAsStringSync(
      '${jsonEncode(payload)}\n',
      mode: FileMode.append,
      flush: true,
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
