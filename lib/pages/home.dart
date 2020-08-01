import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../clipper.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File _image;
  bool loading = false;
  final picker = ImagePicker();

  Future getImage() async {
    final pickedFile = await picker.getImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() {
      _image = File(pickedFile.path);
    });

    await classifyImage();
  }

  Future classifyImage() async {
    var recog = await Tflite.runModelOnImage(
      path: _image.path,
      threshold: 0.3,
    );
    print(recog);
  }

  @override
  void initState() {
    super.initState();
    setState(() {
      loading = true;
    });

    loginUser().then((value) => {});

    Tflite.loadModel(
      model: "assets/models/model.tflite",
      labels: "assets/models/dict.txt",
    ).then(
      (value) => (setState(() {
        loading = false;
      })),
    );
  }

  final _auth = FirebaseAuth.instance;

  Future loginUser() async {
    final AuthResult authResult = await _auth.signInAnonymously();
    final uid = authResult.user.uid;
    var user = await Firestore.instance.collection("users").document(uid).get();
    if (user != null) {
      await Firestore.instance
          .collection("users")
          .document(uid)
          .updateData({'online': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          headerWidget(),
          new Expanded(
            child: onlineUsersWidget(),
          )
        ],
      ),
    );
  }

  Widget headerWidget() {
    final double height = MediaQuery.of(context).size.height * 0.35;
    return Stack(
      children: [
        ClipPath(
          clipper: BezierClipper(),
          child: Container(
            color: Colors.deepPurple,
            height: height,
          ),
        ),
        Center(
          child: Padding(
            padding: EdgeInsets.only(top: 55),
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 50.0,
                  child: CircleAvatar(
                    radius: 48.0,
                    backgroundColor: Colors.white,
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Image(image: AssetImage('assets/images/mask.png')),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Ensure Mask",
                  style: TextStyle(fontSize: 25.0, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget onlineUsersWidget() {
    return StreamBuilder<QuerySnapshot>(
      stream: Firestore.instance.collection('users').snapshots(),
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) return new Text('Error: ${snapshot.error}');
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            return new Text('Loading...');
          default:
            var documents = snapshot.data.documents;
            return ListView.builder(
              itemCount: documents.length,
              itemBuilder: (context, i) {
                return _buildListItem(context, documents[i]);
              },
            );
        }
      },
    );
  }

  Widget _buildListItem(BuildContext context, DocumentSnapshot d) {
    return Card(
      child: ListTile(
        onTap: () {
          onListItemTap(d["uid"]);
        },
        title: Text(
          d["uname"],
          style: TextStyle(fontSize: 22),
        ),
        trailing: d["online"] == true
            ? Chip(
                label: Text("online", style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green[500],
              )
            : Chip(
                label: Text("offline", style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.grey[500],
              ),
      ),
    );
  }

  onListItemTap(String uid) {
    Navigator.of(context).pushNamed("/ensure");
  }
}
