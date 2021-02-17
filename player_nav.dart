import 'dart:collection';

import 'package:database_intro/models/player.dart';
import 'package:database_intro/utils/authentication.dart';
import 'package:database_intro/utils/database_helper.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:database_intro/main.dart';

class PlayerNav extends StatefulWidget {
  @override
  _PlayerNavState createState() => _PlayerNavState();
}

class _PlayerNavState extends State<PlayerNav> {
  HomeState homeState = new HomeState();
  var db = new DatabaseHelper();
  Auth auth = new Auth();

  final List<String> _playerWins = <String>[];
  final List<String> _playerTied = <String>[];
  final List<String> _playerPlayed = <String>[];
  final List<Player> _playerList = <Player>[];

  final FirebaseDatabase database = FirebaseDatabase.instance;

  Map<String, String> nameFromId = new HashMap<String, String>();
  var _isAlreadyCalculatingNameFromIdMap = false;

  @override
  void initState() {
    super.initState();

    _readPlayerList();
    updateNameFromIdMap();

    database.reference().child("Players").onChildAdded.listen(_playersChanged);
    database.reference().child("Players").onChildChanged.listen(_playersChanged);
    database.reference().child("Players").onChildRemoved.listen(_playersChanged);
    database.reference().child("Players").onChildMoved.listen(_playersChanged);
  }

