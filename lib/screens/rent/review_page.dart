import 'package:flutter/material.dart';

class ReviewPage extends StatefulWidget {
  final String requestId;
  final String lenderId;

  const ReviewPage({super.key, required this.requestId, required this.lenderId});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  double _rating = 0;
  final TextEditingController _commentController = TextEditingController();

  void _submitReview() {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    final review = {
      'requestId': widget.requestId,
      'lenderId': widget.lenderId,
      'rating': _rating,
      'comment': _commentController.text.trim(),
      'timestamp': DateTime.now(),
    };

    // TODO: Replace with your Bloc/Event or Firestore submission
    print('Review submitted: $review');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review submitted!')),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave a Review'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Rate your experience',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Simple star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = starIndex.toDouble()),
                  icon: Icon(
                    _rating >= starIndex ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
                hintText: 'Write something about your experience',
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _submitReview,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Submit Review', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
