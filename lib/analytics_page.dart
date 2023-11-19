import 'package:flutter/material.dart';
import 'package:roadtrap/homeview.dart';
import 'package:roadtrap/raw.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Analytics"),
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Color(0xffF0F0F0),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
        actions: [],
        iconTheme: IconThemeData().copyWith(
          color: Colors.black
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          children: [
            SizedBox(height: 13,),
            LayoutBuilder(
              builder: (context, c) {
                return Row(
                  children: [
                    button(c.maxWidth, Image.asset("images/bump.png"), () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (context) => RawPage()));
                    }, "Raw"),
                    SizedBox(width: 13,),
                    button(c.maxWidth, Image.asset("images/bump.png"), () { }, "Insights"),
                    SizedBox(width: 13,),
                    button(c.maxWidth, Image.asset("images/bump.png"), () { }, "Logs")
                  ],
                );
              }
            ),
            SizedBox(height: 20,),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (){
                  print("Sending data to server...");
                  DatabaseHelper.instance.sendToServer();
                },
                child: Text("Send Data To Server"),
              ),
            )
          ],
        ),
      ),
    );
  }

  button(double parentWidth, Widget icon, VoidCallback func, String label) {
    double height = (parentWidth / 3) - 2 * 13 ;
    return Expanded(
      child: Column(
        children: [
          DataContainer(
              onTap: func,
              height: height,
              child: Container(
                child: icon,
              )
          ),
          SizedBox(height: 10,),
          Text(label)
        ],
      ),
    );
  }
}
