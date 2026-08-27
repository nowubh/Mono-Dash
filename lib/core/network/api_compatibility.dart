import 'dart:collection';

import 'network_exceptions.dart';

typedef ApiVariantCall<T> = Future<T> Function();

class ApiEndpointVariant<T> {
  const ApiEndpointVariant({required this.name, required this.call});

  final String name;
  final ApiVariantCall<T> call;
}

class ApiCompatibility {
  const ApiCompatibility._();

  static final Map<Object, Map<String, String>> _variantCache =
      HashMap<Object, Map<String, String>>();

  static Future<T> tryVariants<T>(
    List<ApiEndpointVariant<T>> variants, {
    bool Function(Object error) shouldTryNext = isMissingEndpoint,
    Object? cacheScope,
    String? cacheKey,
  }) async {
    if (variants.isEmpty) {
      throw ArgumentError.value(variants, 'variants', 'must not be empty');
    }

    final orderedVariants = _orderedVariants(
      variants,
      cacheScope: cacheScope,
      cacheKey: cacheKey,
    );
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var i = 0; i < orderedVariants.length; i++) {
      try {
        final result = await orderedVariants[i].call();
        _rememberVariant(
          orderedVariants[i],
          cacheScope: cacheScope,
          cacheKey: cacheKey,
        );
        return result;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        final hasNext = i + 1 < orderedVariants.length;
        if (!hasNext || !shouldTryNext(error)) {
          rethrow;
        }
      }
    }

    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  static List<ApiEndpointVariant<T>> _orderedVariants<T>(
    List<ApiEndpointVariant<T>> variants, {
    required Object? cacheScope,
    required String? cacheKey,
  }) {
    if (cacheScope == null || cacheKey == null) return variants;
    final cachedName = _variantCache[cacheScope]?[cacheKey];
    if (cachedName == null) return variants;
    final cachedIndex = variants.indexWhere((variant) {
      return variant.name == cachedName;
    });
    if (cachedIndex <= 0) return variants;

    return [
      variants[cachedIndex],
      ...variants.take(cachedIndex),
      ...variants.skip(cachedIndex + 1),
    ];
  }

  static void _rememberVariant<T>(
    ApiEndpointVariant<T> variant, {
    required Object? cacheScope,
    required String? cacheKey,
  }) {
    if (cacheScope == null || cacheKey == null) return;
    final scopeCache = _variantCache.putIfAbsent(cacheScope, () => {});
    scopeCache[cacheKey] = variant.name;
  }

  static bool isMissingEndpoint(Object error) {
    if (error is AppNetworkException) {
      return error.statusCode == 404 || error.statusCode == 405;
    }
    return false;
  }
}
