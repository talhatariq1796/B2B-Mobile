import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/lead.dart';
import '../../domain/repositories/lead_list_repository.dart';
import '../datasources/lead_list_remote_data_source.dart';

class LeadListRepositoryImpl implements LeadListRepository {
  LeadListRepositoryImpl(this._remote);

  final LeadListRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Lead>>> getLeads() async {
    try {
      final leads = await _remote.getLeads();
      return Right(leads);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }

  @override
  Future<Either<Failure, LeadExportFile>> exportToExcel() async {
    try {
      final file = await _remote.exportToExcel();
      return Right(file);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } catch (_) {
      return const Left(UnknownFailure());
    }
  }
}
