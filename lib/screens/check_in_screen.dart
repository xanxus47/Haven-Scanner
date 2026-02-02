import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/profile_service.dart';
import '/services/supabase_service.dart';
import '/models/profile_model.dart';
import '/models/evacuation_center_model.dart';

class CheckInScreen extends StatefulWidget {
  final String? userName;
  final VoidCallback onSignOut;
  
  const CheckInScreen({
    super.key, 
    required this.userName, 
    required this.onSignOut
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  MobileScannerController? _controller;
  bool _isProcessing = false;
  bool _isTorchOn = false; // ✨ NEW: Track flash state
  final ImagePicker _picker = ImagePicker();
  
  final ProfileService _profileService = ProfileService();
  final SupabaseService _supabaseService = SupabaseService();
  
  List<EvacuationCenter> _centers = [];
  EvacuationCenter? _selectedCenter;
  final Map<String, DateTime> _scanCooldowns = {};

  final Color _primaryColor = const Color(0xFF2563EB);
  final Color _overlayColor = const Color(0x99000000);

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _loadCenters();
  }

  void _loadCenters() async {
    final res = await _profileService.getEvacuationCenters();
    if (res['success'] && mounted) {
      setState(() => _centers = res['data']);
    }
  }

  // ✨ NEW: Toggle flash with state tracking
  void _toggleFlash() {
    _controller?.toggleTorch();
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  // ----------------------------------------------------------------
  // 🔄 LOGIC FLOW
  // ----------------------------------------------------------------

  void _handleScan(String rawData) async {
    if (_isProcessing || _selectedCenter == null) return;

    if (_scanCooldowns.containsKey(rawData)) {
      if (DateTime.now().difference(_scanCooldowns[rawData]!).inSeconds < 5) return;
    }
    _scanCooldowns[rawData] = DateTime.now();

    setState(() => _isProcessing = true);
    _controller?.stop(); 

    try {
      final id = _profileService.extractProfileId(rawData);
      if (id == null) throw "Invalid QR Code format";

      final profileRes = await _profileService.getProfileDetails(id);
      if (!profileRes['success']) throw "Profile not found";
      final Profile profile = profileRes['data'];

      if (mounted) _takeProofPhotoAndCheckIn(profile, id);

    } catch (e) {
      if (mounted) _showErrorDialog("Scan Error", e.toString());
    }
  }

  Future<void> _takeProofPhotoAndCheckIn(Profile profile, String id) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        maxWidth: 800,
      );

      if (photo == null) {
        _resetScanner();
        return;
      }

      setState(() => _isProcessing = true);

      final File file = File(photo.path);
      final String fileName = 'proof_${id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await Supabase.instance.client.storage
          .from('checkin-proofs')
          .upload(fileName, file);

      final String proofUrl = Supabase.instance.client.storage
          .from('checkin-proofs')
          .getPublicUrl(fileName);

      await _processCheckIn(profile, id, proofUrl);

    } catch (e) {
      print("PHOTO ERROR: $e");
      if (mounted) _showErrorDialog("Photo Error", "Failed to upload proof: $e");
    }
  }

  Future<void> _processCheckIn(Profile profile, String id, String? proofUrl) async {
    if (_selectedCenter == null) return;

    setState(() => _isProcessing = true);
    
    final res = await _profileService.checkInEvacuee(id, _selectedCenter!.id);

    if (res['success']) {
      try {
        await _supabaseService.trackEvacueeCheckIn(
          profileId: id, 
          fullName: profile.fullName, 
          evacuationCenterId: _selectedCenter!.id,
          evacuationCenterName: _selectedCenter!.name,
          age: profile.age?.toString(), 
          sex: profile.sex, 
          barangay: profile.barangay,
          proofImage: proofUrl 
        );
        
        if (mounted) _showSuccessDialog(profile.fullName);
        
      } catch (e) {
        print("SUPABASE ERROR: $e");
        if (mounted) _showErrorDialog("Sync Error", "Dashboard Sync failed:\n\n$e");
      }
    } else {
      if (mounted) _showErrorDialog("Check-In Failed", res['message']);
    }
  }

  // ----------------------------------------------------------------
  // 🎨 UI BUILDER
  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // VIEW 1: SELECT CENTER
    if (_selectedCenter == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("Select Location"), 
          backgroundColor: _primaryColor,
          elevation: 0,
        ),
        body: _centers.isEmpty 
          ? const Center(child: CircularProgressIndicator()) 
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _centers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final center = _centers[i];
                return Material(
                  color: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedCenter = center);
                      _resetScanner();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.location_on_rounded, color: _primaryColor),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  center.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  center.barangay,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      );
    }

    // VIEW 2: SCANNER ACTIVE
    return Scaffold(
      body: Stack(
        children: [
          // Camera Feed
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleScan(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // Overlay + Scan Frame
          CustomPaint(
            painter: ScannerOverlayPainter(_overlayColor),
            child: const SizedBox.expand(),
          ),

          // Top Header Bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10, 
                bottom: 16, 
                left: 20, 
                right: 20
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                )
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Checking in to:", 
                          style: TextStyle(color: Colors.white70, fontSize: 12)
                        ),
                        Text(
                          _selectedCenter!.name, 
                          style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 18
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // ✨ ENHANCED FLASH BUTTON
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _isTorchOn 
                          ? Colors.amber.withOpacity(0.3) 
                          : Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isTorchOn ? Colors.amber : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: _isTorchOn ? Colors.amber : Colors.white,
                      ),
                      onPressed: _toggleFlash,
                      tooltip: _isTorchOn ? 'Turn off flash' : 'Turn on flash',
                    ),
                  ),
                  
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedCenter = null;
                        _isProcessing = false;
                        _isTorchOn = false; // Reset flash state
                      });
                    },
                    icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                    label: const Text("Change", style: TextStyle(color: Colors.white)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                  )
                ],
              ),
            ),
          ),

          // Processing Loader
          if (_isProcessing) 
            Container(
              color: Colors.black54, 
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("Processing...", style: TextStyle(color: Colors.white))
                  ],
                )
              )
            ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // 🎨 DIALOGS
  // ----------------------------------------------------------------

  void _showSuccessDialog(String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 48, color: Colors.green),
              ),
              const SizedBox(height: 20),
              
              const Text(
                "Check-In Successful",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              Text(
                "$name has been verified and checked in to ${_selectedCenter?.name}.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.4),
              ),
              
              const SizedBox(height: 28),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _resetScanner();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    "Scan Next Evacuee", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, size: 32, color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _resetScanner();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Dismiss"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _resetScanner() {
    if (mounted) {
      setState(() => _isProcessing = false);
      _controller?.start();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

// ----------------------------------------------------------------
// 🎨 SCANNER OVERLAY PAINTER (Preserved from original)
// ----------------------------------------------------------------

class ScannerOverlayPainter extends CustomPainter {
  final Color overlayColor;

  ScannerOverlayPainter(this.overlayColor);

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = size.width * 0.7;
    final Rect scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = overlayColor);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final double cornerLength = 30;
    
    // Top-left
    canvas.drawLine(
      Offset(scanArea.left, scanArea.top + cornerLength),
      Offset(scanArea.left, scanArea.top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanArea.left, scanArea.top),
      Offset(scanArea.left + cornerLength, scanArea.top),
      borderPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(scanArea.right - cornerLength, scanArea.top),
      Offset(scanArea.right, scanArea.top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanArea.right, scanArea.top),
      Offset(scanArea.right, scanArea.top + cornerLength),
      borderPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(scanArea.left, scanArea.bottom - cornerLength),
      Offset(scanArea.left, scanArea.bottom),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanArea.left, scanArea.bottom),
      Offset(scanArea.left + cornerLength, scanArea.bottom),
      borderPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(scanArea.right - cornerLength, scanArea.bottom),
      Offset(scanArea.right, scanArea.bottom),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanArea.right, scanArea.bottom - cornerLength),
      Offset(scanArea.right, scanArea.bottom),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}