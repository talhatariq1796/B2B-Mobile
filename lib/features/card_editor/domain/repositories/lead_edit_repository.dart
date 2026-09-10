import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';

/// Fields the reviewer can correct before creating the agency. Names match
/// this app's own field names (see [Lead]) — the data layer maps them
/// to the backend's `snake_case` field names.
class LeadEditFields {
  const LeadEditFields({
    required this.agencyName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.mobilePhone,
    required this.mobilePhone2,
    required this.landlinePhone,
    required this.landlinePhone2,
    required this.faxPhone,
    required this.agencyWebsite,
    required this.address,
    required this.country,
  });

  final String agencyName;
  final String firstName;
  final String lastName;
  final String email;
  final String mobilePhone;
  final String mobilePhone2;
  final String landlinePhone;
  final String landlinePhone2;
  final String faxPhone;
  final String agencyWebsite;
  final String address;
  final String country;
}

/// Domain-facing contract for PATCH /api/leads/{id}/ ("Save corrections").
abstract class LeadEditRepository {
  Future<Either<Failure, Unit>> updateLead({
    required String backendLeadId,
    required LeadEditFields fields,
  });
}
