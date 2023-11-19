import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:roadtrap/analytics_page.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class HomeView extends StatefulWidget {
  @override
  _HomeViewState createState() => _HomeViewState();
}

class CombinedData {
  GyroscopeEvent? gyroscopeData;
  AccelerometerEvent? accelerometerData;
  Position? position;

  CombinedData(this.gyroscopeData, this.accelerometerData, this.position);
}

class _HomeViewState extends State<HomeView> {

  StreamSubscription? gyroscopeSubscription;
  StreamSubscription? accelerometerSubscription;
  StreamSubscription? positionSubscription;
  StreamSubscription? combinedSubscription;
  double? speed;
  Position? position;
  GyroscopeEvent? gyroscopeData;
  AccelerometerEvent? accelerometerData;
  String time = "";

  MqttServerClient? client;

  DateTime? timeCollectionStarted;
  DateTime? timeCollectionStopped;

  double xOffset = 0.0;
  final double dragThreshold = 100.0;

  bool collectionStarted = false;

  Duration diffTime = Duration();

  String formattedTime = "";

  int rowCount = 0;

  @override
  void initState() {

    print("!!!!!!!!!!! INITIALIZING !!!!!!!!!!");

    client = MqttServerClient.withPort(
        "test.mosquitto.org",
        "jeanpaulabighosnroadtrap",
        1883
    );

    client!.logging(on: false);
    // client!.onConnected = () {
    //   print('MQTT_LOGS:: Connected');
    // };
    // client!.onDisconnected = (){
    //   print('MQTT_LOGS:: Disconnected');
    // };
    // client!.onUnsubscribed = (topic) {
    //   print('MQTT_LOGS:: Subscribed topic: $topic');
    // };
    // client!.onSubscribed = (topic){
    //   print('MQTT_LOGS:: Failed to subscribe $topic');
    // };
    // client!.onSubscribeFail = (topic) {
    //   print('MQTT_LOGS:: Unsubscribed topic: $topic');
    // };
    // client!.pongCallback = (){
    //   print('MQTT_LOGS:: Ping response client callback invoked');
    // };
    client!.keepAlivePeriod = 60;
    // client!.logging(on: true);
    client!.setProtocolV311();

    init();

    // TODO: implement initState
    super.initState();
  }

  init() async {
    await Geolocator.requestPermission();

    try {
      await client!.connect();
    } catch (e) {
      print('Exception: $e');
      client!.disconnect();
    }

    combinedSubscription = getCombinedStream()
        .throttle((_) => Stream.value(true).delay(Duration(seconds: 1)))
        .listen((CombinedData data) async {
      if (client?.connectionStatus?.state == MqttConnectionState.connected) {
        final builder = MqttClientPayloadBuilder();
        final Map<String, dynamic> message = {
          "uid": FirebaseAuth.instance.currentUser?.uid,
          "gyroscope": {
            "x": data.gyroscopeData?.x,
            "y": data.gyroscopeData?.y,
            "z": data.gyroscopeData?.z,
          },
          "accelerometer": {
            "x": data.accelerometerData?.x,
            "y": data.accelerometerData?.y,
            "z": data.accelerometerData?.z,
          },
          "position": {
            "longitude": data.position?.longitude,
            "latitude": data.position?.latitude,
            "accuracy": data.position?.accuracy,
            "altitude": data.position?.altitude,
            "altitudeAccuracy": data.position?.altitudeAccuracy,
          },
          // "timestamp": DateFormat('dd/MM/yyyy-HH:mm:ss').format(DateTime.now()),
          "timestamp": DateTime.now().millisecondsSinceEpoch,
          "speedAccuracy": data.position?.speedAccuracy,
          "speed": data.position?.speed,
        };

        // print(jsonEncode(message));

        builder.addString(jsonEncode(message));

        setState(() {
          if(collectionStarted) {
            diffTime = DateTime.now().difference(timeCollectionStarted!);
          }
        });

        // TODO: client?.publishMessage('roadtrap_jp:datacollection:realtime', MqttQos.atLeastOnce, builder.payload!);

        if(collectionStarted) {
          await DatabaseHelper.instance.insertPayload(message);
        }
      }


      // Update your UI or state with the combined data
      setState(() {
        // Example:
        speed = data.position!.speed;
        gyroscopeData = data.gyroscopeData;
        accelerometerData = data.accelerometerData;
        position = data.position;
        time = DateFormat('dd/MM/yyyy-HH:mm:ss').format(DateTime.now());
      });
      // You can also send this data via MQTT here
    });
  }

