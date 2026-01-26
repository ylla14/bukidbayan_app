class RentRequest {
  final String itemId;
  final String name;
  final String address;
  final DateTime start;
  final DateTime end;
  final String? landSizeProofPath;
  final String? cropHeightProofPath;

  RentRequest({
    required this.itemId,
    required this.name,
    required this.address,
    required this.start,
    required this.end,
    this.landSizeProofPath,
    this.cropHeightProofPath,
  });

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'name': name,
        'address': address,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'landSizeProofPath': landSizeProofPath,
        'cropHeightProofPath': cropHeightProofPath,
      };

  factory RentRequest.fromMap(Map<String, dynamic> map) => RentRequest(
        itemId: map['itemId'],
        name: map['name'],
        address: map['address'],
        start: DateTime.parse(map['start']),
        end: DateTime.parse(map['end']),
        landSizeProofPath: map['landSizeProofPath'],
        cropHeightProofPath: map['cropHeightProofPath'],
      );
}
