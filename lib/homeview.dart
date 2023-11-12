import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sensors_plus/sensors_plus.dart';

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

  double xOffset = 0.0;
  final double dragThreshold = 100.0;

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
        .listen((CombinedData data) {
      if (client?.connectionStatus?.state == MqttConnectionState.connected) {
        final builder = MqttClientPayloadBuilder();
        final message = {
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
          "timestamp": DateFormat('dd/MM/yyyy-HH:mm:ss').format(DateTime.now()),
          "speedAccuracy": data.position?.speedAccuracy,
          "speed": data.position?.speed,
        };

        // print(jsonEncode(message));

        builder.addString(jsonEncode(message));

        client?.publishMessage('roadtrap_jp:datacollection:realtime', MqttQos.atLeastOnce, builder.payload!);
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
          Icon(
            Icons.analytics,
            color: Colors.grey,
            size: 35.0,
            semanticLabel: 'Text to announce in accessibility modes',
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

  _bumpPressed(){}
  _potholePressed(){}
  _hazardPressed(){}

  button(double parentWidth, Widget icon, void Function() func) {
    double height = (parentWidth / 3) - 2 * 13 ;
    return Expanded(
      child: GestureDetector(
        onTap: func,
        child: DataContainer(
            onTap: (){},
            height: height,
            child: Container(
              child: icon,
            )
        ),
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

