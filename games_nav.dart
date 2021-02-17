import 'dart:collection';

import 'package:database_intro/utils/database_helper.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:database_intro/main.dart';
import 'package:database_intro/models/game';
import 'package:database_intro/models/player.dart';
import 'package:intl/intl.dart';

class GamesNav extends StatefulWidget {
  @override
  GamesNavState createState() => GamesNavState();
}

class GamesNavState extends State<GamesNav> {
  HomeState homeState = new HomeState();
  var db = new DatabaseHelper();
  final List<Game> _gameList = <Game>[];

  final Map<String, String> _idToName = new HashMap<String, String>();

  final FirebaseDatabase database = FirebaseDatabase.instance;
  DatabaseReference databaseReference;

  List _games;

  List pieces;

  @override
  void initState() {
    super.initState();

    database.reference().child("Games").orderByChild("date").once().then((DataSnapshot snapshot) {
      try {
        Map<dynamic, dynamic> data = snapshot.value;
        List<dynamic> list = data.values.toList()..sort((a, b) => b['date'].compareTo(a['date']));
        setState(() {
          _games = list;
        });
      } catch (e) {
        List<dynamic> data = snapshot.value;
        List<dynamic> list = data..sort((a, b) => b['date'].compareTo(a['date']));
        setState(() {
          _games = list;
        });
      }
      _readGameList();
    });

    database.reference().child("Players").once().then((DataSnapshot snapshot) {
      var data = snapshot.value.values.toList();
      data.forEach((item) {
        _idToName[item["playerid"]] = item["playername"];
      });
    });
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        backgroundColor: Colors.white,
        body: (_idToName == null || _idToName.isEmpty || _gameList == null || _gameList.isEmpty)
            ? new Center(
                child: Text(
                "Loading...",
                style: new TextStyle(fontSize: 60.0, color: Colors.black),
              ))
            : new ListView.builder(
                itemCount: _gameList.length,
                itemBuilder: (_, int position) {
                  return new Card(
                    color: Colors.white,
                    elevation: 5.0,
                    child: new ListTile(
                      leading: new CircleAvatar(
                        child: Text("${position + 1}"),
                      ),
                      title: new Text(
                          "${_idToName[_gameList[position].player1]} vs. ${_idToName[_gameList[position].player2]}", style: TextStyle(fontWeight: FontWeight.bold),),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(padding: EdgeInsets.fromLTRB(0, 4, 0, 0),),
                          Row(
                            children: <Widget>[
                              Text("Winner: "),
                              Text("${getWinner(position)}")
                            ],
                          ),
                          Padding(padding: EdgeInsets.fromLTRB(0, 4, 0, 0),),
                          Row(
                            children: <Widget>[
                              Text("Win method: "),
                              Text("${_gameList[position].winmethod}")
                            ],
                          ),
                          Padding(padding: EdgeInsets.fromLTRB(0, 4, 0, 0),),
                          Row(
                            children: <Widget>[
                              Text("Gamemode: "),
                              Text("${_gameList[position].gamemode}")
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _showAlertDialog(context,
                          _gameList[position].date, _gameList[position].piecemap, _gameList[position].gamemode),
                      onLongPress: () => null,
                    ),
                  );
                }));
  }

  void _showAlertDialog(BuildContext context, int epoch, piecemap, gamemode) {

    var date = new DateTime.fromMillisecondsSinceEpoch(epoch);
    var format = new DateFormat("EEEE, MMMM d, y");
    var formattedDate = format.format(date);

    var alert = new AlertDialog(
      title: new Text("Game Info"),
      content: new Container(
        width: 200.0,
        height: 273.0,
        child: new Column(
          children: <Widget>[
            new Text("This game was officially ended on:\n$formattedDate"),
            new Padding(padding: EdgeInsets.all(10.0)),
            new Container(
              height: 220.0,
              width: 220.0,
              child: (piecemap.isNotEmpty) ? _getKvartoBoard(piecemap, gamemode) : Text("This game didn't have any piece data"),
            )
          ],
        ),
      ),
      actions: <Widget>[
        FlatButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("OK"))
      ],
    );
    showDialog(context: context, builder: (context) => alert);
  }

  Widget _getKvartoBoard(piecemap, gamemode) {
    var pieceMap = piecemap;
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Container(
        child: GridView.count(
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: (gamemode != "5x5") ? 4 : 5,
            shrinkWrap: true,
            children: List.generate((gamemode != "5x5") ? 16 : 25, (index) {
              return Center(
                  child: Container(
                    child: Padding(
                      padding: (gamemode != "5x5") ? EdgeInsets.all(8.0) : EdgeInsets.all(4.0),
                      child: _getPieceImageFromId(pieceMap[index]),
                    ),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.deepOrange),
                        color: Colors.blueGrey[100]
                    ),
                  )
              );
            })
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.deepOrange[800], width: 4.0),
        ),
      ),
    );
  }

  Widget _getPieceImageFromId(pieceId) {
    if (pieceId != -1) {
      var addon;
      if (pieceId < 16) {
        addon = '_red.png';
      } else if (pieceId < 32) {
        addon = '_green.png';
        pieceId = pieceId - 16;
      } else if (pieceId < 48) {
        addon = '_yellow.png';
        pieceId = pieceId - 32;
      } else {
        addon = '_blue.png';
        pieceId = pieceId - 48;
      }
      var imageMap = [
        'duct',
        'cube',
        'frame',
        'plank',
        'pipe',
        'can',
        'ring',
        'oreo',
        'tent',
        'roof',
        'arrow',
        'wedge',
        'weird',
        'bit',
        'nut',
        'bolt',
      ];

      return Image.asset('lib/images/${imageMap[pieceId]}$addon');

    } else {
      return Container();
    }

  }

  _readGameList() async {
    List items = _games;
    int index = -1;
    items.forEach((item) {
      index++;
      setState(() {
        _gameList.add(Game.map(item));
        //_gameList[index].player1 = _players[int.parse(_gameList[index].player1) - 1]['playername'];
      });
    });
  }

  getWinner(int position) {
    if (_gameList[position].winner == "Tie") {
      return "Tie";
    }
    return _idToName[_gameList[position].winner];
  }
}

//Copyright 2021, Joseph Winningham, All rights reserved.
