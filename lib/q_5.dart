import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  void _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;

    // Add marker
    mapboxMap.annotations.createPointAnnotationManager().then((pointAnnotationManager) async {
      final ByteData bytes = await rootBundle.load('assets/marker.png');
      final Uint8List list = bytes.buffer.asUint8List();

      pointAnnotationManager.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(-77.0499, 38.9292)).toJson(),
        image: list,
      ));
    });

    // line
    mapboxMap.style.addSource(GeoJsonSource(
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
    mapboxMap.style.addLayer(LineLayer(
      id: "line_layer",
      sourceId: "line_source",
      lineColor: Colors.black.value,
      lineWidth: 5.0,
    ));

    // highlighted area
    mapboxMap.style.addSource(GeoJsonSource(
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
                    [-77.0369, 38.9082],
                    [-77.0359, 38.9082],
                    [-77.0359, 38.9072],
                    [-77.0369, 38.9072]
                  ]
                ]
              }
            }
          ]
        }
      ''',
    ));
    mapboxMap.style.addLayer(FillLayer(
      id: "highlight_layer",
      sourceId: "highlight_source",
      fillColor: Colors.red.value,
      fillOpacity: 0.5,
    ));

    // directional arrows
    await _addDirectionalArrows();
  }

  Future<void> _addDirectionalArrows() async {
    final ByteData arrowBytes = await rootBundle.load('assets/arrow.png');
    final Uint8List arrowList = arrowBytes.buffer.asUint8List();

    // point annotations for each segment of the line with rotation
    final List<Position> coordinates = [
      Position(-77.0369, 38.9072),
      Position(-77.0459, 38.9082),
      Position(-77.0549, 38.9092),
      Position(-77.0639, 38.9102),
      Position(-77.0729, 38.9112),
      Position(-77.0819, 38.9122)
    ];

    mapboxMap!.annotations.createPointAnnotationManager().then((pointAnnotationManager) async {
      for (int i = 0; i < coordinates.length - 1; i++) {
        final start = coordinates[i];
        final end = coordinates[i + 1];
        final rotation = _calculateRotation(start, end);

        pointAnnotationManager.create(PointAnnotationOptions(
          geometry: Point(coordinates: start).toJson(),
          image: arrowList,
          iconRotate: rotation,
        ));
      }
    });
  }

  double _calculateRotation(Position start, Position end) {
    final dx = end.lng - start.lng;
    final dy = end.lat - start.lat;
    return atan2(dy, dx) * 180 / pi;
  }

  Future<void> addMarker(MapboxMap mapboxMap,double y,double x,double iconSize)async {
    mapboxMap.annotations.createPointAnnotationManager().then((pointAnnotationManager) async {
      final ByteData bytes = await rootBundle.load('assets/marker.png');
      final Uint8List list = bytes.buffer.asUint8List();

      pointAnnotationManager.create(PointAnnotationOptions(
          geometry: Point(coordinates: Position(y, x)).toJson(),
          image: list,
          iconSize: iconSize,
          iconOffset: [-5.0,10.0]

      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Test App'),
      ),
      body: MapWidget(
        key: const ValueKey("mapWidget"),
        onMapCreated: _onMapCreated,
        onTapListener: (screenCoordinate) async {
          //pointAnnotationManager?.deleteAll();
          // setState(()  {}); if you want to add only one marker uncomment deleteAll and setState
          addMarker(mapboxMap!, screenCoordinate.y, screenCoordinate.x,0.2);
        },
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(-77.0499, 38.9292)).toJson(),
          zoom: 12.0,
        ),
        styleUri: MapboxStyles.MAPBOX_STREETS,
      ),
    );

}

}
