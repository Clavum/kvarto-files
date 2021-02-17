import 'dart:async';

import 'package:database_intro/models/game';
import 'package:database_intro/models/player.dart';
import 'package:database_intro/models/piece.dart';
import 'package:database_intro/utils/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:database_intro/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'dart:collection';

class RightNav extends StatefulWidget {
  @override
  _RightNavState createState() => _RightNavState();
}

class _RightNavState extends State<RightNav> {
  HomeState homeState = new HomeState();
  var db = new DatabaseHelper();
  final List names = [
    "Red Duct", "Red Cube", "Red Frame", "Red Plank", "Red Pipe", "Red Can", "Red Ring", "Red Oreo", "Red Tent", "Red Roof", "Red Arrow", "Red Wedge", "Red Weird", "Red Bit", "Red Nut", "Red Bolt",
    "Yellow Duct", "Yellow Cube", "Yellow Frame", "Yellow Plank", "Yellow Pipe", "Yellow Can", "Yellow Ring", "Yellow Oreo", "Yellow Tent", "Yellow Roof", "Yellow Arrow", "Yellow Wedge", "Yellow Weird", "Yellow Bit", "Yellow Nut", "Yellow Bolt",
    "Green Duct", "Green Cube", "Green Frame", "Green Plank", "Green Pipe", "Green Can", "Green Ring", "Green Oreo", "Green Tent", "Green Roof", "Green Arrow", "Green Wedge", "Green Weird", "Green Bit", "Green Nut", "Green Bolt",
    "Blue Duct", "Blue Cube", "Blue Frame", "Blue Plank", "Blue Pipe", "Blue Can", "Blue Ring", "Blue Oreo", "Blue Tent", "Blue Roof", "Blue Arrow", "Blue Wedge", "Blue Weird", "Blue Bit", "Blue Nut", "Blue Bolt"
  ];

  final List<int> _pieceUses = new List(64);
  final FirebaseDatabase database = FirebaseDatabase.instance;
  DatabaseReference databaseReference;

  var preventOnlyOnePieceUpdate = false;

