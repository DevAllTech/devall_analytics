import 'dart:io';

/// Gzip-encodes bytes using dart:io's GZipCodec.
List<int> gzipEncode(List<int> input) {
  return gzip.encode(input);
}
