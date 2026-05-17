import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SemanticPaper {
  final String paperId;
  final String title;
  final String abstract_;
  final List<String> authors;
  final int? year;
  final String? url;
  final String? pdfUrl;

  SemanticPaper({
    required this.paperId,
    required this.title,
    required this.abstract_,
    required this.authors,
    this.year,
    this.url,
    this.pdfUrl,
  });

  factory SemanticPaper.fromJson(Map<String, dynamic> json) {
    final authorList = (json['authors'] as List?)
        ?.map((a) => a['name'] as String? ?? 'Unknown')
        .toList() ?? [];
    
    String? pdfUrl;
    if (json['openAccessPdf'] != null && json['openAccessPdf'] is Map) {
      pdfUrl = json['openAccessPdf']['url'] as String?;
    }

    return SemanticPaper(
      paperId: json['paperId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      abstract_: json['abstract'] as String? ?? '',
      authors: authorList,
      year: json['year'] as int?,
      url: json['url'] as String?,
      pdfUrl: pdfUrl,
    );
  }

  String get authorString => authors.join(', ');
  
  String toFileContent() {
    final sb = StringBuffer();
    sb.writeln("Title: $title");
    sb.writeln("Authors: $authorString");
    if (year != null) sb.writeln("Year: $year");
    if (url != null) sb.writeln("URL: $url");
    sb.writeln("");
    sb.writeln("Abstract:");
    sb.writeln(abstract_);
    return sb.toString();
  }
}

class SemanticScholarClient {
  /// Get the backend base URL (same logic as AiClient)
  static String _backendUrl() {
    if (kIsWeb) {
      final pageHost = Uri.base.host;
      return 'http://$pageHost:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// Search for papers via the backend proxy (avoids CORS)
  Future<List<SemanticPaper>> searchPapers(String query, {int limit = 10, int minYear = 1900}) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('${_backendUrl()}/semantic_scholar');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'limit': limit, 'minYear': minYear}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) return [];
        final papers = (data['data'] as List?)
            ?.map((p) => SemanticPaper.fromJson(p as Map<String, dynamic>))
            .where((p) => p.abstract_.isNotEmpty)
            .toList() ?? [];
        return papers;
      } else {
        return [];
      }
    } catch (e) {
      print("Semantic Scholar Client Error: $e");
      return [];
    }
  }

  /// Build a search query from existing literature keywords
  Future<List<SemanticPaper>> searchRelatedToContent(List<String> keywords, {int limit = 10, int minYear = 1900}) async {
    if (keywords.isEmpty) return [];
    
    // The first keyword is the research title. Using too many words causes 0 results.
    String query = keywords.first;
    if (query.trim().isEmpty && keywords.length > 1) {
      query = keywords[1];
    }
    // Limit to first 12 words to avoid strict match failure
    query = query.split(RegExp(r'\s+')).take(12).join(' ');
    
    print("Semantic Scholar Query: $query");
    return searchPapers(query, limit: limit, minYear: minYear);
  }
}