  @override
  void initState() {
    super.initState();

    _readPieceUsage();

    database.reference().child("Pieces").onChildAdded.listen(_onPieceEvent);
    database.reference().child("Pieces").onChildChanged.listen(_onPieceEvent);

    for (int i = 0; i < 64; i++) {
      _pieceUses[i] = 0;
    }

  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void setState(fn) {
    if(mounted){
      super.setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      backgroundColor: Colors.blueGrey,
      body: (_pieceUses[63] == 0) //Won't ever be 0. But if there's an issue getting pieces, this will cause it to load forever
          ? new Center(child: Text("Loading...", style: new TextStyle(fontSize: 60.0, color: Colors.white),))
          : new Container(
        child: new Row(
          children: <Widget>[
            new Expanded(
              child: new Column(
                children: <Widget>[
                  new Padding(padding: EdgeInsets.all(20.0)),
                  new Expanded(child: newButtonGrid(Colors.red)),
                  new Expanded(child: newButtonGrid(Colors.green)),
                  new Padding(padding: EdgeInsets.all(20.0))
                ],
                mainAxisAlignment: MainAxisAlignment.center,
              ),
            ),
            new Expanded(
              child: new Column(
                children: <Widget>[
                  new Padding(padding: EdgeInsets.all(20.0)),
                  new Expanded(child: newButtonGrid(Colors.yellow)),
                  new Expanded(child: newButtonGrid(Colors.blue)),
                  new Padding(padding: EdgeInsets.all(20.0))
                ],
                mainAxisAlignment: MainAxisAlignment.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Container getNewContainer(colorSkip, text, number, asset1, color) {
    return new Container(
      width: 45.0,
      height: 45.0,
      child: new Container(
        width: 40.0,
        height: 40.0,
        padding: EdgeInsets.all(2.0),
        child: new Stack(
          children: <Widget>[
            new Image.asset(asset1),
            new Center(
                child: new Text(
                  "$text",
                  textAlign: TextAlign.center,
                  style: new TextStyle(
                      color: Colors.white),
                )),
          ],
        ),
      ),
    );
  }

  Container newButtonGrid(Color color) {
    var colorSkip;
    var colorAddon;
    if (color == Colors.red) {
      colorSkip = 0;
      colorAddon = "_red";
    }
    if (color == Colors.green) {
      colorSkip = 16;
      colorAddon = "_green";
    }
    if (color == Colors.yellow) {
      colorSkip = 32;
      colorAddon = "_yellow";
    }
    if (color == Colors.blue) {
      colorSkip = 48;
      colorAddon = "_blue";
    }
    return new Container(
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Duct\n${_pieceUses[0 + colorSkip]}",
                        0,
                        "lib/images/duct$colorAddon.png",
                        color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Pipe\n${_pieceUses[4 + colorSkip]}",
                        4,
                        "lib/images/pipe$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Tent\n${_pieceUses[8 + colorSkip]}",
                        8,
                        "lib/images/tent$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Weird\n${_pieceUses[12 + colorSkip]}",
                        12,
                        "lib/images/weird$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
              ],
            ),
            new Padding(padding: EdgeInsets.all(4.0)),
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Cube\n${_pieceUses[1 + colorSkip]}",
                        1,
                        "lib/images/cube$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Can\n${_pieceUses[5 + colorSkip]}",
                        5,
                        "lib/images/can$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Roof\n${_pieceUses[9 + colorSkip]}",
                        9,
                        "lib/images/roof$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Bit\n${_pieceUses[13 + colorSkip]}",
                        13,
                        "lib/images/bit$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
              ],
            ),
            new Padding(padding: EdgeInsets.all(4.0)),
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Frame\n${_pieceUses[2 + colorSkip]}",
                        2,
                        "lib/images/frame$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Ring\n${_pieceUses[6 + colorSkip]}",
                        6,
                        "lib/images/ring$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Arrow\n${_pieceUses[10 + colorSkip]}",
                        10,
                        "lib/images/arrow$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Nut\n${_pieceUses[14 + colorSkip]}",
                        14,
                        "lib/images/nut$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
              ],
            ),
            new Padding(padding: EdgeInsets.all(4.0)),
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Plank\n${_pieceUses[3 + colorSkip]}",
                        3,
                        "lib/images/plank$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Oreo\n${_pieceUses[7 + colorSkip]}",
                        7,
                        "lib/images/oreo$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Wedge\n${_pieceUses[11 + colorSkip]}",
                        11,
                        "lib/images/wedge$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(
                        colorSkip,
                        "Bolt\n${_pieceUses[15 + colorSkip]}",
                        15,
                        "lib/images/bolt$colorAddon.png", color)),
                new Padding(padding: EdgeInsets.all(8.0)),
              ],
            ),
          ],
        ));
  }

//  Future<List<dynamic>> _getAllPieces() async {
//    return db.getAllPieces();
//  }

  _readPieceUsage() async {
    if (!preventOnlyOnePieceUpdate) {
      preventOnlyOnePieceUpdate = true;
      for (int i = 0; i < 64; i++) {
        if (i == 0) {
          await database.reference().child("Pieces").orderByChild("piece").equalTo(i).once().then((DataSnapshot snapshot) {
            var data = snapshot.value;
            var excludedPieces = 0;
            snapshot.value.values.toList().forEach((item) {
              if (item["gamemode"] == "16 Pieces") {
                excludedPieces++;
              }
            });
            try {
              setState(() {
                _pieceUses[i] = data.length - excludedPieces;
              });
            } catch (e) {
              setState(() {
                _pieceUses[i] = 0;
              });
            }
            preventOnlyOnePieceUpdate = false;
          });
        } else {
          database.reference().child("Pieces").orderByChild("piece").equalTo(i).once().then((DataSnapshot snapshot) {
            var data = snapshot.value;
            var excludedPieces = 0;
            snapshot.value.values.toList().forEach((item) {
              if (item["gamemode"] == "16 Pieces") {
                excludedPieces++;
              }
            });
            try {
              setState(() {
                _pieceUses[i] = data.length - excludedPieces;
              });
            } catch (e) {
              setState(() {
                _pieceUses[i] = 0;
              });
            }
          });
        }
      }
    }
  }

  void _onPieceEvent(Event event) {
    setState(() {
      _readPieceUsage();
    });
  }
}

//Copyright 2021, Joseph Winningham, All rights reserved.
