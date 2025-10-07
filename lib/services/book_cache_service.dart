import 'dart:typed_data';

/// Service to manage book caching across the app
/// This provides a public interface to the EPUB viewer cache
class BookCacheService {
  // Static cache for parsed books
  static final Map<String, BookCacheEntry> _cache = {};

  /// Get information about the cache
  static Map<String, dynamic> getCacheInfo() {
    return {
      'cachedBooksCount': _cache.length,
      'cachedBookIds': _cache.keys.toList(),
      'cacheEntries': _cache.entries.map((e) => {
        'bookId': e.key,
        'pageCount': e.value.pages.length,
        'imageCount': e.value.images.length,
        'cachedAt': e.value.cachedAt.toIso8601String(),
      }).toList(),
    };
  }

  /// Clear all cached books
  static void clearCache() {
    print('🗑️ Clearing book cache (${_cache.length} books)');
    _cache.clear();
  }

  /// Remove a specific book from cache
  static void removeCachedBook(String bookId) {
    if (_cache.containsKey(bookId)) {
      print('🗑️ Removing book from cache: $bookId');
      _cache.remove(bookId);
    }
  }

  /// Check if a book is cached
  static bool isCached(String bookId) {
    return _cache.containsKey(bookId);
  }

  /// Get a cached book entry
  static BookCacheEntry? getCachedBook(String bookId) {
    return _cache[bookId];
  }

  /// Add a book to the cache
  static void cacheBook(String bookId, BookCacheEntry entry) {
    print('💾 Caching book: $bookId');
    _cache[bookId] = entry;
    print('✅ Book cached successfully! Cache size: ${_cache.length} books');
  }

  /// Get total cached books count
  static int get cachedBooksCount => _cache.length;

  /// Get total memory usage estimate (rough calculation)
  static int getMemoryUsageEstimate() {
    int totalBytes = 0;
    for (var entry in _cache.values) {
      // Estimate text size (2 bytes per character for UTF-16)
      for (var page in entry.pages) {
        totalBytes += page.length * 2;
      }
      // Add image sizes
      for (var image in entry.images.values) {
        totalBytes += image.length;
      }
    }
    return totalBytes;
  }

  /// Get human-readable memory usage
  static String getMemoryUsageFormatted() {
    final bytes = getMemoryUsageEstimate();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Book cache entry class
class BookCacheEntry {
  final List<String> pages;
  final Map<String, Uint8List> images;
  final String bookTitle;
  final DateTime cachedAt;

  BookCacheEntry({
    required this.pages,
    required this.images,
    required this.bookTitle,
  }) : cachedAt = DateTime.now();
}
