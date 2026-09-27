import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Color Scheme - Updated
  final Color _primaryColor = Color(0xFF6366F1); // Indigo 500
  final Color _secondaryColor = Color(0xFF8B5CF6); // Violet 500
  final Color _accentColor = Color(0xFF10B981); // Emerald 500
  final Color _successColor = Color(0xFF34D399); // Emerald 400
  final Color _warningColor = Color(0xFFF59E0B); // Amber 500
  final Color _errorColor = Color(0xFFEF4444); // Red 500
  final Color _backgroundColor = Color(0xFFF8FAFC); // Slate 50
  final Color _surfaceColor = Color(0xFFFFFFFF); // White
  final Color _textPrimary = Color(0xFF1E293B); // Slate 800
  final Color _textSecondary = Color(0xFF64748B); // Slate 500
  final Color _textDisabled = Color(0xFF94A3B8); // Slate 400

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedDrawerIndex = 0;

  // Add these with other state variables at the top of _HomeState class
  List<Map<String, dynamic>> _prescriptionsList = [];
  bool _isLoadingPrescriptions = false;

  // Add this variable with other state variables at the top of _HomeState class
  List<Map<String, dynamic>> _icdCodesList = [];
  bool _isLoadingICDCodes = false;

  // Stats data - Update to be dynamic
  final List<Map<String, dynamic>> _stats = [
    {
      'title': 'Total Prescriptions',
      'value': '0',
      'color': Color(0xFF6366F1), // Primary color
      'icon': Icons.description_outlined,
      'subtitle': 'Load to see count',
    },
    {
      'title': 'Total Users',
      'value': '0',
      'color': Color(0xFF10B981), // Success color
      'icon': Icons.people_outline,
      'subtitle': 'Load to see count',
    },
    {
      'title': 'Total Prescribers',
      'value': '0',
      'color': Color(0xFF8B5CF6), // Secondary color
      'icon': Icons.medical_services_outlined,
      'subtitle': 'Load to see count',
    },
  ];

  // State variables
  String? _selectedPatientName;
  File? _selectedImage;
  bool _isUploading = false;
  List<String> _selectedICDCodes = [];
  CameraController? _cameraController;

  // Users API variables
  List<Map<String, dynamic>> _usersList = [];
  bool _isLoadingUsers = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Initialize camera permission request
    _requestCameraPermission();
    // Initialize users list
    _usersList = [];
    _isLoadingUsers = false;
    _searchQuery = '';

    // NEW: Initialize ICD codes list and fetch ICD codes
    _icdCodesList = [];
    _isLoadingICDCodes = false;
    _fetchICDCodes();

    // NEW: Automatically fetch users when Home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_usersList.isEmpty && !_isLoadingUsers) {
        _fetchUsers();
      }
    });
  }

  Future<void> _fetchICDCodes() async {
    setState(() {
      _isLoadingICDCodes = true;
    });
    try {
      final response = await http.get(
        Uri.parse('https://omb-api.omegambs.site/icd-codes'),
        headers: {'Accept': 'application/json'},
      );
      print('Fetch ICD codes response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body);

        setState(() {
          _icdCodesList = responseData.map((code) {
            return {
              'code': code['code'] ?? '',
              'description': code['description'] ?? '',
              'displayText': '${code['code']} - ${code['description']}',
            };
          }).toList();
        });

        print('Successfully loaded ${_icdCodesList.length} ICD codes');
      } else {
        print('Failed to fetch ICD codes: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load ICD codes'),
            backgroundColor: _warningColor,
          ),
        );
      }
    } catch (e) {
      print('Error fetching ICD codes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading ICD codes: ${e.toString()}'),
          backgroundColor: _errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoadingICDCodes = false;
      });
    }
  }

  Future<void> _fetchPrescriptions() async {
    setState(() {
      _isLoadingPrescriptions = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final tokenType = prefs.getString('token_type') ?? 'bearer';

      if (token == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please login again')));
        setState(() {
          _isLoadingPrescriptions = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://omb-api.omegambs.site/prescriptions'),
        headers: {
          'Accept': 'application/json',
          'Authorization': '$tokenType $token',
        },
      );

      print('Fetch prescriptions response status: ${response.statusCode}');
      print('Fetch prescriptions response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body);

        setState(() {
          _prescriptionsList = responseData.map((prescription) {
            // Format prescriber name
            final prescriber = prescription['prescriber'] ?? {};
            final prescriberFirstName = prescriber['first_name'] ?? '';
            final prescriberLastName = prescriber['last_name'] ?? '';
            final prescriberName = '$prescriberFirstName $prescriberLastName'
                .trim();
            final prescriberEmail = prescriber['email'] ?? '';

            // Format patient name
            final patientName =
                prescription['patient_name'] ?? 'Unknown Patient';

            // Format date
            String formattedDate = '';
            try {
              final createdAt = prescription['created_at'] ?? '';
              if (createdAt.isNotEmpty) {
                final date = DateTime.parse(createdAt);
                final monthNames = [
                  'Jan',
                  'Feb',
                  'Mar',
                  'Apr',
                  'May',
                  'Jun',
                  'Jul',
                  'Aug',
                  'Sep',
                  'Oct',
                  'Nov',
                  'Dec',
                ];
                final month = monthNames[date.month - 1];
                final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
                final minute = date.minute.toString().padLeft(2, '0');
                final amPm = date.hour < 12 ? 'AM' : 'PM';
                formattedDate =
                    '$month ${date.day}, ${date.year}, $hour:$minute $amPm';
              }
            } catch (e) {
              formattedDate = prescription['created_at'] ?? '';
            }

            return {
              'id': prescription['id'] ?? 0,
              'patient_name': patientName,
              'prescriber_name': prescriberName.isNotEmpty
                  ? prescriberName
                  : prescriberEmail,
              'prescriber_email': prescriberEmail,
              'date': formattedDate,
              'icd_codes': List<String>.from(prescription['icd_codes'] ?? []),
              'file_path': prescription['file_path'] ?? '',
              'file_name': prescription['file_name'] ?? '',
              'file_type': prescription['file_type'] ?? '',
              'created_at': prescription['created_at'] ?? '',
            };
          }).toList();

          // Sort by creation date (newest first)
          _prescriptionsList.sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );
        });

        // Update stats with actual count
        setState(() {
          _stats[0]['value'] = _prescriptionsList.length.toString();
        });

        // Also update Total Prescribers count if users are loaded
        if (_usersList.isNotEmpty) {
          final totalPrescribers = _usersList
              .where((user) => user['role']?.toLowerCase() == 'prescriber')
              .length;
          setState(() {
            _stats[2]['value'] = totalPrescribers.toString();
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescriptions loaded successfully'),
            backgroundColor: _successColor,
          ),
        );
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access denied. Please check your permissions.'),
            backgroundColor: _errorColor,
          ),
        );
      } else {
        try {
          final responseData = jsonDecode(response.body);
          String errorMessage = 'Failed to fetch prescriptions';
          if (responseData['detail'] != null) {
            errorMessage = responseData['detail'];
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: _errorColor),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to fetch prescriptions: ${response.statusCode}',
              ),
              backgroundColor: _errorColor,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Fetch prescriptions error: $e');
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: _errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoadingPrescriptions = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // Request camera permission
  void _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      print('Camera permission granted');
    } else {
      print('Camera permission denied');
    }
  }

  // Request gallery permission
  Future<bool> _requestGalleryPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted;
    }
    return true;
  }

  Widget _getCurrentScreen() {
    switch (_selectedDrawerIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return _buildUploadPrescriptionScreen();
      case 2:
        return _buildUsersScreen();
      default:
        return _buildHomeContent();
    }
  }

  // Direct camera opening function pick image from camera
  Future<void> _openCameraDirect() async {
    try {
      // Check camera permission
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        final permission = await Permission.camera.request();
        if (!permission.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Camera permission is required')),
          );
          return;
        }
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo captured successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No photo taken'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error opening camera: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open camera: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _backgroundColor,
      drawer: _buildNavigationDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: _getCurrentScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = screenWidth * 0.5;

    // Fetch prescriptions when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_prescriptionsList.isEmpty && !_isLoadingPrescriptions) {
        _fetchPrescriptions();
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBox(),
        _buildStatsGrid(cardHeight),
        SizedBox(height: 24),
        _buildRecentPrescriptionsSection(),
        SizedBox(height: 30),
      ],
    );
  }

  Widget _buildUploadPrescriptionScreen() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Prescription',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Fill in the details below to upload a new prescription',
            style: TextStyle(fontSize: 14, color: _textSecondary),
          ),
          SizedBox(height: 30),

          // Patient Name Field
          Text(
            'Patient name',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _textDisabled.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _selectedPatientName = value;
                });
              },
              decoration: InputDecoration(
                hintText: "Enter patient's full name",
                hintStyle: TextStyle(color: _textDisabled),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                prefixIcon: Icon(Icons.person_outline, color: _textSecondary),
              ),
            ),
          ),
          SizedBox(height: 24),

          // ICD Codes Field
          Text(
            'ICD Codes (At least one)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 8),
          GestureDetector(
            onTap: _showICDCodesDialog,
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _textDisabled.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.code_outlined, color: _textSecondary),
                    SizedBox(width: 12),
                    Expanded(
                      child: _selectedICDCodes.isEmpty
                          ? Text(
                              'Select one or more codes...',
                              style: TextStyle(color: _textDisabled),
                            )
                          : Text(
                              '${_selectedICDCodes.length} code(s) selected',
                              style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                    Icon(Icons.arrow_drop_down, color: _textSecondary),
                  ],
                ),
              ),
            ),
          ),

          if (_selectedICDCodes.isNotEmpty) ...[
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedICDCodes.map((code) {
                final codeOnly = code.split(' - ')[0];
                return Chip(
                  label: Text(codeOnly),
                  deleteIcon: Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      _selectedICDCodes.remove(code);
                    });
                  },
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: _primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
          ],
          SizedBox(height: 24),

          // Prescription File
          Text(
            'Prescription file (Image/PDF)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 12),

          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _selectedImage != null
                    ? _successColor.withOpacity(0.3)
                    : _textDisabled.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: _selectedImage != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.file(
                          _selectedImage!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImage = null;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _errorColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _successColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Image Selected',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          color: _primaryColor,
                          size: 60,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Tap to Upload',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Supports: JPG, PNG, PDF',
                          style: TextStyle(fontSize: 14, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
          ),
          SizedBox(height: 30),

          // Action Buttons Row
          Row(
            children: [
              // Open Camera Button
              Expanded(
                child: GestureDetector(
                  onTap: _openCameraDirect,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primaryColor, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined, color: _primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Open Camera',
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),

              // Choose File Button
              Expanded(
                child: GestureDetector(
                  onTap: _pickImageFromGallery,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Choose File',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 30),

          // Bottom Buttons Row
          Row(
            children: [
              // Cancel Button
              Expanded(
                child: GestureDetector(
                  onTap: _cancelUpload,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _textDisabled.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isUploading
                          ? CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _textSecondary,
                            )
                          : Text(
                              'Cancel',
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),

              // Upload Button
              Expanded(
                child: GestureDetector(
                  onTap: _uploadPrescription,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: _canUpload()
                          ? LinearGradient(
                              colors: [_successColor, Color(0xFF10B981)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: _canUpload()
                          ? null
                          : _textDisabled.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _canUpload()
                          ? [
                              BoxShadow(
                                color: _successColor.withOpacity(0.3),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: _isUploading
                          ? CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            )
                          : Text(
                              'Upload',
                              style: TextStyle(
                                color: _canUpload()
                                    ? Colors.white
                                    : _textDisabled,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  bool _canUpload() {
    return _selectedPatientName != null &&
        _selectedPatientName!.isNotEmpty &&
        _selectedICDCodes.isNotEmpty &&
        _selectedImage != null;
  }

  void _showICDCodesDialog() async {
    // Refresh ICD codes before showing dialog
    if (_icdCodesList.isEmpty && !_isLoadingICDCodes) {
      await _fetchICDCodes();
    }

    // Temporary list to hold selected codes during dialog
    List<String> tempSelectedCodes = List.from(_selectedICDCodes);
    TextEditingController searchController = TextEditingController();

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Filter ICD codes based on search
            List<Map<String, dynamic>> filteredCodes =
                searchController.text.isEmpty
                ? _icdCodesList
                : _icdCodesList.where((code) {
                    final searchText = searchController.text.toLowerCase();
                    return code['code'].toLowerCase().contains(searchText) ||
                        code['description'].toLowerCase().contains(
                          searchText,
                        ) ||
                        code['displayText'].toLowerCase().contains(searchText);
                  }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.maxFinite,
                height: 500,
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select ICD Codes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 20,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Search Box
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: searchController,
                          onChanged: (value) {
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            hintText: 'Search ICD codes...',
                            hintStyle: TextStyle(color: _textDisabled),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                            prefixIcon: Icon(
                              Icons.search,
                              color: _textSecondary,
                              size: 20,
                            ),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: _isLoadingICDCodes && _icdCodesList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: _primaryColor,
                                  ),
                                  SizedBox(height: 10),
                                  Text('Loading ICD codes...'),
                                ],
                              ),
                            )
                          : filteredCodes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_outlined,
                                    color: _textDisabled,
                                    size: 40,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    searchController.text.isEmpty
                                        ? 'No ICD codes available'
                                        : 'No matching codes found',
                                    style: TextStyle(color: _textSecondary),
                                  ),
                                  if (searchController.text.isNotEmpty)
                                    TextButton(
                                      onPressed: () {
                                        searchController.clear();
                                        setState(() {});
                                      },
                                      child: Text('Clear search'),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredCodes.length,
                              itemBuilder: (context, index) {
                                final code =
                                    filteredCodes[index]['displayText'];
                                final isSelected = tempSelectedCodes.contains(
                                  code,
                                );

                                return Container(
                                  margin: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _primaryColor.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(color: _primaryColor)
                                        : null,
                                  ),
                                  child: CheckboxListTile(
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              filteredCodes[index]['code'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: _textPrimary,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            if (isSelected)
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _primaryColor,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  'Selected',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          filteredCodes[index]['description'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          tempSelectedCodes.add(code);
                                        } else {
                                          tempSelectedCodes.remove(code);
                                        }
                                      });
                                    },
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    dense: true,
                                    activeColor: _primaryColor,
                                  ),
                                );
                              },
                            ),
                    ),

                    // Selected count indicator
                    if (tempSelectedCodes.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: _textDisabled.withOpacity(0.2),
                            ),
                          ),
                          color: _backgroundColor,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Selected: ${tempSelectedCodes.length}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                            if (tempSelectedCodes.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    tempSelectedCodes.clear();
                                  });
                                },
                                child: Text(
                                  'Clear all',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _errorColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      setState(() {
        _selectedICDCodes = tempSelectedCodes;
      });
    } else {
      setState(() {
        _selectedICDCodes = result;
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                SizedBox(height: 20),
                Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(Icons.camera_alt, color: _primaryColor),
                        ),
                      ),
                      title: Text(
                        'Take Photo',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _openCameraDirect();
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    SizedBox(height: 8),
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.photo_library,
                            color: _successColor,
                          ),
                        ),
                      ),
                      title: Text(
                        'Choose from Gallery',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromGallery();
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final hasPermission = await _requestGalleryPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery permission is required')),
        );
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image selected from gallery'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No image selected'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select image: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _uploadPrescription() async {
    if (!_canUpload()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final tokenType = prefs.getString('token_type') ?? 'bearer';

      if (token == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please login again')));
        setState(() {
          _isUploading = false;
        });
        return;
      }

      List<String> icdCodesOnly = _selectedICDCodes.map((code) {
        return code.split(' - ')[0];
      }).toList();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://omb-api.omegambs.site/prescriptions/upload'),
      );

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = '$tokenType $token';

      request.fields['patient_name'] = _selectedPatientName!;
      request.fields['icd_codes'] = jsonEncode(icdCodesOnly);

      print('Uploading prescription with:');
      print('- Patient: $_selectedPatientName');
      print('- ICD Codes: ${jsonEncode(icdCodesOnly)}');
      print('- File: ${_selectedImage!.path}');

      var fileStream = http.ByteStream(_selectedImage!.openRead());
      var fileLength = await _selectedImage!.length();

      var multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: _selectedImage!.path.split('/').last,
      );
      request.files.add(multipartFile);

      var response = await request.send();
      var responseString = await response.stream.bytesToString();

      print('Upload response status: ${response.statusCode}');
      print('Upload response body: $responseString');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(responseString);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: _successColor, size: 60),
                  SizedBox(height: 16),
                  Text(
                    'Success!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Prescription uploaded successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resetForm();
                        setState(() {
                          _selectedDrawerIndex = 0;
                        });
                        _fetchPrescriptions();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription uploaded successfully'),
            backgroundColor: _successColor,
          ),
        );
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access denied. Please login again.'),
            backgroundColor: _errorColor,
          ),
        );
      } else if (response.statusCode == 422) {
        try {
          final errorData = jsonDecode(responseString);
          String errorMessage = 'Validation error';
          if (errorData['detail'] is List && errorData['detail'].isNotEmpty) {
            List<String> errors = [];
            for (var error in errorData['detail']) {
              if (error['msg'] != null) {
                errors.add(error['msg']);
              }
            }
            errorMessage = errors.join('\n');
          } else if (errorData['detail'] is String) {
            errorMessage = errorData['detail'];
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: _warningColor,
              duration: Duration(seconds: 5),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Validation error occurred'),
              backgroundColor: _warningColor,
            ),
          );
        }
      } else {
        try {
          final errorData = jsonDecode(responseString);
          String errorMessage = 'Failed to upload prescription';
          if (errorData['detail'] != null) {
            errorMessage = errorData['detail'];
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: _errorColor),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload: ${response.statusCode}'),
              backgroundColor: _errorColor,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Upload prescription error: $e');
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: _errorColor,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _cancelUpload() {
    if (_isUploading) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: _warningColor, size: 40),
              SizedBox(height: 16),
              Text(
                'Cancel Upload?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Are you sure you want to cancel? All entered data will be lost.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'No',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resetForm();
                        setState(() {
                          _selectedDrawerIndex = 0;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _errorColor,
                      ),
                      child: Text(
                        'Yes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _selectedPatientName = null;
      _selectedICDCodes.clear();
      _selectedImage = null;
      _isUploading = false;
    });
  }

  Widget _buildUsersScreen() {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Users Management',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Manage and view all system users',
              style: TextStyle(fontSize: 14, color: _textSecondary),
            ),
            SizedBox(height: 20),

            // User stats cards
            Row(
              children: [
                // Total Users
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.2),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Users',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          _usersList.length.toString(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),

                // Verified Users
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_successColor, Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _successColor.withOpacity(0.2),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          _usersList
                              .where((user) => user['is_verified'] == true)
                              .length
                              .toString(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Search bar and refresh button
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search users by name, email, or role...',
                        hintStyle: TextStyle(color: _textDisabled),
                        prefixIcon: Icon(Icons.search, color: _textSecondary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                GestureDetector(
                  onTap: _fetchUsers,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoadingUsers
                          ? CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : Icon(Icons.refresh, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Users list header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Users (${_getFilteredUsers().length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  '${_getFilteredUsers().length} users',
                  style: TextStyle(fontSize: 14, color: _textSecondary),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Users list
            _isLoadingUsers && _usersList.isEmpty
                ? Container(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: _primaryColor),
                          SizedBox(height: 16),
                          Text(
                            'Loading users...',
                            style: TextStyle(color: _textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : _getFilteredUsers().isEmpty
                ? Container(
                    height: 300,
                    padding: EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: _textDisabled,
                            size: 60,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No users found'
                                : 'No matching users',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Try refreshing the users list'
                                : 'Try a different search term',
                            style: TextStyle(
                              color: _textDisabled,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 20),
                          if (_searchQuery.isEmpty)
                            ElevatedButton(
                              onPressed: _fetchUsers,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text('Refresh Users'),
                            ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    constraints: BoxConstraints(minHeight: 200, maxHeight: 600),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _getFilteredUsers().length,
                      itemBuilder: (context, index) {
                        final user = _getFilteredUsers()[index];
                        final fullName =
                            '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                                .trim();
                        final email = user['email'] ?? '';
                        final role = user['role'] ?? '';
                        final createdAt = user['created_at'] ?? '';
                        final isVerified = user['is_verified'] ?? false;

                        final initials = _getInitials(fullName, email);

                        String formattedDate = '';
                        try {
                          if (createdAt.isNotEmpty) {
                            final date = DateTime.parse(createdAt);
                            final monthNames = [
                              'Jan',
                              'Feb',
                              'Mar',
                              'Apr',
                              'May',
                              'Jun',
                              'Jul',
                              'Aug',
                              'Sep',
                              'Oct',
                              'Nov',
                              'Dec',
                            ];
                            final month = monthNames[date.month - 1];
                            formattedDate = '$month ${date.day}, ${date.year}';
                          }
                        } catch (e) {
                          formattedDate = createdAt;
                        }

                        return Container(
                          margin: EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_primaryColor, _secondaryColor],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fullName.isNotEmpty ? fullName : email,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: _textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                SizedBox(width: 6),
                                if (isVerified)
                                  Icon(
                                    Icons.verified,
                                    color: _successColor,
                                    size: 16,
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 2),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textDisabled,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              constraints: BoxConstraints(maxWidth: 80),
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: role.toLowerCase() == 'prescriber'
                                    ? LinearGradient(
                                        colors: [
                                          _warningColor,
                                          Color(0xFFF59E0B),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      )
                                    : LinearGradient(
                                        colors: [_textSecondary, _textDisabled],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredUsers() {
    if (_searchQuery.isEmpty) {
      return _usersList;
    }

    return _usersList.where((user) {
      final fullName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
          .toLowerCase();
      final email = (user['email'] ?? '').toLowerCase();
      final role = (user['role'] ?? '').toLowerCase();

      return fullName.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          role.contains(_searchQuery);
    }).toList();
  }

  String _getInitials(String fullName, String email) {
    if (fullName.isNotEmpty) {
      final nameParts = fullName.trim().split(' ');
      if (nameParts.length >= 2 &&
          nameParts[0].isNotEmpty &&
          nameParts[1].isNotEmpty) {
        return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
      } else if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
        return nameParts[0].substring(0, 1).toUpperCase();
      }
    }

    if (email.isNotEmpty && email.contains('@')) {
      final emailPrefix = email.split('@')[0];
      if (emailPrefix.isNotEmpty) {
        return emailPrefix.substring(0, 1).toUpperCase();
      }
    }

    return 'U';
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final tokenType = prefs.getString('token_type') ?? 'bearer';

      if (token == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please login again')));
        setState(() {
          _isLoadingUsers = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://omb-api.omegambs.site/admin/users'),
        headers: {
          'Accept': 'application/json',
          'Authorization': '$tokenType $token',
        },
      );

      print('Fetch users response status: ${response.statusCode}');
      print('Fetch users response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body);

        setState(() {
          _usersList = responseData.map((user) {
            return {
              'id': user['id'] ?? 0,
              'email': user['email'] ?? '',
              'first_name': user['first_name'] ?? '',
              'last_name': user['last_name'] ?? '',
              'role': user['role'] ?? '',
              'is_active': user['is_active'] ?? false,
              'is_verified': user['is_verified'] ?? false,
              'created_at': user['created_at'] ?? '',
            };
          }).toList();

          _usersList.sort(
            (a, b) => (b['created_at'] as String).compareTo(
              a['created_at'] as String,
            ),
          );

          final totalUsers = _usersList.length;
          final totalPrescribers = _usersList
              .where((user) => user['role']?.toLowerCase() == 'prescriber')
              .length;

          _stats[1]['value'] = totalUsers.toString();
          _stats[2]['value'] = totalPrescribers.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Users list updated successfully'),
            backgroundColor: _successColor,
          ),
        );
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access denied. Please check your permissions.'),
            backgroundColor: _errorColor,
          ),
        );
      } else {
        try {
          final responseData = jsonDecode(response.body);
          String errorMessage = 'Failed to fetch users';

          if (responseData['detail'] != null) {
            errorMessage = responseData['detail'];
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: _errorColor),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to fetch users: ${response.statusCode}'),
              backgroundColor: _errorColor,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Fetch users error: $e');
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: _errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _secondaryColor],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            icon: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.menu, size: 22, color: Colors.white),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Ω',
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Omega Medical',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Billing Inc.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search prescriptions, patients...',
            hintStyle: TextStyle(color: _textDisabled),
            prefixIcon: Container(
              padding: EdgeInsets.all(14),
              child: Icon(Icons.search, color: _textSecondary),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(double cardHeight) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_usersList.isNotEmpty && _prescriptionsList.isNotEmpty) {
        final totalUsers = _usersList.length;
        final totalPrescribers = _usersList
            .where((user) => user['role']?.toLowerCase() == 'prescriber')
            .length;

        if (_stats[1]['value'] != totalUsers.toString()) {
          setState(() {
            _stats[1]['value'] = totalUsers.toString();
            _stats[2]['value'] = totalPrescribers.toString();
          });
        }
      }
    });

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard(_stats[0], cardHeight)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard(_stats[1], cardHeight)),
            ],
          ),
          SizedBox(height: 12),
          _buildLargeStatCard(_stats[2], cardHeight),
        ],
      ),
    );
  }

  Widget _buildStatCard(Map<String, dynamic> stat, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  stat['color'].withOpacity(0.2),
                  stat['color'].withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(stat['icon'], color: stat['color'], size: 26),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat['title'],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    stat['value'],
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.trending_up_rounded,
                    color: _successColor,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLargeStatCard(Map<String, dynamic> stat, double height) {
    return Container(
      height: height * 0.8,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [stat['color'], Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: stat['color'].withOpacity(0.3),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat['title'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  stat['value'],
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(stat['icon'], color: Colors.white, size: 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPrescriptionsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Prescriptions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Recent uploaded prescriptions',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _fetchPrescriptions,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoadingPrescriptions
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.refresh, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Loading State
          if (_isLoadingPrescriptions)
            Container(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: _primaryColor),
                    SizedBox(height: 12),
                    Text(
                      'Loading prescriptions...',
                      style: TextStyle(color: _textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          // Empty State
          else if (_prescriptionsList.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: _textDisabled,
                      size: 50,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No recent prescriptions',
                      style: TextStyle(color: _textSecondary, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Upload your first prescription',
                      style: TextStyle(color: _textDisabled, fontSize: 14),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _fetchPrescriptions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Load Prescriptions'),
                    ),
                  ],
                ),
              ),
            )
          // Prescriptions List
          else
            Column(
              children: _prescriptionsList.map((prescription) {
                final patientName =
                    prescription['patient_name'] ?? 'Unknown Patient';
                final date = prescription['date'] ?? '';

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _textDisabled.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryColor, _secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.description_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    title: Text(
                      patientName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      date,
                      style: TextStyle(fontSize: 13, color: _textSecondary),
                    ),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            color: _primaryColor,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'View',
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    onTap: () {
                      _viewPrescription(prescription);
                    },
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _viewPrescription(Map<String, dynamic> prescription) async {
    final prescriptionId = prescription['id'];

    if (prescriptionId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid prescription ID')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _primaryColor, strokeWidth: 2),
              SizedBox(height: 16),
              Text(
                'Loading Prescription Details...',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final tokenType = prefs.getString('token_type') ?? 'bearer';

      if (token == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please login again')));
        return;
      }

      final response = await http.get(
        Uri.parse(
          'https://omb-api.omegambs.site/prescriptions/$prescriptionId',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': '$tokenType $token',
        },
      );

      print(
        'Fetch prescription details response status: ${response.statusCode}',
      );
      print('Fetch prescription details response body: ${response.body}');

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final prescriptionData = jsonDecode(response.body);

        final patientName =
            prescriptionData['patient_name'] ?? 'Unknown Patient';
        final icdCodes = List<String>.from(prescriptionData['icd_codes'] ?? []);
        final filePath = prescriptionData['file_path'] ?? '';
        final fileName = prescriptionData['file_name'] ?? '';
        final fileType = prescriptionData['file_type'] ?? '';
        final createdAt = prescriptionData['created_at'] ?? '';

        final prescriber = prescriptionData['prescriber'] ?? {};
        final prescriberFirstName = prescriber['first_name'] ?? '';
        final prescriberLastName = prescriber['last_name'] ?? '';
        final prescriberName = '$prescriberFirstName $prescriberLastName'
            .trim();
        final prescriberEmail = prescriber['email'] ?? '';

        String formattedDate = '';
        try {
          if (createdAt.isNotEmpty) {
            final date = DateTime.parse(createdAt);
            final monthNames = [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec',
            ];
            final month = monthNames[date.month - 1];
            final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
            final minute = date.minute.toString().padLeft(2, '0');
            final amPm = date.hour < 12 ? 'AM' : 'PM';
            formattedDate =
                '$month ${date.day}, ${date.year}, $hour:$minute $amPm';
          }
        } catch (e) {
          formattedDate = createdAt;
        }

        _showPrescriptionDialog(
          patientName: patientName,
          date: formattedDate,
          icdCodes: icdCodes,
          filePath: filePath,
          fileName: fileName,
          fileType: fileType,
          prescriberName: prescriberName,
          prescriberEmail: prescriberEmail,
        );
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access denied. Please check your permissions.'),
            backgroundColor: _errorColor,
          ),
        );
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prescription not found'),
            backgroundColor: _errorColor,
          ),
        );
      } else {
        try {
          final responseData = jsonDecode(response.body);
          String errorMessage = 'Failed to fetch prescription details';
          if (responseData['detail'] != null) {
            errorMessage = responseData['detail'];
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: _errorColor),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to fetch: ${response.statusCode}'),
              backgroundColor: _errorColor,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      Navigator.pop(context);
      print('Fetch prescription error: $e');
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: _errorColor,
        ),
      );
    }
  }

  void _showPrescriptionDialog({
    required String patientName,
    required String date,
    required List<String> icdCodes,
    required String filePath,
    required String fileName,
    required String fileType,
    required String prescriberName,
    required String prescriberEmail,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _secondaryColor],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Prescription Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 20, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Patient Info
                      _buildInfoRow(
                        icon: Icons.person_outline,
                        title: 'Patient',
                        value: patientName,
                      ),
                      SizedBox(height: 12),

                      // Date
                      _buildInfoRow(
                        icon: Icons.calendar_today_outlined,
                        title: 'Date',
                        value: date,
                      ),
                      SizedBox(height: 12),

                      // Prescriber Info
                      if (prescriberName.isNotEmpty)
                        _buildInfoRow(
                          icon: Icons.medical_services_outlined,
                          title: 'Prescriber',
                          value: prescriberName,
                          subtitle: prescriberEmail,
                        ),

                      // ICD Codes
                      if (icdCodes.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Text(
                          'ICD Codes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: icdCodes.map((code) {
                            return Chip(
                              label: Text(code),
                              backgroundColor: _primaryColor.withOpacity(0.1),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: _primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 16),
                      ],

                      // File Info
                      if (fileName.isNotEmpty)
                        _buildInfoRow(
                          icon: Icons.attach_file_outlined,
                          title: 'File',
                          value: fileName,
                          subtitle: fileType,
                        ),

                      // Uploaded Image Section
                      if (filePath.isNotEmpty) ...[
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _textDisabled.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Uploaded Prescription',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                              ),
                              SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                height: 250,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _textDisabled.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: _buildPrescriptionImage(filePath),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 24),

                      // Close Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Close',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _textDisabled.withOpacity(0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Icon(icon, size: 18, color: _primaryColor)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionImage(String filePath) {
    print('File path received: $filePath');

    String imageUrl;

    if (filePath.startsWith('http')) {
      imageUrl = filePath;
    } else if (filePath.contains('/')) {
      final baseUrl = 'https://omb-api.omegambs.site';
      imageUrl = filePath.startsWith('/')
          ? '$baseUrl$filePath'
          : '$baseUrl/$filePath';
    } else {
      final baseUrl = 'https://omb-api.omegambs.site';
      imageUrl = '$baseUrl/uploads/$filePath';

      print('Constructed image URL: $imageUrl');
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      headers: {'Accept': 'image/*'},
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: _backgroundColor,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _primaryColor),
                SizedBox(height: 12),
                Text(
                  'Loading image...',
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
              ],
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('Image loading error: $error');
        print('Failed URL: $imageUrl');

        final fallbackUrl = 'https://omb-api.omegambs.site/uploads/$filePath';

        if (imageUrl != fallbackUrl) {
          return Image.network(
            fallbackUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error2, stackTrace2) {
              return _buildImageErrorState(filePath);
            },
          );
        }

        return _buildImageErrorState(filePath);
      },
    );
  }

  Widget _buildImageErrorState(String filePath) {
    return Container(
      color: _backgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: _textDisabled, size: 50),
          SizedBox(height: 12),
          Text(
            'Unable to load image',
            style: TextStyle(
              fontSize: 14,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'File: ${filePath.length > 30 ? '${filePath.substring(0, 30)}...' : filePath}',
            style: TextStyle(fontSize: 11, color: _textDisabled),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Container(
        color: _backgroundColor,
        child: Column(
          children: [
            // Drawer Header
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Ω',
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Omega Medical',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Billing Inc.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(height: 20),
                  _buildDrawerItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Prescription Dashboard',
                    isSelected: _selectedDrawerIndex == 0,
                    onTap: () {
                      setState(() {
                        _selectedDrawerIndex = 0;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.cloud_upload_outlined,
                    title: 'Upload Prescription',
                    isSelected: _selectedDrawerIndex == 1,
                    onTap: () {
                      setState(() {
                        _selectedDrawerIndex = 1;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people_outline,
                    title: 'Users Management',
                    isSelected: _selectedDrawerIndex == 2,
                    onTap: () {
                      setState(() {
                        _selectedDrawerIndex = 2;
                      });
                      _fetchUsers();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            Container(
              padding: EdgeInsets.all(20),
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(Icons.logout_outlined, color: _errorColor),
                  ),
                ),
                title: Text(
                  'Logout',
                  style: TextStyle(
                    color: _errorColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _logoutUser();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tileColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logoutUser() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_outlined, color: _errorColor, size: 40),
              SizedBox(height: 16),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Are you sure you want to logout?',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _errorColor,
                      ),
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('access_token');
        await prefs.remove('token_type');
        await prefs.remove('user_email');
        await prefs.remove('user_name');

        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: _successColor,
          ),
        );
      } catch (e) {
        print('Logout error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: ${e.toString()}'),
            backgroundColor: _errorColor,
          ),
        );
      }
    }
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? _primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : _textSecondary,
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : _textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
