import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A log entry for the debug overlay.
class DevAllDebugEntry {
  final String type;
  final String message;
  final DateTime timestamp;
  final bool success;

  DevAllDebugEntry({
    required this.type,
    required this.message,
    required this.success,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Singleton log for debug entries.
class DevAllDebugLog {
  static final Queue<DevAllDebugEntry> _entries = Queue();
  static int _maxEntries = 100;
  static final List<VoidCallback> _listeners = [];

  /// Adds a debug entry.
  static void add({
    required String type,
    required String message,
    bool success = true,
  }) {
    if (!kDebugMode) return;

    _entries.addLast(DevAllDebugEntry(
      type: type,
      message: message,
      success: success,
    ));

    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }

    for (final listener in _listeners) {
      listener();
    }
  }

  /// Returns all entries as a list.
  static List<DevAllDebugEntry> get entries =>
      _entries.toList().reversed.toList();

  /// Number of entries.
  static int get length => _entries.length;

  /// Registers a listener for new entries.
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Removes a listener.
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Clears all entries.
  static void clear() {
    _entries.clear();
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Sets the max entries to keep.
  static void setMaxEntries(int max) {
    _maxEntries = max;
  }

  /// Resets state for testing.
  @visibleForTesting
  static void reset() {
    _entries.clear();
    _listeners.clear();
    _maxEntries = 100;
  }
}

/// Debug overlay widget that shows real-time analytics events.
///
/// Only renders in debug mode. In release mode, renders nothing.
///
/// Usage:
/// ```dart
/// Stack(children: [
///   MyApp(),
///   DevAllDebugOverlay(),
/// ])
/// ```
class DevAllDebugOverlay extends StatefulWidget {
  const DevAllDebugOverlay({super.key});

  @override
  State<DevAllDebugOverlay> createState() => _DevAllDebugOverlayState();
}

class _DevAllDebugOverlayState extends State<DevAllDebugOverlay> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    DevAllDebugLog.addListener(_onUpdate);
  }

  @override
  void dispose() {
    DevAllDebugLog.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final entries = DevAllDebugLog.entries;

    return Positioned(
      bottom: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[900],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header toggle
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.analytics, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'DevAll (${entries.length})',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            // Event list
            if (_expanded)
              Container(
                width: 300,
                constraints: const BoxConstraints(maxHeight: 250),
                child: entries.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'No events yet',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: entries.length,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  entry.success
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: entry.success
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  size: 12,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '[${entry.type}] ${entry.message}',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
