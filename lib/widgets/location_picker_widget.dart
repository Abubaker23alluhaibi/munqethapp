import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../config/theme.dart';

class LocationPickerWidget extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final Function(double latitude, double longitude) onLocationSelected;
  final String? label;

  const LocationPickerWidget({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    required this.onLocationSelected,
    this.label,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      // Use initial location if provided, otherwise get current location
      if (widget.initialLatitude != null && widget.initialLongitude != null) {
        _selectedLocation = LatLng(
          widget.initialLatitude!,
          widget.initialLongitude!,
        );
        widget.onLocationSelected(
          widget.initialLatitude!,
          widget.initialLongitude!,
        );
      } else {
        final position = await _getCurrentLocation();
        if (position != null) {
          double lat = position.latitude;
          double lng = position.longitude;
          if (lat > 42 && lng < 40) {
            lat = position.longitude;
            lng = position.latitude;
          }
          _selectedLocation = LatLng(lat, lng);
          widget.onLocationSelected(lat, lng);
        } else {
          _selectedLocation = const LatLng(33.3152, 44.3661);
          widget.onLocationSelected(33.3152, 44.3661);
        }
      }
    } catch (e) {
      // Default to Baghdad on error
      _selectedLocation = const LatLng(33.3152, 44.3661);
      widget.onLocationSelected(33.3152, 44.3661);
      _errorMessage = 'تعذر الحصول على الموقع الحالي';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      return null;
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    widget.onLocationSelected(location.latitude, location.longitude);
  }

  Future<void> _getCurrentLocationButton() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final position = await _getCurrentLocation();
      if (position != null) {
        double lat = position.latitude;
        double lng = position.longitude;
        if (lat > 42 && lng < 40) {
          lat = position.longitude;
          lng = position.latitude;
        }
        final location = LatLng(lat, lng);
        setState(() {
          _selectedLocation = location;
        });
        widget.onLocationSelected(lat, lng);
        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(location, 15),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر الحصول على الموقع الحالي'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null) ...[
            Text(
              widget.label!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  if (_isLoading)
                    Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_selectedLocation != null)
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _selectedLocation!,
                        zoom: 15,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      onTap: _onMapTap,
                      markers: {
                        Marker(
                          markerId: const MarkerId('selected_location'),
                          position: _selectedLocation!,
                          draggable: true,
                          onDragEnd: (newPosition) {
                            setState(() {
                              _selectedLocation = newPosition;
                            });
                            widget.onLocationSelected(
                              newPosition.latitude,
                              newPosition.longitude,
                            );
                          },
                        ),
                      },
                      myLocationButtonEnabled: false,
                      myLocationEnabled: false,
                      zoomControlsEnabled: true,
                      mapType: MapType.normal,
                      buildingsEnabled: true,
                      trafficEnabled: false,
                      mapToolbarEnabled: false,
                      rotateGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                    ),
                  // Current location button
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: _getCurrentLocationButton,
                      child: Icon(
                        Icons.my_location,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  // Center marker indicator
                  if (!_isLoading && _selectedLocation != null)
                    const Center(
                      child: Icon(
                        Icons.location_on,
                        color: AppTheme.primaryColor,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'اضغط على الخريطة أو اسحب العلامة لتحديد موقعك',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}




