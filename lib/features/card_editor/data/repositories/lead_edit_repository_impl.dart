import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/repositories/lead_edit_repository.dart';
import '../datasources/lead_edit_remote_data_source.dart';

class LeadEditRepositoryImpl implements LeadEditRepository {
  LeadEditRepositoryImpl(this._remote);

  final LeadEditRemoteDataSource _remote;

  @override
  Future<Either<Failure, Unit>> updateLead({
    required String backendLeadId,
    required LeadEditFields fields,
  }) async {
    try {
      await _remote.updateLead(backendLeadId: backendLeadId, fields: fields);
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
