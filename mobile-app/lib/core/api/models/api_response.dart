/// Generic API Response wrapper
///
/// All API responses from the backend follow this structure:
/// {
///   "success": true/false,
///   "message": "Optional message",
///   "data": { ... }
/// }
class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final String? error;
  final String? code;

  const ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.error,
    this.code,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      error: json['error'] as String?,
      code: json['code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (message != null) 'message': message,
      if (data != null) 'data': data,
      if (error != null) 'error': error,
      if (code != null) 'code': code,
    };
  }

  bool get isSuccess => success && error == null;
  bool get isError => !success || error != null;
}
