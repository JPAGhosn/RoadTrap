import 'package:flutter/material.dart';
import 'package:roadtrap/homeview.dart';

class RawPage extends StatefulWidget {
  const RawPage({super.key});

  @override
  State<RawPage> createState() => _RawPageState();
}

class _RawPageState extends State<RawPage> {
  var currentPage = 1;
  List<Map<String, dynamic>> payloads = List.empty();

  int totalPages = 1;

  @override
  void initState() {

    getTotal();

    // TODO: implement initState
    super.initState();
  }

  getTotal() async {
    totalPages = await DatabaseHelper.instance.getPayloadTotalPages();
    await loadPayload(currentPage);
  }

  loadPayload(int page) async {
    payloads = await DatabaseHelper.instance.getPayloadPatch(page: page);
    setState(() {
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Raw Stored Data"),
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Color(0xffF0F0F0),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
        actions: [],
        iconTheme: IconThemeData().copyWith(
            color: Colors.black
        ),
      ),
      body: Container(
        child: Column(
          children: [
            Expanded(child: ListView(
              children: [
                ...payloads.map((p) => ListTile(
                  leading: Icon(Icons.data_object),
                  title: Text("${DateTime.fromMillisecondsSinceEpoch(p['timestamp'] as int)}"),
                ))
              ],
            )),
            Container(
              height: 65,
              color: Colors.blue,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Text("Page: $currentPage / $totalPages", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
                    Expanded(child: Container()),
                    GestureDetector(onTap: (){
                      if(currentPage > 1) {
                        currentPage = currentPage-1;
                        loadPayload(currentPage);
                      }
                    }, child: Icon(Icons.west, color: Colors.white,)),
                    SizedBox(width: 20,),
                    GestureDetector(onTap: (){
                      if(currentPage < totalPages) {
                        currentPage = currentPage+1;
                        loadPayload(currentPage);
                      }
                    },child: Icon(Icons.east, color: Colors.white,)),
                  ],
                ),
              ),
            )
          ],
        ),
      )
    );
  }
}
