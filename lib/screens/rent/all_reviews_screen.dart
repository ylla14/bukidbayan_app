import 'package:bukidbayan_app/models/review.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';

class AllReviewsScreen extends StatelessWidget {
  final String equipmentId;
  final String equipmentName;

  const AllReviewsScreen({
    super.key,
    required this.equipmentId,
    required this.equipmentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: FutureBuilder<List<Review>>(
        future: FirestoreService().getReviewsForEquipment(equipmentId),
        builder: (context, snapshot) {
          final reviews = snapshot.data ?? [];
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return CustomScrollView(
            slivers: [
              // ── Fancy SliverAppBar 
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                elevation: 0,
                backgroundColor: lightColorScheme.primary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsets.only(left: 20, bottom: 16, right: 20),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reviews',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        equipmentName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          lightColorScheme.primary,
                          lightColorScheme.secondary,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Decorative circles
                        Positioned(
                          top: -20,
                          right: -30,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.07),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 60,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Stats Bar 
              if (!isLoading && reviews.isNotEmpty)
                SliverToBoxAdapter(
                  child: _ReviewSummaryBar(reviews: reviews),
                ),

              // ── Loading 
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),

              // ── Empty State 
              if (!isLoading && reviews.isEmpty)
                SliverFillRemaining(
                  child: _EmptyReviewsState(),
                ),

              // ── Review List 
              if (!isLoading && reviews.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _ReviewCard(review: reviews[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Summary Bar 

class _ReviewSummaryBar extends StatelessWidget {
  final List<Review> reviews;

  const _ReviewSummaryBar({required this.reviews});

  double get _average =>
      reviews.isEmpty ? 0 : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Average score
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _average.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: lightColorScheme.primary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              _StarRow(rating: _average, size: 14),
              const SizedBox(height: 2),
              Text(
                '${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          const VerticalDivider(width: 1),
          const SizedBox(width: 20),
          // Rating breakdown bars
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = reviews.where((r) => r.rating.round() == star).length;
                final fraction = reviews.isEmpty ? 0.0 : count / reviews.length;
                return _RatingBar(star: star, fraction: fraction, count: count);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final int star;
  final double fraction;
  final int count;

  const _RatingBar({
    required this.star,
    required this.fraction,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Text(
            '$star',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 10, color: Colors.amber),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation<Color>(
                  lightColorScheme.primary.withOpacity(0.7),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 16,
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review Card 

class _ReviewCard extends StatelessWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: avatar + name + date + stars
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              FutureBuilder<String?>(
                future: FirestoreService().getUserNameById(review.reviewerId),
                builder: (context, nameSnap) {
                  final name = nameSnap.data ?? 'A';
                  return _Avatar(name: name);
                },
              ),
              const SizedBox(width: 12),
              // Name + stars
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String?>(
                      future: FirestoreService()
                          .getUserNameById(review.reviewerId),
                      builder: (context, nameSnap) {
                        return Text(
                          nameSnap.data ?? 'Anonymous',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    _StarRow(rating: review.rating.toDouble(), size: 14),
                  ],
                ),
              ),
              // Rating badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _ratingColor(review.rating).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  review.rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _ratingColor(review.rating),
                  ),
                ),
              ),
            ],
          ),

          // Comment
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                review.comment,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: Color(0xFF444455),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _ratingColor(num rating) {
    if (rating >= 4) return const Color(0xFF22C55E);
    if (rating >= 3) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

// ── Shared Widgets 

class _StarRow extends StatelessWidget {
  final double rating;
  final double size;

  const _StarRow({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(Icons.star_rounded, size: size, color: Colors.amber);
        } else if (i < rating) {
          return Icon(Icons.star_half_rounded, size: size, color: Colors.amber);
        } else {
          return Icon(Icons.star_outline_rounded,
              size: size, color: Colors.amber.withOpacity(0.4));
        }
      }),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            lightColorScheme.primary,
            lightColorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _EmptyReviewsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: lightColorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rate_review_outlined,
                size: 38,
                color: lightColorScheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Be the first to share your experience\nwith this equipment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}