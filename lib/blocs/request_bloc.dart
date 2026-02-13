// import 'dart:async';

// import 'package:bukidbayan_app/services/firestore_service.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'request_event.dart';
// import 'request_state.dart';
// import '../../models/rent_request.dart';
// import '../../services/rent_request_service.dart';

// class RequestBloc extends Bloc<RequestEvent, RequestState> {
//   final RentRequestService _requestService = RentRequestService();
//   final FirestoreService _firebaseFirestore = FirestoreService();

//   StreamSubscription<RentRequest>? _requestSubscription;

//   RequestBloc() : super(RequestLoading()) {
//     on<LoadRequest>(_onLoadRequest);
//     on<RequestStatusUpdated>(_onStatusUpdated);
//     on<_RequestUpdated>(_onRequestUpdated);
//   }

//   Future<void> _onLoadRequest(
//     LoadRequest event,
//     Emitter<RequestState> emit,
//   ) async {
//     emit(RequestLoading());

//     // Cancel any existing subscription
//     await _requestSubscription?.cancel();

//     try {
//       // Listen to the Firestore document in real-time
//       _requestSubscription = _requestService
//           .requestStream(event.requestId)
//           .listen((request) {
//         add(_RequestUpdated(request));
//       });
//     } catch (e) {
//       emit(RequestError('Failed to load request: $e'));
//     }
//   }

//   Future<void> _onStatusUpdated(
//     RequestStatusUpdated event,
//     Emitter<RequestState> emit,
//   ) async {
//     if (state is RequestLoaded) {
//       final current = (state as RequestLoaded).request;

//       try {
//         // Persist the status update
//         final updated = await _requestService.updateRequestStatus(
//           requestId: current.requestId,
//           status: event.status,
//         );

//         // 🔥 Business rules: update equipment availability
//         if (event.status == RentRequestStatus.approved ||
//             event.status == RentRequestStatus.onTheWay ||
//             event.status == RentRequestStatus.inProgress ||
//             event.status == RentRequestStatus.returned) {
//           await _firebaseFirestore.setAvailability(current.itemId, false);
//         } else if (event.status == RentRequestStatus.finished ||
//                    event.status == RentRequestStatus.completed) {
//           await _firebaseFirestore.setAvailability(current.itemId, true);
//         }

//         // No need to emit manually — snapshot listener will update state
//       } catch (e) {
//         emit(RequestError('Failed to update request: $e'));
//       }
//     }
//   }

//   Future<void> _onRequestUpdated(
//     _RequestUpdated event,
//     Emitter<RequestState> emit,
//   ) async {
//     emit(RequestLoaded(event.request));
//   }

//   @override
//   Future<void> close() {
//     _requestSubscription?.cancel();
//     return super.close();
//   }
// }

// /// Private event used internally to update the state from the Firestore listener
// class _RequestUpdated extends RequestEvent {
//   final RentRequest request;
//   _RequestUpdated(this.request);

//   @override
//   List<Object?> get props => [request];
// }


import 'dart:async';

import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'request_event.dart';
import 'request_state.dart';
import '../../models/rent_request.dart';
import '../../services/rent_request_service.dart';

class RequestBloc extends Bloc<RequestEvent, RequestState> {
  final RentRequestService _requestService = RentRequestService();
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<RentRequest>? _requestSubscription;

  RequestBloc() : super(RequestLoading()) {
    on<LoadRequest>(_onLoadRequest);
    on<RequestStatusUpdated>(_onStatusUpdated);
    on<_RequestUpdated>(_onRequestUpdated);
  }

  Future<void> _onLoadRequest(
    LoadRequest event,
    Emitter<RequestState> emit,
  ) async {
    emit(RequestLoading());

    // Cancel any existing subscription
    await _requestSubscription?.cancel();

    try {
      // Listen to the Firestore document in real-time
      _requestSubscription = _requestService
          .requestStream(event.requestId)
          .listen((request) {
        add(_RequestUpdated(request));
      });
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
      print('🔄 Updating request status to: ${event.status.name}');
      
      // Persist the status update
      final updated = await _requestService.updateRequestStatus(
        requestId: current.requestId,
        status: event.status,
      );

      print('✅ Request status updated, now validating equipment availability');

      // ✅ Update equipment availability with notification
      await _firestoreService.validateEquipmentAvailabilityWithNotification(current.itemId);

      print('✅ Equipment availability validated');

      // No need to emit manually — snapshot listener will update state
    } catch (e) {
      print('❌ Error in _onStatusUpdated: $e');
      emit(RequestError('Failed to update request: $e'));
    }
  }
}

  Future<void> _onRequestUpdated(
    _RequestUpdated event,
    Emitter<RequestState> emit,
  ) async {
    emit(RequestLoaded(event.request));
  }

  @override
  Future<void> close() {
    _requestSubscription?.cancel();
    return super.close();
  }
}

/// Private event used internally to update the state from the Firestore listener
class _RequestUpdated extends RequestEvent {
  final RentRequest request;
  _RequestUpdated(this.request);

  @override
  List<Object?> get props => [request];
}