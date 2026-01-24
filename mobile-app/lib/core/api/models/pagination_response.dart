/// Pagination metadata for paginated API responses
class PaginationMeta {
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  const PaginationMeta({
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? json['pageSize'] as int? ?? 20,
      totalItems:
          json['total_items'] as int? ?? json['totalItems'] as int? ?? 0,
      totalPages:
          json['total_pages'] as int? ?? json['totalPages'] as int? ?? 0,
      hasNext: json['has_next'] as bool? ?? json['hasNext'] as bool? ?? false,
      hasPrevious:
          json['has_previous'] as bool? ??
          json['hasPrevious'] as bool? ??
          false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'page_size': pageSize,
      'total_items': totalItems,
      'total_pages': totalPages,
      'has_next': hasNext,
      'has_previous': hasPrevious,
    };
  }
}

/// Paginated API Response
class PaginatedResponse<T> {
  final List<T> items;
  final PaginationMeta meta;

  const PaginatedResponse({required this.items, required this.meta});

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    final data = json['data'] ?? json;
    final items =
        (data['items'] as List<dynamic>? ??
                data['results'] as List<dynamic>? ??
                data['data'] as List<dynamic>? ??
                [])
            .map((item) => fromJsonT(item))
            .toList();

    final meta = data['meta'] != null
        ? PaginationMeta.fromJson(data['meta'] as Map<String, dynamic>)
        : PaginationMeta(
            page: data['page'] as int? ?? 1,
            pageSize:
                data['page_size'] as int? ?? data['pageSize'] as int? ?? 20,
            totalItems: items.length,
            totalPages: 1,
            hasNext: false,
            hasPrevious: false,
          );

    return PaginatedResponse<T>(items: items, meta: meta);
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'items': items.map((item) => toJsonT(item)).toList(),
      'meta': meta.toJson(),
    };
  }
}