  Stream<CombinedData> getCombinedStream() {
    return Rx.combineLatest3<GyroscopeEvent, AccelerometerEvent, Position, CombinedData>(
        gyroscopeEvents,
        accelerometerEvents,
        Geolocator.getPositionStream(),
            (gyroscopeData, accelerometerData, position) => CombinedData(gyroscopeData, accelerometerData, position)
    );
  }

  @override
  void dispose() {
    // Important: Always cancel the subscriptions when the widget is disposed to avoid memory leaks
    gyroscopeSubscription?.cancel();
    accelerometerSubscription?.cancel();
    positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("RoadTrap"),
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Color(0xffF0F0F0),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
        actions: [
          GestureDetector(
            onTap: (){
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => AnalyticsPage()));
            },
            child: Icon(
              Icons.analytics,
              color: Colors.grey,
              size: 35.0,
              semanticLabel: 'Text to announce in accessibility modes',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0, left: 12),
            child: CircleAvatar(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          children: [
            SizedBox(height: 13,),
            _timeAndSpeed,
            SizedBox(height: 13,),
            _location,
            SizedBox(height: 13,),
            Row(
              children: [
                // _gyro,
                // _accelero
                Expanded(
                  child: _gyro,
                ),
                SizedBox(width: 10,),
                Expanded(
                  child: _accelero,
                ),
                SizedBox(width: 10,),
              ],
            ),
            SizedBox(height: 13,),
            Container(
              alignment: Alignment.center,
              height: 10,
              child: divider(),
            ),
            SizedBox(height: 13,),
            _guesser,
            SizedBox(height: 13,),
            _chooser,
            SizedBox(height: 25,),
            SizedBox(
                width: double.infinity,
                height:60,
                child: ElevatedButton(onPressed: () async {
                  // get the number of rows collected
                  try {
                    rowCount = await DatabaseHelper.instance.getPayloadRowCount();
                  }
                  catch(e) {
                    print(e);
                  }
                  setState(() {
                    if(collectionStarted) {
                      timeCollectionStopped = DateTime.now();
                      // final diffTime = timeCollectionStopped!.difference(timeCollectionStarted!);
                      setState(() {
                        final snackBar = SnackBar(
                          content: Text("${formattedTime} - $rowCount"),
                          action: SnackBarAction(
                            label: 'Ok',
                            onPressed: () {
                              // Code to undo the change.
                            },
                          ),
                        );

                        ScaffoldMessenger.of(context).showSnackBar(snackBar);

                        timeCollectionStarted = null;
                        timeCollectionStopped = null;
                        diffTime = Duration.zero;
                      });
                    }
                    else {
                      timeCollectionStarted = DateTime.now();
                    }
                    collectionStarted = !collectionStarted;
                  });
                }, child: Text(collectionStarted ? "Stop Collection" : "Start Collection"))
            ),
            SizedBox(height: 13,),
            Text((){
              int hours = diffTime.inHours;
              int minutes = diffTime.inMinutes % 60;
              int seconds = diffTime.inSeconds % 60;

              formattedTime = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
              return formattedTime;
            }())
            // ListView(
            //   children: [
            //     ListTile(title: Text('Speed: $speed')),
            //     ListTile(title: Text('Gyroscope: $gyroscopeData')),
            //     ListTile(title: Text('Accelerometer: $accelerometerData')),
            //     ListTile(title: Text('Location: $position')),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  get _chooser {
    return LayoutBuilder(
        builder: (context, c) {
          return Row(
            children: [
              button(c.maxWidth, Image.asset("images/bump.png"), _bumpPressed),
              SizedBox(width: 13,),
              button(c.maxWidth, Image.asset("images/pothole.png"), _potholePressed),
              SizedBox(width: 13,),
              button(c.maxWidth, Image.asset("images/hazard.png"), _hazardPressed),
            ],
          );
        }
    );
  }

  _bumpPressed(){
    DatabaseHelper.instance.insertChooser("Bump");
  }
  _potholePressed(){
    DatabaseHelper.instance.insertChooser("Pothole");
  }
  _hazardPressed(){
    DatabaseHelper.instance.insertChooser("Hazard");
  }

  button(double parentWidth, Widget icon, void Function() func) {
    double height = (parentWidth / 3) - 2 * 13 ;
    return Expanded(
      child: DataContainer(
          onTap: func,
          height: height,
          child: Container(
            child: icon,
          )
      ),
    );
  }

  get _gyro {
    return DataContainer(
        padding: const EdgeInsets.only(),
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0, top: 15, bottom: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Gyroscope:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: TextDecoration.underline),
              ),
              SizedBox(height: 7,),
              Row(
                children: [
                  _dataItem("x", "${gyroscopeData?.x.toStringAsFixed(2)}"),
                  SizedBox(width: 10,),
                  _dataItem("y", "${gyroscopeData?.y.toStringAsFixed(2)}"),
                  SizedBox(width: 10,),
                  _dataItem("z", "${accelerometerData?.z.toStringAsFixed(2)}"),
                ],
              ),
              SizedBox(height: 7,),
              Text("Rotate Left", style: TextStyle(color: Color(0xff269200), fontWeight: FontWeight.bold)),
            ],
          ),
        )
    );
  }

  get _guesser {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          xOffset += details.primaryDelta ?? 0;
        });
      },
      onHorizontalDragEnd: (details) {

        if (xOffset > dragThreshold) {
          // Dragged right
          print("right");
        } else if (xOffset < -dragThreshold) {
          // Dragged left
          print("left");
        }

        // Add animation to slide back to original position
        if (xOffset.abs() > dragThreshold) {
          // If drag is more than threshold, trigger action
          // performAction();
        }

        setState(() {
          xOffset = 0.0;
        });
      },
      child: DataContainer(height: 100, child: AnimatedContainer(
        duration: Duration(milliseconds: 20),
        transform: Matrix4.translationValues(xOffset, 0, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Row(
              children: [
                Icon(Icons.west, color: Color(0xffE30000),),
                SizedBox(width: 10,),
                Icon(Icons.cancel_outlined, color: Color(0xffE30000),)
              ],
            ),
            Text("Bump?", style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),),
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xff269200),),
                SizedBox(width: 10,),
                Icon(Icons.east, color: Color(0xff269200),),
              ],
            ),
          ],
        ),
      )),
    );
  }

  get _accelero {
    return DataContainer(
        padding: const EdgeInsets.only(),
        child: Padding(
          padding: const EdgeInsets.only(left: 20.0, top: 15, bottom: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Accelerometer:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: TextDecoration.underline),
              ),
              SizedBox(height: 7,),
              Row(
                children: [
                  _dataItem("x", "${accelerometerData?.x.toStringAsFixed(2)}"),
                  SizedBox(width: 10,),
                  _dataItem("y", "${accelerometerData?.y.toStringAsFixed(2)}"),
                  SizedBox(width: 10,),
                  _dataItem("z", "${accelerometerData?.z.toStringAsFixed(2)}"),
                ],
              ),
              SizedBox(height: 7,),
              Text("Up", style: TextStyle(color: Color(0xff269200), fontWeight: FontWeight.bold)),
            ],
          ),
        )
    );;
  }

  divider({double height = 3, Color color = const Color(0xffF0F0F0)}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color: color,
      ),
    );
  }

  get _location {
    return DataContainer(
        padding: const EdgeInsets.only(),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 15, bottom: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Location:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: TextDecoration.underline),
                  ),
                  SizedBox(height: 7,),
                  Row(
                    children: [
                      _dataItem("longitude", "${position?.longitude.toStringAsFixed(3)}"),
                      SizedBox(width: 10,),
                      _dataItem("latitude", "${position?.latitude.toStringAsFixed(3)}"),
                      SizedBox(width: 10,),
                      _dataItem("Altitude", "${position?.altitude.toStringAsFixed(3)}"),
                    ],
                  ),
                  SizedBox(height: 7,),
                  Text("Mar Elias Road", style: TextStyle(color: Color(0xff269200), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            // SizedBox(width: 20,),
            // Expanded(child: Container(
            //   color: Colors.grey,
            //   height: 150,
            // )),
          ],
        ));
  }


  get _timeAndSpeed {
    return DataContainer(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Time Stamp:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: TextDecoration.underline),
              ),
              SizedBox(height: 7,),
              Text(time, style: TextStyle(color: Color(0xff269200), fontWeight: FontWeight.bold))
            ],
          ),
          Expanded(child: Container()),
          Text("${speed?.toStringAsFixed(2)} Km/h", style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),)
        ],
      ),
    );
  }

  _dataItem(String title, String value) {
    return Column(
      children: [
        Text(title, style: TextStyle(
            color: Color(0xff8C8C8C)
        ),),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold),),
      ],
    );
  }

}

