// profile_screen.dart
import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:flutter/material.dart';

//COLUMN VERSION
// class ProfileScreen extends StatelessWidget {
//   const ProfileScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: const CustomAppBar(),
//       drawer: const CustomDrawer(),
//       body: Padding(
//         padding: const EdgeInsets.all(24),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             const SizedBox(height: 20),

//             // Profile Picture
//             const CircleAvatar(
//               radius: 55,
//               backgroundImage: AssetImage('assets/images/loopyNailong.jpg'),
//               // fallback color if image not found
//               backgroundColor: Colors.grey,
//             ),

//             const SizedBox(width: 16),

//             Column(
//               children: [

//               ],
//             ),

//             // Name
//             Text(
//               mockUser.name,
//               style: TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),

//             const SizedBox(height: 6),

//             // Position
//             Text(
//               mockUser.role,
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.grey,
//               ),
//             ),

//             const SizedBox(height: 12),

//             // Rating
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: List.generate(5, (index){
//                 return Icon(
//                   index < mockUser.rating
//                     ?Icons.star
//                     :Icons.star_border_outlined,
//                   color: Colors.amber,
//                   size: 20
//                 );
//               })
//             ),

//             const SizedBox(height: 30),

//             // Optional actions
//             ElevatedButton(
//               onPressed: () {
//                 print('Edit profile');
//               },
//               child: const Text('Edit Profile'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

//ROW VERSION
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      drawer: const CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// PROFILE HEADER
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const CircleAvatar(
                      radius: 45,
                      backgroundImage: AssetImage(
                        'assets/images/loopyNailong.jpg',
                      ),
                    ),
                    Positioned(
                      bottom: -8,
                      left: 0,
                      right: 0,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {},
                        child: const Text(
                          'Edit',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 40),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mockUser.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mockUser.role,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < mockUser.rating
                              ? Icons.star
                              : Icons.star_border_outlined,
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 40), // spacing
            /// BUTTONS BELOW
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 20,
              children: [
                OutlinedButton(onPressed: (){print('nyello');}, child: Text('Hello')),
                OutlinedButton(onPressed: (){print('nyello');}, child: Text('Hello')),
                OutlinedButton(onPressed: (){print('nyello');}, child: Text('Hello')),
              ],
            ),
            const SizedBox(height: 40), // spacing
            Container(
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(20),
              ),

              height: 400,
              width: double.infinity,
            )
          ],
        ),
      ),
    );
  }
}

class MockUser {
  final String name;
  final String role;
  final double rating;

  MockUser({required this.name, required this.role, required this.rating});
}

final MockUser mockUser = MockUser(
  name: 'Juan Dela Cruz',
  role: 'Farmer • Equipment Owner',
  rating: 3.0,
);
