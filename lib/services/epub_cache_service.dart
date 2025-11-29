import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Service for caching parsed EPUB pages and images locally
/// This dramatically improves performance when reopening books
class EpubCacheService {
  static const String _prefixPages = 'epub_pages_';
  static const String _prefixImages = 'epub_images_';
  static const String _prefixHash = 'epub_hash_';
  static const String _prefixTitle = 'epub_title_';
  static const String _prefixVersion = 'epub_version_';
  static const int _maxCacheAgeHours = 24 * 30; // 30 days
  
  /// IMPORTANT: Increment this version number whenever you change the EPUB parsing logic
  /// This ensures old caches are invalidated when parser improvements are made
  /// Version history:
  /// - v1: Initial cache implementation
  /// - v2: Added link support and variable-size image rendering
  static const int _cacheVersion = 2;

  /// Generate a hash from EPUB bytes to detect if file has changed
  static String _generateHash(List<int> bytes) {
    // Use first and last 10KB plus file length for fast hashing
    final sampleSize = 10240; // 10KB
    final totalSize = bytes.length;
    
    List<int> sample;
    if (totalSize <= sampleSize * 2) {
      sample = bytes;
    } else {
      sample = [
        ...bytes.sublist(0, sampleSize),
        ...bytes.sublist(totalSize - sampleSize, totalSize),
      ];
    }
    
    final digest = md5.convert([...sample, ...utf8.encode(totalSize.toString())]);
    return digest.toString();
  }

  /// Save parsed pages to cache
  static Future<bool> savePagesCache({
    required String bookId,
    required List<int> epubBytes,
    required List<String> pages,
    required Map<String, Uint8List> images,
    required String bookTitle,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hash = _generateHash(epubBytes);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Save pages as JSON
      final pagesJson = jsonEncode({
        'pages': pages,
        'timestamp': timestamp,
      });

      // Save images as base64-encoded JSON
      final imagesMap = <String, String>{};
      images.forEach((key, value) {
        imagesMap[key] = base64Encode(value);
      });
      final imagesJson = jsonEncode({
        'images': imagesMap,
        'timestamp': timestamp,
      });

      // Save all data
      await prefs.setString('$_prefixPages$bookId', pagesJson);
      await prefs.setString('$_prefixImages$bookId', imagesJson);
      await prefs.setString('$_prefixHash$bookId', hash);
      await prefs.setString('$_prefixTitle$bookId', bookTitle);
      await prefs.setInt('$_prefixVersion$bookId', _cacheVersion);

      print('✅ EPUB cache saved for book $bookId: ${pages.length} pages, ${images.length} images (v$_cacheVersion)');
      return true;
    } catch (e) {
      print('❌ Error saving EPUB cache: $e');
      return false;
    }
  }

  /// Load parsed pages from cache
  static Future<Map<String, dynamic>?> loadPagesCache({
    required String bookId,
    required List<int> epubBytes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check cache version first
      final savedVersion = prefs.getInt('$_prefixVersion$bookId');
      if (savedVersion == null || savedVersion != _cacheVersion) {
        print('📦 EPUB cache miss for book $bookId (version mismatch: saved=$savedVersion, current=$_cacheVersion)');
        // Clear old cache to free up space
        await clearBookCache(bookId);
        return null;
      }
      
      final currentHash = _generateHash(epubBytes);
      final savedHash = prefs.getString('$_prefixHash$bookId');

      // Check if hash matches (file hasn't changed)
      if (savedHash == null || savedHash != currentHash) {
        print('📦 EPUB cache miss for book $bookId (hash mismatch or not found)');
        return null;
      }

      // Load pages
      final pagesJson = prefs.getString('$_prefixPages$bookId');
      if (pagesJson == null) {
        print('📦 EPUB cache miss for book $bookId (pages not found)');
        return null;
      }

      final pagesData = jsonDecode(pagesJson) as Map<String, dynamic>;
      final timestamp = pagesData['timestamp'] as int;
      
      // Check cache age
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      final ageHours = age / (1000 * 60 * 60);
      if (ageHours > _maxCacheAgeHours) {
        print('📦 EPUB cache expired for book $bookId (${ageHours.toInt()} hours old)');
        await clearBookCache(bookId);
        return null;
      }

      // Load images
      final imagesJson = prefs.getString('$_prefixImages$bookId');
      final imagesData = imagesJson != null 
          ? jsonDecode(imagesJson) as Map<String, dynamic>
          : <String, dynamic>{};
      
      final imagesMap = imagesData['images'] as Map<String, dynamic>? ?? {};
      final images = <String, Uint8List>{};
      imagesMap.forEach((key, value) {
        images[key] = base64Decode(value as String);
      });

      // Load title
      final bookTitle = prefs.getString('$_prefixTitle$bookId') ?? 'Book';

      final pages = (pagesData['pages'] as List).cast<String>();
      
      print('✅ EPUB cache hit for book $bookId: ${pages.length} pages, ${images.length} images');
      
      return {
        'pages': pages,
        'images': images,
        'title': bookTitle,
      };
    } catch (e) {
      print('❌ Error loading EPUB cache: $e');
      return null;
    }
  }

