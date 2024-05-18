import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;

    mapboxMap.annotations.createPointAnnotationManager().then((pointAnnotationManager) async {
      final ByteData bytes = await rootBundle.load('assets/marker.png');
      final Uint8List list = bytes.buffer.asUint8List();

      pointAnnotationManager.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(-80.1263, 35.7845)).toJson(),
        image: list,
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
        cameraOptions: CameraOptions(center: Point(coordinates: Position(-80.1263, 35.7845)).toJson(), zoom: 12.0),
        styleUri: MapboxStyles.MAPBOX_STREETS,
      ),
    );
  }
}
