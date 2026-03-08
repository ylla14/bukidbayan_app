import 'package:bukidbayan_app/widgets/sign_button.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/screens/auth/signin_screen.dart';
import 'package:bukidbayan_app/screens/location_picker_screen.dart';

import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_scaffold.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formSignInKey = GlobalKey<FormState>();
  bool rememberPassword = true;
  final AuthService authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  bool _isPasswordHidden = true;
  bool _isSigningUp = false;

  // Coordinates set when the user picks a location from the map.
  // If set and the address text hasn't changed since, we skip re-geocoding.
  double? _pickedLat;
  double? _pickedLng;
  String? _pickedAddress;

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        addressController.text = result.address;
        _pickedLat     = result.latitude;
        _pickedLng     = result.longitude;
        _pickedAddress = result.address;
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    addressController.dispose();
    super.dispose();
  }

  // Reusable border helper
  OutlineInputBorder _border({Color color = Colors.black12, double width = 1.5, double radius = 14}) {
    return OutlineInputBorder(
      borderSide: BorderSide(color: color, width: width),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            // margin: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            // decoration: BoxDecoration(
            //   color: Colors.white,
            //   borderRadius: BorderRadius.all(Radius.circular(20)),
            // ),

            child: Form(
              key: _formSignInKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // ── App Icon / Logo Area ──────────────────────────────────
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: lightColorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 44,
                      color: lightColorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Heading ───────────────────────────────────────────────
                  Text(
                    'Welcome!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 32.0,
                      color: lightColorScheme.primary,
                      letterSpacing: 0.2,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Create your account to get started',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17.0,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── First Name + Last Name ────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'First Name',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: firstNameController,
                              style: const TextStyle(fontSize: 17),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'First name',
                                hintStyle: const TextStyle(color: Colors.black38, fontSize: 16),
                                prefixIcon: Icon(
                                  Icons.badge_outlined,
                                  color: lightColorScheme.primary,
                                  size: 22,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: _border(),
                                enabledBorder: _border(),
                                focusedBorder: _border(color: lightColorScheme.primary, width: 2),
                                errorBorder: _border(color: Colors.redAccent),
                                focusedErrorBorder: _border(color: Colors.redAccent, width: 2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Last Name',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: lastNameController,
                              style: const TextStyle(fontSize: 17),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'Last name',
                                hintStyle: const TextStyle(color: Colors.black38, fontSize: 16),
                                prefixIcon: Icon(
                                  Icons.badge_outlined,
                                  color: lightColorScheme.primary,
                                  size: 22,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: _border(),
                                enabledBorder: _border(),
                                focusedBorder: _border(color: lightColorScheme.primary, width: 2),
                                errorBorder: _border(color: Colors.redAccent),
                                focusedErrorBorder: _border(color: Colors.redAccent, width: 2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Email Field ───────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email Address',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 17),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter your email',
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 16),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: lightColorScheme.primary,
                        size: 24,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: _border(),
                      enabledBorder: _border(),
                      focusedBorder: _border(color: lightColorScheme.primary, width: 2),
                      errorBorder: _border(color: Colors.redAccent),
                      focusedErrorBorder: _border(color: Colors.redAccent, width: 2),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Password Field ────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: passwordController,
                        obscureText: _isPasswordHidden,
                        obscuringCharacter: '*',
                        style: const TextStyle(fontSize: 17),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          hintStyle: const TextStyle(color: Colors.black38, fontSize: 16),
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: lightColorScheme.primary,
                            size: 24,
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: IconButton(
                              iconSize: 26,
                              icon: Icon(
                                _isPasswordHidden
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.black45,
                              ),
                              tooltip: _isPasswordHidden ? 'Show password' : 'Hide password',
                              onPressed: () {
                                setState(() {
                                  _isPasswordHidden = !_isPasswordHidden;
                                });
                              },
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: _border(),
                          enabledBorder: _border(),
                          focusedBorder: _border(color: lightColorScheme.primary, width: 2),
                          errorBorder: _border(color: Colors.redAccent),
                          focusedErrorBorder: _border(color: Colors.redAccent, width: 2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '• Minimum of 6 characters\n'
                                '• Avoid common passwords (e.g. "123456", "password", birthdays, etc..)',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Address Field ─────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Address',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: addressController,
                    style: const TextStyle(fontSize: 17),
                    onChanged: (_) {
                      // If the user edits the address manually after picking
                      // from the map, clear the stored coordinates so we
                      // re-geocode the typed text on submit.
                      if (_pickedAddress != null &&
                          addressController.text != _pickedAddress) {
                        _pickedLat = null;
                        _pickedLng = null;
                        _pickedAddress = null;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your address or pick from the map';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Type address or pick on map',
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 16),
                      prefixIcon: Icon(
                        Icons.location_on_outlined,
                        color: lightColorScheme.primary,
                        size: 24,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: IconButton(
                          iconSize: 26,
                          icon: Icon(
                            Icons.map_outlined,
                            color: lightColorScheme.primary,
                          ),
                          tooltip: 'Pick location on map',
                          onPressed: _openLocationPicker,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: _border(),
                      enabledBorder: _border(),
                      focusedBorder: _border(color: lightColorScheme.primary, width: 2),
                      errorBorder: _border(color: Colors.redAccent),
                      focusedErrorBorder: _border(color: Colors.redAccent, width: 2),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Sign Up Button ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: SignButton(
                      buttonText: _isSigningUp ? 'Signing Up...' : 'Sign Up',
                      onPressed: _isSigningUp
                          ? null
                          : () async {
                              if (_formSignInKey.currentState!.validate()) {
                                setState(() => _isSigningUp = true);

                                try {
                                  final address = addressController.text.trim();

                                  // Use map-picked coordinates directly if available,
                                  // otherwise geocode the typed address via Nominatim.
                                  double lat, lng;
                                  if (_pickedLat != null && address == _pickedAddress) {
                                    lat = _pickedLat!;
                                    lng = _pickedLng!;
                                  } else {
                                    final coords = await authService.validateAndGeocodeAddress(address);
                                    lat = coords['latitude']!;
                                    lng = coords['longitude']!;
                                  }

                                  await authService.signUp(
                                    emailController.text,
                                    passwordController.text,
                                    firstNameController.text,
                                    lastNameController.text,
                                    address,
                                    lat,
                                    lng,
                                  );

                                  if (!mounted) return;
                                  showConfirmSnackbar(context: context, title: 'Success', message: 'Account Created Successfully!');
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (e) => const SignInScreen()),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() => _isSigningUp = false);
                                  showErrorSnackbar(context: context, title: 'Error', message: e.toString().replaceAll('Exception: ', ''));
                                }
                              }
                            },
                    ),
                  ),

                  const SizedBox(height: 28.0),

                  // ── Divider ───────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.black12, thickness: 1.2)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Already registered?',
                          style: TextStyle(color: Colors.black38, fontSize: 14),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.black12, thickness: 1.2)),
                    ],
                  ),

                  const SizedBox(height: 20.0),

                  // ── Sign In Link ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (e) => const SignInScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: lightColorScheme.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: lightColorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// //import 'package:bukidbayan_app/widgets/sign_button.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';

// import 'package:bukidbayan_app/services/auth_services.dart';
// import 'package:bukidbayan_app/screens/auth/signin_screen.dart';
// import 'package:bukidbayan_app/screens/auth/otp_screen.dart'; // create this screen for OTP entry
// import 'package:bukidbayan_app/theme/theme.dart';
// import 'package:bukidbayan_app/widgets/custom_scaffold.dart';
// import 'package:bukidbayan_app/widgets/custom_snackbars.dart';

// // Location type options — feel free to localise the labels
// const List<Map<String, dynamic>> _locationTypes = [
//   {'value': 'Home',             'label': 'Home',             'icon': Icons.home_rounded},
//   {'value': 'Farm',             'label': 'Farm / Field',     'icon': Icons.grass_rounded},
//   {'value': 'Business',         'label': 'Business',         'icon': Icons.store_rounded},
//   {'value': 'Current Location', 'label': 'Current Location', 'icon': Icons.my_location_rounded},
// ];

// class SignUpScreen extends StatefulWidget {
//   const SignUpScreen({super.key});

//   @override
//   State<SignUpScreen> createState() => _SignUpScreenState();
// }

// class _SignUpScreenState extends State<SignUpScreen> {
//   final _formKey        = GlobalKey<FormState>();
//   final AuthService authService = AuthService();

//   // Controllers
//   final _firstNameController  = TextEditingController();
//   final _lastNameController   = TextEditingController();
//   final _phoneController      = TextEditingController(); // digits only, no country code
//   final _addressController    = TextEditingController();

//   String _selectedLocationType = 'Home';
//   double? _latitude;
//   double? _longitude;

//   bool _isFetchingLocation = false;
//   bool _isSendingOtp       = false;

//   // ── Philippines country code prefix shown in UI ───────────────────────────
//   static const String _countryCode = '+63';

//   @override
//   void dispose() {
//     _firstNameController.dispose();
//     _lastNameController.dispose();
//     _phoneController.dispose();
//     _addressController.dispose();
//     super.dispose();
//   }

//   // ── Location helpers ──────────────────────────────────────────────────────

//   Future<void> _fetchCurrentLocation() async {
//     setState(() => _isFetchingLocation = true);
//     try {
//       // Permission check
//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//       }
//       if (permission == LocationPermission.deniedForever ||
//           permission == LocationPermission.denied) {
//         throw Exception('Location permission denied.');
//       }

//       final pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       _latitude  = pos.latitude;
//       _longitude = pos.longitude;

//       // Reverse geocode → human-readable address
//       final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
//       if (placemarks.isNotEmpty) {
//         final p = placemarks.first;
//         final parts = [
//           p.street,
//           p.subLocality,
//           p.locality,
//           p.administrativeArea,
//         ].where((s) => s != null && s.isNotEmpty).toList();
//         _addressController.text = parts.join(', ');
//       }

//       setState(() {});
//     } catch (e) {
//       if (mounted) {
//         showErrorSnackbar(
//           context: context,
//           title: 'Location Error',
//           message: e.toString().replaceAll('Exception: ', ''),
//         );
//       }
//     } finally {
//       if (mounted) setState(() => _isFetchingLocation = false);
//     }
//   }

//   // ── Form submit ───────────────────────────────────────────────────────────

//   Future<void> _onSignUp() async {
//     if (!_formKey.currentState!.validate()) return;

//     // Build E.164 phone number: +63 + strip leading zero if present
//     final rawPhone = _phoneController.text.trim();
//     final normalised = rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
//     final fullPhone = '$_countryCode$normalised';

//     setState(() => _isSendingOtp = true);

//     await authService.sendOtp(
//       phoneNumber: fullPhone,
//       onCodeSent: (verificationId) {
//         if (!mounted) return;
//         setState(() => _isSendingOtp = false);
//         // Navigate to OTP screen passing all the data we need after verification
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => OtpScreen(
//               verificationId:   verificationId,
//               phoneNumber:      fullPhone,
//               firstName:        _firstNameController.text.trim(),
//               lastName:         _lastNameController.text.trim(),
//               address:          _addressController.text.trim(),
//               locationType:     _selectedLocationType,
//               latitude:         _latitude,
//               longitude:        _longitude,
//             ),
//           ),
//         );
//       },
//       onError: (error) {
//         if (!mounted) return;
//         setState(() => _isSendingOtp = false);
//         showErrorSnackbar(context: context, title: 'Error', message: error);
//       },
//     );
//   }

//   // ── Build

//   @override
//   Widget build(BuildContext context) {
//     return CustomScaffold(
//       child: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.fromLTRB(30.0, 0.0, 30.0, 30.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Text(
//                   'Welcome!',
//                   style: TextStyle(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 30.0,
//                     color: lightColorScheme.primary,
//                   ),
//                 ),

//                 const SizedBox(height: 40),

//                 // ── First & Last Name ──────────────────────────────────────
//                 Row(
//                   children: [
//                     Expanded(child: _buildField(
//                       controller: _firstNameController,
//                       label: 'First Name',
//                       hint: 'Juan',
//                       validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
//                     )),
//                     const SizedBox(width: 10),
//                     Expanded(child: _buildField(
//                       controller: _lastNameController,
//                       label: 'Last Name',
//                       hint: 'Dela Cruz',
//                       validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
//                     )),
//                   ],
//                 ),

//                 const SizedBox(height: 25),

//                 // ── Phone Number ──────────────────────────────────────────
//                 TextFormField(
//                   controller: _phoneController,
//                   keyboardType: TextInputType.phone,
//                   inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                   validator: (v) {
//                     if (v == null || v.isEmpty) return 'Please enter your phone number';
//                     // PH mobile: 10 digits (09XXXXXXXXX) or 9 digits after stripping leading 0
//                     final stripped = v.startsWith('0') ? v.substring(1) : v;
//                     if (stripped.length != 9 && stripped.length != 10) {
//                       return 'Enter a valid PH mobile number';
//                     }
//                     return null;
//                   },
//                   decoration: _inputDecoration(
//                     label: 'Phone Number',
//                     hint: '09XX XXX XXXX',
//                     prefixWidget: Container(
//                       margin: const EdgeInsets.only(right: 8),
//                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
//                       decoration: BoxDecoration(
//                         border: Border(right: BorderSide(color: Colors.black12)),
//                       ),
//                       child: Text(
//                         _countryCode,
//                         style: const TextStyle(
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black54,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),

//                 const SizedBox(height: 8),

//                 Align(
//                   alignment: Alignment.centerLeft,
//                   child: Text(
//                     'We will send a one-time code (OTP) to verify your number.',
//                     style: TextStyle(fontSize: 12, color: Colors.black45),
//                   ),
//                 ),

//                 const SizedBox(height: 25),

//                 // ── Location Type ─────────────────────────────────────────
//                 Align(
//                   alignment: Alignment.centerLeft,
//                   child: Text(
//                     'Location Type',
//                     style: TextStyle(
//                       fontWeight: FontWeight.w600,
//                       color: Colors.black54,
//                       fontSize: 13,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 _buildLocationTypeSelector(),

//                 const SizedBox(height: 20),

//                 // ── Address field ─────────────────────────────────────────
//                 TextFormField(
//                   controller: _addressController,
//                   maxLines: 2,
//                   validator: (v) => (v == null || v.isEmpty) ? 'Please enter your address' : null,
//                   decoration: _inputDecoration(
//                     label: 'Address',
//                     hint: 'Purok 3, Barangay Poblacion...',
//                     suffixWidget: _isFetchingLocation
//                         ? const Padding(
//                             padding: EdgeInsets.all(12),
//                             child: SizedBox(
//                               width: 18, height: 18,
//                               child: CircularProgressIndicator(strokeWidth: 2),
//                             ),
//                           )
//                         : IconButton(
//                             tooltip: 'Use my current location',
//                             icon: const Icon(Icons.my_location_rounded, color: Colors.black45),
//                             onPressed: () {
//                               setState(() => _selectedLocationType = 'Current Location');
//                               _fetchCurrentLocation();
//                             },
//                           ),
//                   ),
//                 ),

//                 if (_latitude != null && _longitude != null) ...[
//                   const SizedBox(height: 6),
//                   Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text(
//                       '📍 GPS: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
//                       style: const TextStyle(fontSize: 11, color: Colors.black38),
//                     ),
//                   ),
//                 ],

//                 const SizedBox(height: 30),

//                 // ── Sign Up Button ────────────────────────────────────────
//                 SignButton(
//                   buttonText: _isSendingOtp ? 'Sending OTP…' : 'Sign Up',
//                   onPressed: _isSendingOtp ? null : _onSignUp,
//                 ),

//                 const SizedBox(height: 25.0),

//                 // ── Already have an account ───────────────────────────────
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Text('Already have an account? ',
//                         style: TextStyle(color: Colors.black45)),
//                     GestureDetector(
//                       onTap: () => Navigator.pushReplacement(
//                         context,
//                         MaterialPageRoute(builder: (_) => const SignInScreen()),
//                       ),
//                       child: Text(
//                         'Sign In',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: lightColorScheme.primary,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 20.0),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ── Helpers ───────────────────────────────────────────────────────────────

//   Widget _buildLocationTypeSelector() {
//     return Row(
//       children: _locationTypes.map((type) {
//         final isSelected = _selectedLocationType == type['value'];
//         return Expanded(
//           child: GestureDetector(
//             onTap: () {
//               setState(() => _selectedLocationType = type['value'] as String);
//               if (type['value'] == 'Current Location') _fetchCurrentLocation();
//             },
//             child: AnimatedContainer(
//               duration: const Duration(milliseconds: 200),
//               margin: const EdgeInsets.only(right: 6),
//               padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
//               decoration: BoxDecoration(
//                 color: isSelected ? lightColorScheme.primary : Colors.transparent,
//                 border: Border.all(
//                   color: isSelected ? lightColorScheme.primary : Colors.black12,
//                   width: 1.5,
//                 ),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(
//                     type['icon'] as IconData,
//                     size: 22,
//                     color: isSelected ? Colors.white : Colors.black45,
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     type['label'] as String,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 10,
//                       fontWeight: FontWeight.w600,
//                       color: isSelected ? Colors.white : Colors.black45,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildField({
//     required TextEditingController controller,
//     required String label,
//     required String hint,
//     String? Function(String?)? validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       validator: validator,
//       decoration: _inputDecoration(label: label, hint: hint),
//     );
//   }

//   InputDecoration _inputDecoration({
//     required String label,
//     required String hint,
//     Widget? prefixWidget,
//     Widget? suffixWidget,
//   }) {
//     return InputDecoration(
//       label: Text(label),
//       hintText: hint,
//       hintStyle: const TextStyle(color: Colors.black26),
//       prefixIcon: prefixWidget,
//       suffixIcon: suffixWidget,
//       border: OutlineInputBorder(
//         borderSide: const BorderSide(color: Colors.black12),
//         borderRadius: BorderRadius.circular(10),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderSide: const BorderSide(color: Colors.black12),
//         borderRadius: BorderRadius.circular(10),
//       ),
//     );
//   }
// }