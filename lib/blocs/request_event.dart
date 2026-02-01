/// Defines the events for [RequestBloc] used in rent request state management.
///
/// Events represent user or system actions that can trigger state changes:
/// 
/// - [LoadRequest]: Triggered to load a specific rent request by its ID.
/// - [RequestStatusUpdated]: Triggered when the status of a request is updated
///   (e.g., approved, completed), carrying both the request ID and the new status.
///
/// These events are processed by [RequestBloc] to fetch data or update the backend,
/// and ultimately update the UI via emitted states.


import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:equatable/equatable.dart';

abstract class RequestEvent extends Equatable {
  const RequestEvent();

  @override
  List<Object?> get props => [];
}

class LoadRequest extends RequestEvent {
  final String requestId;

  const LoadRequest(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

class RequestStatusUpdated extends RequestEvent {
  final String requestId;
  final RentRequestStatus status;

  const RequestStatusUpdated(this.requestId, this.status);

  @override
  List<Object?> get props => [requestId, status];
}

