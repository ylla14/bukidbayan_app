import 'dart:async';

import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    await _requestSubscription?.cancel();
    try {
      _requestSubscription =
          _requestService.requestStream(event.requestId).listen((request) {
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
        // 1. Persist status update
        await _requestService.updateRequestStatus(
          requestId: current.requestId,
          status: event.status,
          declineReason: event.declineReason,
        );

        // 2. Update equipment availability
        await _firestoreService
            .validateEquipmentAvailabilityWithNotification(current.itemId);

        // 3. Send notifications to the relevant party
        await _sendStatusNotifications(
          request: current,
          newStatus: event.status,
          declineReason: event.declineReason,
        );
      } catch (e) {
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

  // ─────────────────────────────────────────────────────────────────────────
  // Notification dispatch — one method per status transition
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _sendStatusNotifications({
    required RentRequest request,
    required RentRequestStatus newStatus,
    String? declineReason,
  }) async {
    final item = request.itemName;
    final renter = request.name; // renter's display name

    switch (newStatus) {
      // ── Owner approved → notify RENTER ──────────────────────────────────
      case RentRequestStatus.approved:
        await _notify(
          userId: request.renterId,
          title: '✅ Request Approved!',
          body:
              'Your rental request for "$item" has been approved. Get ready for your rental!',
          type: 'request_approved',
          extra: {'requestId': request.requestId},
        );
        break;

      // ── Owner declined → notify RENTER ──────────────────────────────────
      case RentRequestStatus.declined:
        await _notify(
          userId: request.renterId,
          title: 'Request Declined',
          body: declineReason != null
              ? 'Your rental request for "$item" was declined. Reason: $declineReason'
              : 'Your rental request for "$item" was declined by the owner.',
          type: 'request_declined',
          extra: {'requestId': request.requestId},
        );
        break;

      // ── Either party cancelled → notify the OTHER party ─────────────────
      case RentRequestStatus.canceled:
        // Notify renter (owner cancelled) AND owner (renter cancelled).
        // We send to both — each will only see their own notification feed.
        await Future.wait([
          _notify(
            userId: request.renterId,
            title: 'Request Cancelled',
            body: 'Your rental request for "$item" has been cancelled.',
            type: 'request_canceled',
            extra: {'requestId': request.requestId},
          ),
          _notify(
            userId: request.ownerId,
            title: 'Request Cancelled',
            body: 'The rental request for "$item" from $renter has been cancelled.',
            type: 'request_canceled',
            extra: {'requestId': request.requestId},
          ),
        ]);
        break;

      // ── Owner marks ready for pickup → notify RENTER ────────────────────
      case RentRequestStatus.readyForPickup:
        await _notify(
          userId: request.renterId,
          title: 'Equipment Ready for Pick Up',
          body:
              '"$item" is ready for collection. Head over to the owner\'s location to pick it up.',
          type: 'ready_for_pickup',
          extra: {'requestId': request.requestId},
        );
        break;

      // ── Renter picked up (owner confirmed) → notify RENTER ──────────────
      case RentRequestStatus.pickedUp:
        await _notify(
          userId: request.renterId,
          title: 'Pick Up Confirmed',
          body:
              'The owner has confirmed your pick up of "$item". Your rental is now active!',
          type: 'picked_up',
          extra: {'requestId': request.requestId},
        );
        break;

      // ── Owner marks on the way (delivery) → notify RENTER ───────────────
      case RentRequestStatus.onTheWay:
        await _notify(
          userId: request.renterId,
          title: 'Equipment On The Way',
          body:
              '"$item" is on its way to you. Please confirm receipt once it arrives.',
          type: 'on_the_way',
          extra: {'requestId': request.requestId},
        );
        break;

      // ── Renter confirms receipt → rental active → notify OWNER ──────────
      case RentRequestStatus.inProgress:
        await _notify(
          userId: request.ownerId,
          title: 'Rental Now Active',
          body: '$renter has confirmed receipt of "$item". Rental is in progress.',
          type: 'rental_in_progress',
          extra: {'requestId': request.requestId},
        );
        break;

      // ── Owner heading out to retrieve (overdue) → notify RENTER ─────────
      case RentRequestStatus.retrieving:
        await _notify(
          userId: request.renterId,
          title: 'Owner Is On The Way',
          body:
              'The owner is coming to retrieve "$item". Please have it ready for return.',
          type: 'retrieving',
          extra: {'requestId': request.requestId},
        );
        break;

      // ── Renter returns equipment → notify OWNER ──────────────────────────
      case RentRequestStatus.returned:
        await _notify(
          userId: request.ownerId,
          title: 'Equipment Returned',
          body:
              '$renter has marked "$item" as returned. Please confirm the return.',
          type: 'equipment_returned',
          extra: {'requestId': request.requestId},
        );
        break;

      // ── Owner confirms return/retrieval → notify RENTER ─────────────────
      case RentRequestStatus.finished:
        await _notify(
          userId: request.renterId,
          title: 'Rental Finished',
          body:
              'The owner has confirmed the return of "$item". Almost done — awaiting final completion.',
          type: 'rental_finished',
          extra: {'requestId': request.requestId},
        );
        break;

      // ── Owner confirms completion → notify RENTER (leave a review!) ──────
      case RentRequestStatus.completed:
        await Future.wait([
          _notify(
            userId: request.renterId,
            title: 'Rental Completed!',
            body:
                'Your rental of "$item" is complete. We\'d love to hear your feedback — leave a review!',
            type: 'rental_completed',
            extra: {'requestId': request.requestId},
          ),
          _notify(
            userId: request.ownerId,
            title: 'Rental Completed',
            body:
                'The rental of "$item" with $renter has been completed successfully.',
            type: 'rental_completed',
            extra: {'requestId': request.requestId},
          ),
        ]);
        break;

      // ── No notification needed for these (intermediate/internal states) ──
      case RentRequestStatus.pending:
        // A new request is created elsewhere; no transition notification here.
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Firestore notification writer
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _notify({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .add({
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        ...extra,
      });
    } catch (e) {
      // Non-fatal — log but don't crash the bloc
      print('⚠️ Failed to send notification to $userId: $e');
    }
  }
}

/// Private event used internally to update the state from the Firestore listener
class _RequestUpdated extends RequestEvent {
  final RentRequest request;
  _RequestUpdated(this.request);

  @override
  List<Object?> get props => [request];
}