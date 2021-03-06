import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

abstract class HttpService {
  /// Makes a PUT request to the endpoint given by [to].
  Future<SimpleHttpResponse> putBinary(
      {required String to,
      required Stream<List<int>> data,
      required int contentLength,
      Map<String, String>? headers});

  Future<SimpleHttpResponse> postJson(
      {required String to,
      required Map<String, dynamic> body,
      Map<String, String>? headers});

  factory HttpService.makeInstance() {
    return _HttpService();
  }
}

class SimpleHttpResponse {
  final int statusCode;
  final String body;
  SimpleHttpResponse(this.statusCode, this.body);

  Map<String, dynamic> parseBodyAsJsonMap() {
    return json.decode(body) as Map<String, dynamic>;
  }
}

class _HttpService implements HttpService {
  @override
  Future<SimpleHttpResponse> putBinary(
      {required String to,
      required Stream<List<int>> data,
      required int contentLength,
      Map<String, String>? headers}) async {
    headers = headers ?? <String, String>{};
    headers.putIfAbsent(
        HttpHeaders.contentTypeHeader, () => 'application/octet-stream');

    final request = await HttpClient().putUrl(Uri.parse(to));
    headers.forEach((key, value) => request.headers.set(key, value));

    int numberOfBytesWritten = 0;
    Stopwatch counter = Stopwatch();
    final response = await data.map((chunk) {
      counter.start();

      numberOfBytesWritten += chunk.length;

      if (counter.elapsed > Duration(seconds: 1)) {
        counter.reset();
        print(
            "Uploaded ${(numberOfBytesWritten / contentLength * 100).ceil()}% of $contentLength");
      }

      return chunk;
    }).pipe(StreamConsumerWithCallbacks(request, onFinalise: () {
      print('Finalising upload...');
    }));

    return SimpleHttpResponse(
        response.statusCode, await response.transform(utf8.decoder).join());
  }

  @override
  Future<SimpleHttpResponse> postJson(
      {required String to,
      required Map<String, dynamic> body,
      Map<String, String>? headers}) async {
    headers = headers ?? <String, String>{};
    headers.putIfAbsent(
        HttpHeaders.contentTypeHeader, () => 'application/json');
    final response = await http.put(Uri.parse(to),
        body: json.encode(body), headers: headers);

    return SimpleHttpResponse(response.statusCode, response.body);
  }
}

class StreamConsumerWithCallbacks implements StreamConsumer<List<int>> {
  final void Function() onFinalise;
  final StreamConsumer relayTo;
  StreamConsumerWithCallbacks(this.relayTo, {required this.onFinalise});

  @override
  Future addStream(Stream stream) {
    return relayTo.addStream(stream);
  }

  @override
  Future close() {
    onFinalise();
    return relayTo.close();
  }
}
