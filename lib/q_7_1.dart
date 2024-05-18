import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  MapboxOptions.setAccessToken(dotenv.get('SDK_REGISTRY_TOKEN'));

  runApp(MaterialApp(home: MapPage()));
}

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapboxMap? mapboxMap;
  List<List<double>> coordinates = [];

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    _addLineLayer();
  }

  Future<void> _addLineLayer() async {
    const geoJson = '''
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": []
          }
        }
      ]
    }
    ''';

    await mapboxMap?.style.addSource(GeoJsonSource(id: "line_source", data: geoJson));
    await mapboxMap?.style.addLayer(LineLayer(
      id: "line_layer",
      sourceId: "line_source",
      lineColor: Colors.black.value,
      lineWidth: 5.0,
    ));
  }

  Future<void> _updateLineLayer() async {
    final geoJson = '''
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates": ${coordinates.map((c) => '[${c[0]}, ${c[1]}]').toList()}
          }
        }
      ]
    }
    ''';

    await mapboxMap?.style.setStyleSourceProperty("line_source", "data", geoJson);
  }

  void _onMapTapped(ScreenCoordinate screenCoordinate) async {
    final point = await mapboxMap?.coordinateForPixel(screenCoordinate);
    if (point != null) {
      final coordinatesList = point['coordinates'] as List<dynamic>?;
      if (coordinatesList != null) {
        final latitude = coordinatesList[1] as double;
        final longitude = coordinatesList[0] as double;
        setState(() {
          coordinates.add([longitude, latitude]);
          _updateLineLayer();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) async {
          if (mapboxMap != null) {
            ScreenCoordinate screenCoordinate = ScreenCoordinate(
              x: details.localPosition.dx,
              y: details.localPosition.dy,
            );
            _onMapTapped(screenCoordinate);
          }
        },
        child: MapWidget(
          key: const ValueKey("mapWidget"),
          onMapCreated: _onMapCreated,
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(-77.0369, 38.9072)).toJson(),
            zoom: 12.0,
          ),
          styleUri: MapboxStyles.MAPBOX_STREETS,
        ),
      ),
    );
  }
}
