import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gif/gif.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'dart:math';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  MapboxOptions.setAccessToken(dotenv.get('SDK_REGISTRY_TOKEN'));

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapboxMap? mapboxMap;
  List<Offset> _tapPositions = [];
  List<Offset> _screenCoordinates = [];
  PointAnnotationManager? pointAnnotationManager;

  @override
  void initState() {
    super.initState();
    _tapPositions = [];
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    // Initialize the PointAnnotationManager
    pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();

    // Add marker on map create
    await addGifMarker(-77.0499, 38.9292);

    // Add initial layers and sources to the map
    _addInitialLayers();

    // Reduce memory use
    mapboxMap.reduceMemoryUse();
  }

  Future<void> _addInitialLayers() async {
    if (mapboxMap == null) return;

    // Line layer
    await mapboxMap!.style.addSource(GeoJsonSource(
      id: "line_source",
      data: '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": [
                  [-77.0369, 38.9072],
                  [-77.0459, 38.9082],
                  [-77.0549, 38.9092],
                  [-77.0639, 38.9102],
                  [-77.0729, 38.9112],
                  [-77.0819, 38.9122]
                ]
              }
            }
          ]
        }
      ''',
    ));
    await mapboxMap!.style.addLayer(LineLayer(
      id: "line_layer",
      sourceId: "line_source",
      lineColor: Colors.black.value,
      lineWidth: 5.0,
    ));

    // Highlighted area layer
    await mapboxMap!.style.addSource(GeoJsonSource(
      id: "highlight_source",
      data: '''
        {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Polygon",
                "coordinates": [
                  [
                    [-77.0369, 38.9072],
                    [-77.0369, 38.9122],
                    [-77.0319, 38.9122],
                    [-77.0319, 38.9072],
                    [-77.0369, 38.9072]
                  ]
                ]
              }
            }
          ]
        }
      ''',
    ));
    await mapboxMap!.style.addLayer(FillLayer(
      id: "highlight_layer",
      sourceId: "highlight_source",
      fillColor: Colors.red.value,
      fillOpacity: 0.5,
    ));

    // Directional arrows
    await _addDirectionalArrows();
  }

  Future<void> _addDirectionalArrows() async {
    final ByteData arrowBytes = await rootBundle.load('assets/arrow.png');
    final Uint8List arrowList = arrowBytes.buffer.asUint8List();

    // Point annotations for each segment of the line with rotation
    final List<Position> coordinates = [
      Position(-77.0369, 38.9072),
      Position(-77.0459, 38.9082),
      Position(-77.0549, 38.9092),
      Position(-77.0639, 38.9102),
      Position(-77.0729, 38.9112),
      Position(-77.0819, 38.9122)
    ];

    if (pointAnnotationManager == null) return;

    for (int i = 0; i < coordinates.length - 1; i++) {
      final start = coordinates[i];
      final end = coordinates[i + 1];
      final rotation = _calculateRotation(start, end);

      pointAnnotationManager!.create(PointAnnotationOptions(
        geometry: Point(coordinates: start).toJson(),
        image: arrowList,
        iconRotate: rotation,
      ));
    }
  }

  double _calculateRotation(Position start, Position end) {
    final dx = end.lng - start.lng;
    final dy = end.lat - start.lat;
    return atan2(dy, dx) * 180 / pi;
  }

  Future<void> addGifMarker(double latitude, double longitude) async {
    if (mapboxMap == null || pointAnnotationManager == null) return;

    final screenCoordinate = await mapboxMap!.pixelForCoordinate(
      Point(coordinates: Position(latitude, longitude)).toJson(),
    );

    setState(() {
      _tapPositions.add(Offset(longitude, latitude));
      _screenCoordinates.add(Offset(screenCoordinate.x, screenCoordinate.y));
    });
  }

  Future<void> _updateGifMarkers() async {
    if (mapboxMap == null) return;

    List<Offset> newScreenCoordinates = [];
    for (var position in _tapPositions) {
      final latitude = position.dy;
      final longitude = position.dx;

      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        print('Invalid latitude or longitude: ($latitude, $longitude)');
        continue; // Skip invalid positions
      }

      final screenCoordinate = await mapboxMap!.pixelForCoordinate(
        Point(coordinates: Position(latitude, longitude)).toJson(),
      );

      newScreenCoordinates.add(Offset(screenCoordinate.x, screenCoordinate.y));
    }

    setState(() {
      _screenCoordinates = newScreenCoordinates;
    });
  }

  void _handleCameraStateChange(CameraChangedEventData cameraState) async {
    print('Camera state has changed to: $cameraState');
    await _updateGifMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Test App'),
      ),
      body: Center(
        child: Stack(
          children: [
            MapWidget(
              key: const ValueKey("mapWidget"),
              onMapCreated: _onMapCreated,
              onTapListener: (screenCoordinate) async {
                await addGifMarker(screenCoordinate.y, screenCoordinate.x);
              },
              onCameraChangeListener: _handleCameraStateChange,
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(-77.0499, 38.9292)).toJson(),
                zoom: 12.0,
              ),
              styleUri: MapboxStyles.MAPBOX_STREETS,
            ),
            ..._screenCoordinates.map((Offset position) {
              return Positioned(
                left: position.dx,
                top: position.dy - 50, // Adjust icon position as needed
                child: Gif(
                  image: const AssetImage('assets/marker_gif.gif'),
                  autostart: Autostart.loop,
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
