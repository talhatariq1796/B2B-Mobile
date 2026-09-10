import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/lead_extraction_repository.dart';
import '../datasources/lead_extraction_remote_data_source.dart';

class LeadExtractionRepositoryImpl implements LeadExtractionRepository {
  LeadExtractionRepositoryImpl(this._remote);

  final LeadExtractionRemoteDataSource _remote;

  @override
  Future<Either<Failure, LeadExtractionResult>> extractCard({
    required String imagePath,
    String? backImagePath,
  }) async {
    try {
      final result = await _remote.extractCard(
        imagePath: imagePath,
        backImagePath: backImagePath,
      );
      return Right(result);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on AmbiguousOutcomeException catch (e) {
      return Left(AmbiguousOutcomeFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }
}
