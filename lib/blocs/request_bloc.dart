/// RequestBloc handles the state management for rent requests in the app.
/// 
/// - Listens to events like [LoadRequest] and [RequestStatusUpdated].
/// - Interacts with [RentRequestService] to fetch and update request data.
/// - Uses [FirestoreService] to enforce business rules, e.g., updating equipment availability.
/// - Emits states such as [RequestLoading], [RequestLoaded], and [RequestError] to update the UI accordingly.

import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'request_event.dart';
import 'request_state.dart';
import '../../models/rent_request.dart';

import '../../services/rent_request_service.dart';

class RequestBloc extends Bloc<RequestEvent, RequestState> {
  final RentRequestService _requestService = RentRequestService();
  final FirestoreService _firebaseFirestore = FirestoreService();

  RequestBloc() : super(RequestLoading()) {
    on<LoadRequest>(_onLoadRequest);
    on<RequestStatusUpdated>(_onStatusUpdated);
  }

  Future<void> _onLoadRequest(
    LoadRequest event,
    Emitter<RequestState> emit,
  ) async {
    emit(RequestLoading());
    try {
      final request = await _requestService.getRequestById(event.requestId);
      emit(RequestLoaded(request));
    } catch (e) {
      emit(RequestError('Failed to load request: $e'));
    }
  }

  Future<void> _onStatusUpdated(
  RequestStatusUpdated event,
  Emitter<RequestState> emit,
) async {
  if (state is RequestLoaded) {
    final current = (state as RequestLoaded).request;

    try {
      // Persist and get the updated request
      final updated = await _requestService.updateRequestStatus(
        requestId: current.requestId,
        status: event.status,
      );
      emit(RequestLoaded(updated));


      // 🔥 Business rules
      if (event.status == RentRequestStatus.approved) {
        await _firebaseFirestore.setAvailability(current.itemId, false);
      } else if (event.status == RentRequestStatus.completed) {
        await _firebaseFirestore.setAvailability(current.itemId, true);
      }

      // Emit the persisted version
      emit(RequestLoaded(updated));
    } catch (e) {
      emit(RequestError('Failed to update request: $e'));
    }
  }
}

}
