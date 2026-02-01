/// Defines the states for [RequestBloc] used in rent request management.
///
/// States represent the current status of a rent request in the UI:
///
/// - [RequestLoading]: Indicates that a request is being fetched or processed.
/// - [RequestLoaded]: Carries a [RentRequest] object when the request data has been successfully loaded.
/// - [RequestError]: Carries an error message when there is a failure in loading or updating a request.
///
/// These states are emitted by [RequestBloc] in response to events to update the UI accordingly.


import 'package:equatable/equatable.dart';
import '../../models/rent_request.dart';

abstract class RequestState extends Equatable {
  const RequestState();

  @override
  List<Object?> get props => [];
}

class RequestLoading extends RequestState {}

class RequestLoaded extends RequestState {
  final RentRequest request;

  const RequestLoaded(this.request);

  @override
  List<Object?> get props => [request];
}

class RequestError extends RequestState {
  final String message;

  const RequestError(this.message);

  @override
  List<Object?> get props => [message];
}
