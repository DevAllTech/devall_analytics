/// Web platform - compression not natively available.
List<int> gzipEncode(List<int> input) {
  throw UnsupportedError('Gzip compression not available on web');
}
