import 'package:bukidbayan_app/blocs/request_bloc.dart';
import 'package:bukidbayan_app/blocs/request_event.dart';
import 'package:bukidbayan_app/blocs/request_state.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class SubmitButton extends StatelessWidget {
  final bool isStep2Complete;
  final DateTime startDate;
  final DateTime returnDate;
  final String name;
  final String address;
  final XFile? landSizeProof;
  final XFile? cropHeightProof;
  final Equipment item;
  final RentRequestService requestService;

  const SubmitButton({
    super.key,
    required this.isStep2Complete,
    required this.startDate,
    required this.returnDate,
    required this.name,
    required this.address,
    this.landSizeProof,
    this.cropHeightProof,
    required this.item,
    required this.requestService,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: OutlinedButton(
        onPressed: () async {
          if (!isStep2Complete) {
            showErrorSnackbar(
              context: context,
              title: 'Incomplete',
              message: 'Please complete all required fields',
            );
            return;
          }

          String? landPath;
          String? cropPath;

          if (landSizeProof != null) landPath = await requestService.saveFileLocally(landSizeProof!);
          if (cropHeightProof != null) cropPath = await requestService.saveFileLocally(cropHeightProof!);

          final currentUserId = FirebaseAuth.instance.currentUser!.uid;

          final request = RentRequest(
            requestId: '',
            itemId: item.id ?? 'Unknown',
            itemName: item.name,
            name: name,
            address: address,
            start: startDate,
            end: returnDate,
            landSizeProofPath: landPath,
            cropHeightProofPath: cropPath,
            status: RentRequestStatus.pending,
            renterId: currentUserId,
            ownerId: item.ownerId,
          );

          final newRequestId = await requestService.saveRequest(request);

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent!')));

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => RequestBloc()..add(LoadRequest(newRequestId)),
                child: BlocBuilder<RequestBloc, RequestState>(
                  builder: (context, state) {
                    if (state is RequestLoaded) {
                      return RequestSentPage(requestId: newRequestId);
                    } else if (state is RequestLoading) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    } else if (state is RequestError) {
                      return Scaffold(body: Center(child: Text('Error: ${state.message}')));
                    } else {
                      return const Scaffold(body: Center(child: Text('Unknown state')));
                    }
                  },
                ),
              ),
            ),
          );
        },
        child: Text('Submit', style: TextStyle(color: lightColorScheme.primary, fontSize: 16)),
      ),
    );
  }
}