class DataContainer extends StatelessWidget {

  final Widget child;
  final EdgeInsets padding;
  final double? height;
  final void Function()? onTap;

  const DataContainer({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15), this.height, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: Color(0xffF0F0F0),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10.0),
          overlayColor: const MaterialStatePropertyAll(Color(0xff269200)),
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class DatabaseHelper {
  static final _dbName = 'myDatabase.db';
  static final _dbVersion = 1;
  static final _tableName = 'payloads';
  static final _tableName2 = 'choosers';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''    
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY,
            uid TEXT,
            gyro_x REAL,
            gyro_y REAL,
            gyro_z REAL,
            acc_x REAL,
            acc_y REAL,
            acc_z REAL,
            longitude REAL,
            latitude REAL,
            accuracy REAL,
            altitude REAL,
            altitudeAccuracy REAL,
            timestamp INTEGER,
            speedAccuracy REAL,
            speed REAL
          );
          ''');

    await db.execute('''    
    CREATE TABLE $_tableName2 (
        id INTEGER PRIMARY KEY,
        uid TEXT,
        timestamp INTEGER,
        type TEXT);
          ''');
  }

  Future<int> insert(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(_tableName, row);
  }

  insertPayload(Map<String, dynamic> payload) async {

    final uid = payload['uid'];
    final gyro_x = payload['gyroscope']['x'];
    final gyro_y = payload['gyroscope']['y'];
    final gyro_z = payload['gyroscope']['z'];
    final acc_x = payload['accelerometer']['x'];
    final acc_y = payload['accelerometer']['y'];
    final acc_z = payload['accelerometer']['z'];
    final longitude = payload['position']['longitude'];
    final latitude = payload['position']['latitude'];
    final accuracy = payload['position']['accuracy'];
    final altitude = payload['position']['altitude'];
    final altitudeAccuracy = payload['position']['altitudeAccuracy'];
    final timestamp = payload['timestamp'];
    final speedAccuracy = payload['speedAccuracy'];
    final speed = payload['speed'];

    await insert({
      "uid": uid,
      "gyro_x": "$gyro_x",
      "gyro_y": gyro_y,
      "gyro_z": gyro_z,
      "acc_x": acc_x,
      "acc_y": acc_y,
      "acc_z": acc_z,
      "longitude": longitude,
      "latitude": latitude,
      "accuracy": accuracy,
      "altitude": altitude,
      "altitudeAccuracy": altitudeAccuracy,
      "timestamp": timestamp,
      "speedAccuracy": speedAccuracy,
      "speed": speed
    });
  }

  insertChooser(String chooser) async {
    Database db = await instance.database;
    return await db.insert(_tableName2, {
      "uid": FirebaseAuth.instance.currentUser?.uid,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "type": chooser
    });
  }

  getPayloadRowCount() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> queryResult = await db.rawQuery('SELECT COUNT(*) AS count FROM payloads');
    int count = Sqflite.firstIntValue(queryResult) ?? 0;
    return count;
  }

  getPayloadPatch({required int page}) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> queryResult = await db.rawQuery("""
            SELECT
              id,
              uid,
              gyro_x,
              gyro_y,
              gyro_z,
              acc_x,
              acc_y,
              acc_z,
              longitude,
              latitude,
              accuracy,
              altitude,
              altitudeAccuracy,
              timestamp,
              speedAccuracy,
              speed
            FROM payloads 
            ORDER BY timestamp DESC
            limit 20
            offset ${(page - 1 ) * 20}
    """);

    return queryResult;
  }

  getPayloadTotalPages() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> queryResult = await db.rawQuery('SELECT COUNT(*) AS pages FROM payloads');
    int pages = ((Sqflite.firstIntValue(queryResult) ?? 0) / 20).ceil();
    return pages;
  }

  sendToServer() async {
    Database db = await instance.database;
    final dbPath = await getDatabasesPath();
    final path =  join(dbPath, _dbName);
    final file = File(path);
    print(file.absolute);
    // File file = File(result.files.single.path!);
    var request = http.MultipartRequest('POST', Uri.parse("http://192.168.0.114:9433/data-sync"))
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();

    if (response.statusCode == 200) {
      print("File uploaded");
      await db.delete(_tableName);
      await db.delete(_tableName2);
    } else {
      print("Failed to upload file: ${response.statusCode}");
    }


    // final response = await request.send();
    //
    // if (response.statusCode == 200) {
    //   print('Database uploaded successfully');
    // } else {
    //   print('Failed to upload database');
    // }
  }
}