  /// Clear cache for a specific book
  static Future<void> clearBookCache(String bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefixPages$bookId');
      await prefs.remove('$_prefixImages$bookId');
      await prefs.remove('$_prefixHash$bookId');
      await prefs.remove('$_prefixTitle$bookId');
      await prefs.remove('$_prefixVersion$bookId');
      print('🗑️ EPUB cache cleared for book $bookId');
    } catch (e) {
      print('❌ Error clearing EPUB cache: $e');
    }
  }

  /// Clear all EPUB caches (both SharedPreferences and file-based)
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Clear SharedPreferences-based cache (parsed pages/images)
      for (final key in keys) {
        if (key.startsWith(_prefixPages) || 
            key.startsWith(_prefixImages) || 
            key.startsWith(_prefixHash) ||
            key.startsWith(_prefixTitle) ||
            key.startsWith(_prefixVersion)) {
          await prefs.remove(key);
        }
      }
      
      print('🗑️ All EPUB SharedPreferences caches cleared');
      
      // Clear file-based EPUB cache
      await clearCache();
    } catch (e) {
      print('❌ Error clearing all EPUB caches: $e');
    }
  }

  /// Clear file-based EPUB cache (from epub_viewer)
  static Future<void> clearCache() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDocDir.path}/epub_cache');
      
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('🗑️ EPUB file cache directory cleared');
      }
      
      // Clear all file cache references from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('epub_cache_')) {
          await prefs.remove(key);
        }
      }
      print('✅ EPUB file cache references cleared from SharedPreferences');
    } catch (e) {
      print('Error clearing EPUB file cache: $e');
      rethrow;
    }
  }

  /// Get total file-based EPUB cache size in MB
  static Future<String> getCacheSize() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDocDir.path}/epub_cache');
      
      if (!await cacheDir.exists()) {
        return '0 MB';
      }
      
      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      final sizeMB = (totalSize / 1024 / 1024).toStringAsFixed(2);
      return '$sizeMB MB';
    } catch (e) {
      print('Error calculating EPUB cache size: $e');
      return 'Unknown';
    }
  }

  /// Get comprehensive cache statistics (both types)
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final bookIds = <String>{};
      int sharedPrefSize = 0;
      
      // Calculate SharedPreferences cache size
      for (final key in keys) {
        if (key.startsWith(_prefixPages)) {
          final bookId = key.substring(_prefixPages.length);
          bookIds.add(bookId);
          
          final data = prefs.getString(key);
          if (data != null) {
            sharedPrefSize += data.length;
          }
        }
        if (key.startsWith(_prefixImages)) {
          final data = prefs.getString(key);
          if (data != null) {
            sharedPrefSize += data.length;
          }
        }
      }
      
      // Get file cache size
      final fileCacheSize = await getCacheSize();
      
      return {
        'cachedBooks': bookIds.length,
        'sharedPrefsSizeBytes': sharedPrefSize,
        'sharedPrefsSizeMB': (sharedPrefSize / (1024 * 1024)).toStringAsFixed(2),
        'fileCacheSize': fileCacheSize,
      };
    } catch (e) {
      print('❌ Error getting cache stats: $e');
      return {
        'cachedBooks': 0,
        'sharedPrefsSizeBytes': 0,
        'sharedPrefsSizeMB': '0.00',
        'fileCacheSize': '0 MB',
      };
    }
  }
}
