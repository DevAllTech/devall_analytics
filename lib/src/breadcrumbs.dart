import 'dart:collection';

import 'package:flutter/foundation.dart';

/// A single breadcrumb entry representing a user action or event.
class DevAllBreadcrumb {
  final String category;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  DevAllBreadcrumb({
    required this.category,
    required this.message,
    DateTime? timestamp,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'category': category,
        'message': message,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (data != null && data!.isNotEmpty) 'data': data,
      };
}

/// Circular buffer of recent breadcrumbs for error context.
///
/// Breadcrumbs are automatically trimmed to [maxBreadcrumbs].
/// They are included in error events to show what happened before the error.
class DevAllBreadcrumbs {
  static int _maxBreadcrumbs = 50;
  static final Queue<DevAllBreadcrumb> _breadcrumbs = Queue();

  /// Sets the maximum number of breadcrumbs to keep.
  static void setMaxBreadcrumbs(int max) {
    _maxBreadcrumbs = max;
    _trim();
  }

  /// Adds a breadcrumb to the trail.
  static void add({
    required String category,
    required String message,
    Map<String, dynamic>? data,
  }) {
    _breadcrumbs.addLast(DevAllBreadcrumb(
      category: category,
      message: message,
      data: data,
    ));
    _trim();
  }

  /// Returns all breadcrumbs as a list of JSON maps.
  static List<Map<String, dynamic>> toJsonList() {
    return _breadcrumbs.map((b) => b.toJson()).toList();
  }

  /// Returns the current number of breadcrumbs.
  static int get length => _breadcrumbs.length;

  /// Clears all breadcrumbs.
  static void clear() {
    _breadcrumbs.clear();
  }

  static void _trim() {
    while (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeFirst();
    }
  }

  /// Resets state for testing.
  @visibleForTesting
  static void reset() {
    _breadcrumbs.clear();
    _maxBreadcrumbs = 50;
  }
}
