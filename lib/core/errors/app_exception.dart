sealed class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => '[$code] $message';
}

final class NetworkException extends AppException {
  const NetworkException([
    super.message =
        'No internet connection. Please check your network and try again.',
  ]) : super(code: 'NETWORK_ERROR');
}

final class TimeoutException extends AppException {
  const TimeoutException(
      [super.message = 'Request timed out. Please try again.'])
      : super(code: 'TIMEOUT');
}

final class ServerException extends AppException {
  const ServerException(
    super.message, {
    required this.statusCode,
    String? code,
  }) : super(code: code ?? 'SERVER_ERROR');

  final int statusCode;
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException(
      [super.message = 'Session expired. Please log in again.'])
      : super(code: 'UNAUTHORIZED');
}

final class ParseException extends AppException {
  const ParseException(
      [super.message = 'Failed to process server response.'])
      : super(code: 'PARSE_ERROR');
}

final class ValidationException extends AppException {
  const ValidationException(super.message) : super(code: 'VALIDATION_ERROR');
}

final class UnknownException extends AppException {
  const UnknownException(
      [super.message = 'An unexpected error occurred. Please try again.'])
      : super(code: 'UNKNOWN');
}
