import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/lead_submit_repository.dart';
import '../datasources/lead_submit_remote_data_source.dart';

class LeadSubmitRepositoryImpl implements LeadSubmitRepository {
  LeadSubmitRepositoryImpl(this._remote);

  final LeadSubmitRemoteDataSource _remote;

  @override
  Future<Either<Failure, LeadSubmitResult>> submit({
    required String backendLeadId,
    required LeadSubmitFields fields,
  }) async {
    try {
      final result = await _remote.submit(backendLeadId: backendLeadId, fields: fields);
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

  @override
  Future<Either<Failure, Unit>> submitAll() async {
    try {
      await _remote.submitAll();
      return const Right(unit);
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
