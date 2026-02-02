// lib/models/evacuation_center_model.dart
class EvacuationCenter {
  final String id;
  final String name;
  final String barangay;
  final String? sitio;
  final String? purok;
  final String evacuationStatus;
  final String evacuationType;
  final String? accomodationArea;
  final bool isActivated;
  final bool? isOperational;
  final bool? hasElectricity;
  final bool? hasWaterSupply;
  final Map<String, dynamic>? totalMembersCheckedIn;
  final int? totalFamilyCheckedIn;

  EvacuationCenter({
    required this.id,
    required this.name,
    required this.barangay,
    this.sitio,
    this.purok,
    required this.evacuationStatus,
    required this.evacuationType,
    this.accomodationArea,
    required this.isActivated,
    this.isOperational,
    this.hasElectricity,
    this.hasWaterSupply,
    this.totalMembersCheckedIn,
    this.totalFamilyCheckedIn,
  });

  factory EvacuationCenter.fromJson(Map<String, dynamic> json) {
    return EvacuationCenter(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Center',
      barangay: json['barangay']?.toString() ?? '',
      sitio: json['sitio']?.toString(),
      purok: json['purok']?.toString(),
      evacuationStatus: json['evacuationStatus']?.toString() ?? '',
      evacuationType: json['evacuationType']?.toString() ?? '',
      accomodationArea: json['accomodationArea']?.toString(),
      isActivated: json['isActivated'] == true,
      isOperational: json['isOperational'] == true,
      hasElectricity: json['hasElectricity'] == true,
      hasWaterSupply: json['hasWaterSupply'] == true,
      totalMembersCheckedIn: json['totalMembersCheckedIn'] is Map ? Map<String, dynamic>.from(json['totalMembersCheckedIn']) : null,
      totalFamilyCheckedIn: json['totalFamilyCheckedIn'] is int ? json['totalFamilyCheckedIn'] : null,
    );
  }

  // Helper method to get display name
  String get displayName {
    return name;
  }

  // Helper method to get status description
  String get statusDescription {
    switch (evacuationStatus) {
      case '01': return 'Active';
      case '02': return 'Under Maintenance';
      case '03': return 'Available';
      default: return 'Unknown';
    }
  }

  // Helper method to get type description
  String get typeDescription {
    switch (evacuationType) {
      case '01': return 'Public';
      case '02': return 'Private';
      case '03': return 'School';
      case '04': return 'Church';
      default: return 'Other';
    }
  }

  bool get isAvailable => isActivated && evacuationStatus == '03';
}