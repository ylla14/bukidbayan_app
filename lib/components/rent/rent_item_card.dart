import 'package:flutter/material.dart';

class RentItemCard extends StatelessWidget {
  final String title;
  final String price;
  final String imageUrl;

  const RentItemCard({super.key, required this.title, required this.imageUrl, required this.price});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              // child: Image.network(imageUrl, fit: BoxFit.cover,),
              child: Image.asset(imageUrl, fit: BoxFit.cover,),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "est.", // small indicator
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            )
          ),
        ],
      ),
    );
  }
}

