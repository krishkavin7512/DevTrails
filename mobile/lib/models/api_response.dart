class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final String? error;

  const ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.error,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) =>
      ApiResponse<T>(
        success: json['success'] ?? false,
        message: json['message'],
        data: json['data'] != null && fromJsonT != null
            ? fromJsonT(json['data'])
            : json['data'] as T?,
        error: json['error'],
      );
}

class PaginatedResponse<T> {
  final bool success;
  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int pages;

  const PaginatedResponse({
    required this.success,
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
    String itemsKey,
  ) {
    final rawList = json[itemsKey] as List? ?? [];
    final pagination =
        (json['pagination'] as Map<String, dynamic>?) ?? {};
    return PaginatedResponse<T>(
      success: json['success'] ?? false,
      items: rawList
          .map((e) => fromItem(e as Map<String, dynamic>))
          .toList(),
      page: (pagination['page'] ?? 1) as int,
      limit: (pagination['limit'] ?? 10) as int,
      total: (pagination['total'] ?? 0) as int,
      pages: (pagination['pages'] ?? 1) as int,
    );
  }

  bool get hasMore => page < pages;
}