  _playersChanged(Event event) {
    updateNameFromIdMap();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: (_playerList.isEmpty || _playerWins.isEmpty)
          ? new Center(child: Text("Loading...",
        style: new TextStyle(fontSize: 60.0, color: Colors.black),))
          : new ListView.builder(
          itemCount: _playerList.length,
          itemBuilder: (_, int position) {
            return Padding(
              padding: EdgeInsets.fromLTRB(8.0, (position == 0) ? 16.0 : 4.0, 8.0, (position == _playerList.length - 1) ? 16.0 : 4.0),
              child: Card(
                color: Colors.white,
                elevation: 5.0,
                child: new ListTile(
                  leading: new CircleAvatar(
                    child: Text(
                        "${_playerList[position].playername.substring(0, 1)}", style: TextStyle(color: Colors.white),),
                    backgroundColor: Colors.deepOrange,
                  ),
                  title: new Text("${_playerList[position].playername}", style: TextStyle(fontSize: 18.0),),
                  subtitle: new FutureBuilder<List<List<String>>>(
                    future: getPlayerStats(),
                    //0 = wins, 1 = played, 2 = losses, 3 = winPercent
                    builder: (BuildContext context,
                        AsyncSnapshot<List<List<String>>> snapshot) {
                      switch (snapshot.connectionState) {
                        case ConnectionState.none:
                        case ConnectionState.active:
                        case ConnectionState.waiting:
                          return Text('Loading...');
                        case ConnectionState.done:
                          if (snapshot.hasError)
                            return Text('Error: ${snapshot.error}');
                          return (_playerList[position].playerid != "IOGhtkq1iEaLWfsXdhMkf3LACgS2") ? Column( //Bot
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(padding: EdgeInsets.all(4.0),),
                              getTextRow(int.parse(snapshot.data[0][position]), int.parse(snapshot.data[4][position]), int.parse(snapshot.data[2][position])),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    flex: int.parse(snapshot.data[0][position]),
                                    child: Container(
                                      color: Colors.green,
                                      height: 10.0,
                                    )
                                  ),
                                  Expanded(
                                      flex: int.parse(snapshot.data[4][position]),
                                      child: Container(
                                        color: Colors.orange,
                                        height: 10.0,
                                      )
                                  ),
                                  Expanded(
                                      flex: int.parse(snapshot.data[2][position]),
                                      child: Container(
                                        color: Colors.red,
                                        height: 10.0,
                                      )
                                  ),
                                ],
                              ),
                              Padding(
                                padding: EdgeInsets.all(4.0),
                              ),
                              Text("Total played: ${snapshot.data[1][position]}"
                                  "     Win Percent: ${snapshot.data[3][position]}")
                            ],
                          ) :
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Padding(padding: EdgeInsets.all(4.0),),
                              Text("Play for practice   |   Games and pieces not saved"),
                              Padding(padding: EdgeInsets.all(4.0),),
                              Text("The bot gives random pieces, and plays on random tiles")
                            ],
                          );
                      }
                      return null; // unreachable
                    },
                  ),
                ),
              ),
            );
          }),

    );
  }

  Widget getTextRow(wins, ties, losses) {
    if (ties / (wins + ties + losses) < 0.15) {
      return Row(
        children: <Widget>[
          Expanded(
              flex: wins,
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 8.0, 0),
                child: Text("Wins: $wins", softWrap: false,),
              )
          ),
          Expanded(
            flex: ties + losses,
            child: Row(
              children: <Widget>[
                Text("Ties: $ties"),
                Padding(padding: EdgeInsets.fromLTRB(0, 0, 8.0, 0),),
                Text("Losses: $losses")
              ],
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: <Widget>[
          Expanded(
            flex: wins,
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 8.0, 0),
              child: Text("Wins: $wins", softWrap: false,),
            )
          ),
          Expanded(
            flex: ties,
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 8.0, 0),
              child: Text("Ties: $ties"),
            )
          ),
          Expanded(
            flex: losses,
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: Text("Losses: $losses", softWrap: false,),
            )
          ),
        ],
      );
    }
  }

  updateNameFromIdMap() {
    if (!_isAlreadyCalculatingNameFromIdMap) {
      _isAlreadyCalculatingNameFromIdMap = true;
      var tempMap = new HashMap<String, String>(); //Don't want to clear out the old one until we finish up with everything
      database.reference().child("Players").once().then((DataSnapshot snapshot) {
        var result;
        try {
          result = snapshot.value.values.toList();
        } catch (e) {
          result = snapshot.value;
        }
        result.forEach((item) {
          tempMap[item["playerid"]] = item["playername"];
        });
        nameFromId.clear();
        nameFromId.addAll(tempMap);
        _isAlreadyCalculatingNameFromIdMap = false;
      });
    }
  }

  _readPlayerList() async {
    database.reference().child("Players").once().then((DataSnapshot snapshot) {
      Map<dynamic, dynamic> map = snapshot.value;
      List<dynamic> items = map.values.toList()..sort((a, b) => a['playernumber'].compareTo(b['playernumber']));
      items.forEach((item) {
        setState(() {
          if (item["playerid"] != "IOGhtkq1iEaLWfsXdhMkf3LACgS2") { //bot
            _playerList.add(Player.map(item));
          }
        });
      });
      _readWinsList();
      _readPlayed();
    });
  }

  _readWinsList() async {
    for (int i = 0; i < _playerList.length; i++) {
      database.reference().child("Games").orderByChild("winner").equalTo(
          _playerList[i].playerid).once().then((DataSnapshot snapshot) {
        var data = snapshot.value;

        if (data != null) {
          setState(() {
            _playerWins.add(data.length.toString());
          });
        } else {
          setState(() {
            _playerWins.add("0");
          });
        }
      });
    }
  }

  _readPlayed() async {
    for (int i = 0; i < _playerList.length; i++) {
      var played2 = 0;
      var tied = 0;
      database.reference().child("Games").orderByChild("player1").equalTo(
          _playerList[i].playerid).once().then((DataSnapshot snapshot) {
        var data = snapshot.value;
        if (data != null) {
          void iterateMapEntry(key, value) {
            if (data[key] != null) {
              played2++;
              if (data[key]["winner"] == "Tie") {
                tied++;
              }
            }
          }
          data.forEach(iterateMapEntry);
        }
      });
      database.reference().child("Games").orderByChild("player2").equalTo(
          _playerList[i].playerid).once().then((DataSnapshot snapshot) {
        var data = snapshot.value;
        if (data != null) {
          void iterateMapEntry(key, value) {
            if (data[key] != null) {
              played2++;
              if (data[key]["winner"] == "Tie") {
                tied++;
              }
            }
          }
          try {
            data.forEach(
                iterateMapEntry); //use only this after rogue data fixed
          } catch (e) {
            for (int i = 0; i < data.length; i++) {
              played2++;
              if (data[i]["winner"] == "Tie") {
                tied++;
              }
            }
          }
        }
        setState(() {
          _playerPlayed.add(played2.toString());
          _playerTied.add(tied.toString());
        });
      });
    }
  }

  Future<List<List<String>>> getPlayerStats() async {
    var values = new List<List<String>>();
    var wins = new List<String>();
    var played = new List<String>();
    var losses = new List<String>();
    var winPercent = new List<String>();
    var tied = new List<String>();
    values.add(wins);
    values.add(played);
    values.add(losses);
    values.add(winPercent);
    values.add(tied);
    for (int i = 0; i < _playerWins.length; i++) {
      String wins = _playerWins[i];
      values[0].add(wins);
    }
    for (int i = 0; i < _playerWins.length; i++) {
      String played = _playerPlayed[i];
      values[1].add(played);
    }
    for (int i = 0; i < _playerTied.length; i++) {
      String played = _playerTied[i];
      values[4].add(played);
    }
    for (int i = 0; i < _playerWins.length; i++) {
      String wins = _playerWins[i];
      String played = _playerPlayed[i];
      String tied = _playerTied[i];
      String losses = (int.parse(played) - int.parse(wins) - int.parse(tied)).toString();
      values[2].add(losses);
    }
    for (int i = 0; i < _playerWins.length; i++) {
      String wins = _playerWins[i];
      String played = _playerPlayed[i];
      String tied = _playerTied[i];
      String winPercent = '';
      if ((((int.parse(wins) / (int.parse(played) - int.parse(tied))) * 100).toString()) == "NaN") {
        if (int.parse(wins) > 0) {
          winPercent = '100.0%';
        } else {
          winPercent = '0.0%';
        }
      } else {
        winPercent =
            ((((int.parse(wins) / (int.parse(played) - int.parse(tied))) * 1000).round() / 10).toString()) +
                "%";
      }
      values[3].add(winPercent);
    }
    return values;
  }
}

//Copyright 2021, Joseph Winningham, All rights reserved.
