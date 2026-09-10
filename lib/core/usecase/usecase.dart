import 'package:dartz/dartz.dart';

import '../error/failures.dart';

/// Contract every use case in `domain/usecases` implements.
/// [SuccessType] is the success return type, [Params] the input.
abstract class UseCase<SuccessType, Params> {
  Future<Either<Failure, SuccessType>> call(Params params);
}

/// For use cases that take no parameters.
class NoParams {
  const NoParams();
}
