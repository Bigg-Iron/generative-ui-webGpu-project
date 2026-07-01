import 'dart:convert';

class WordPieceTokenizer {
  final Map<String, int> vocab;
  final int maxSeqLength;

  static const String clsToken = '[CLS]';
  static const String sepToken = '[SEP]';
  static const String unkToken = '[UNK]';
  static const String padToken = '[PAD]';

  WordPieceTokenizer({
    required this.vocab,
    this.maxSeqLength = 128,
  });

  /// Factory to parse vocabulary from a plain-text string where each line represents a token.
  factory WordPieceTokenizer.fromString(String vocabText, {int maxSeqLength = 128}) {
    final vocab = <String, int>{};
    final lines = const LineSplitter().convert(vocabText);
    for (var i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) {
        vocab[token] = i;
      }
    }
    return WordPieceTokenizer(vocab: vocab, maxSeqLength: maxSeqLength);
  }

  /// Factory to generate a default minimal fallback vocabulary for initial setup/testing.
  factory WordPieceTokenizer.fallback({int maxSeqLength = 128}) {
    final vocab = <String, int>{
      padToken: 0,
      unkToken: 100,
      clsToken: 101,
      sepToken: 102,
    };
    
    // Add some common words for testing
    final commonWords = [
      'the', 'of', 'and', 'a', 'to', 'in', 'is', 'you', 'that', 'it', 'he', 'was', 
      'for', 'on', 'are', 'as', 'with', 'his', 'they', 'i', 'at', 'be', 'this', 'have',
      'from', 'or', 'one', 'had', 'by', 'word', 'but', 'not', 'what', 'all', 'were',
      'we', 'when', 'your', 'can', 'said', 'there', 'use', 'an', 'each', 'which', 
      'she', 'do', 'how', 'their', 'if', 'will', 'up', 'other', 'about', 'out', 'many',
      'then', 'them', 'these', 'so', 'some', 'her', 'would', 'make', 'like', 'him',
      'into', 'time', 'has', 'look', 'two', 'more', 'write', 'go', 'see', 'number',
      'no', 'way', 'could', 'people', 'my', 'than', 'first', 'water', 'been', 'call',
      'who', 'oil', 'its', 'now', 'find', 'long', 'down', 'day', 'did', 'get', 'come',
      'made', 'may', 'part'
    ];

    for (var i = 0; i < commonWords.length; i++) {
      vocab[commonWords[i]] = 103 + i;
    }

    return WordPieceTokenizer(vocab: vocab, maxSeqLength: maxSeqLength);
  }

  int get clsId => vocab[clsToken] ?? 101;
  int get sepId => vocab[sepToken] ?? 102;
  int get unkId => vocab[unkToken] ?? 100;
  int get padId => vocab[padToken] ?? 0;

  /// Clean and normalize the text (lowercase, basic punctuation splitting).
  String _normalize(String text) {
    var cleaned = text.toLowerCase();
    
    // Inserts spaces around punctuation marks so they are split out as individual tokens.
    final buffer = StringBuffer();
    for (var i = 0; i < cleaned.length; i++) {
      final char = cleaned[i];
      if (_isPunctuation(char)) {
        buffer.write(' $char ');
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isPunctuation(String char) {
    const punct = r'''!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~''';
    return punct.contains(char);
  }

  /// Tokenizes text into WordPiece IDs.
  List<int> encode(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) {
      return [clsId, sepId];
    }

    final words = normalized.split(' ');
    final tokenIds = <int>[clsId];

    for (final word in words) {
      if (word.isEmpty) continue;

      if (vocab.containsKey(word)) {
        tokenIds.add(vocab[word]!);
        continue;
      }

      // WordPiece algorithm: greedily find longest subword prefix matching vocabulary.
      var start = 0;
      var isBad = false;
      final wordTokens = <int>[];

      while (start < word.length) {
        var end = word.length;
        var matchId = -1;

        while (start < end) {
          var substr = word.substring(start, end);
          if (start > 0) {
            substr = '##$substr';
          }

          if (vocab.containsKey(substr)) {
            matchId = vocab[substr]!;
            break;
          }
          end--;
        }

        if (matchId == -1) {
          isBad = true;
          break;
        }

        wordTokens.add(matchId);
        start = end;
      }

      if (isBad) {
        tokenIds.add(unkId);
      } else {
        tokenIds.addAll(wordTokens);
      }
    }

    tokenIds.add(sepId);

    // Padding or truncation
    if (tokenIds.length > maxSeqLength) {
      final truncated = tokenIds.sublist(0, maxSeqLength - 1)..add(sepId);
      return truncated;
    } else {
      final paddingNeeded = maxSeqLength - tokenIds.length;
      tokenIds.addAll(List.filled(paddingNeeded, padId));
      return tokenIds;
    }
  }

  /// Returns human-readable token strings for visualization (non-padded).
  List<String> tokenizeToStrings(String text) {
    final ids = encode(text);
    final reverse = <int, String>{};
    for (final entry in vocab.entries) {
      reverse[entry.value] = entry.key;
    }
    return ids
        .where((id) => id != padId)
        .map((id) => reverse[id] ?? unkToken)
        .toList();
  }
}
