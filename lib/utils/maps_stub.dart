import 'package:flutter/widgets.dart'; // Import this for StatelessWidget and Widget

// 1. Add 'extends StatelessWidget' so it is a valid UI element
class GoogleMap extends StatelessWidget {
  final CameraPosition initialCameraPosition;
  final void Function(GoogleMapController)? onMapCreated;
  final Set<Marker> markers;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final MapType mapType;

  const GoogleMap({
    super.key, // Use super.key for modern Flutter
    required this.initialCameraPosition,
    this.onMapCreated,
    this.markers = const {},
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = true,
    this.mapType = MapType.normal,
  });

  // Since this is only used for the web build to prevent crashes,
  // we return an empty box.
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class GoogleMapController {
  // 2. Add this method so your map_screen.dart can call it without error
  Future<void> animateCamera(CameraUpdate update) async {}
}

class CameraPosition {
  final LatLng target;
  final double zoom;
  const CameraPosition({required this.target, this.zoom = 10});
}

class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

class Marker {
  final MarkerId markerId;
  final LatLng position;
  final InfoWindow infoWindow;
  final BitmapDescriptor icon;
  final VoidCallback? onTap;

  const Marker({
    required this.markerId,
    required this.position,
    this.infoWindow = InfoWindow.noText,
    this.icon = BitmapDescriptor.defaultMarker,
    this.onTap,
  });
}

class MarkerId {
  final String value;
  const MarkerId(this.value);
}

class InfoWindow {
  final String? title;
  final String? snippet;
  static const InfoWindow noText = InfoWindow();
  const InfoWindow({this.title, this.snippet});
}

class BitmapDescriptor {
  static const BitmapDescriptor defaultMarker = BitmapDescriptor._();
  static const double hueRed = 0;
  static const double hueBlue = 240;
  static const double hueGreen = 120;
  static const double hueOrange = 30;
  const BitmapDescriptor._();
  static BitmapDescriptor defaultMarkerWithHue(double hue) =>
      const BitmapDescriptor._();
}

class CameraUpdate {
  static CameraUpdate newCameraPosition(CameraPosition pos) =>
      const CameraUpdate._();
  const CameraUpdate._();
}

enum MapType { normal, satellite, terrain, hybrid }

// VoidCallback is already in flutter/widgets.dart, so we don't need to redefine it.