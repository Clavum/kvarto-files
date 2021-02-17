import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:database_intro/utils/authentication.dart';
import 'package:database_intro/widgets/GameRequest.dart';
import 'package:database_intro/widgets/GameView.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:database_intro/utils/database_helper.dart';
import 'package:database_intro/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class PlayNav extends StatefulWidget {
  @override
  PlayNavState createState() => PlayNavState();
}

class PlayNavState extends State<PlayNav> {
  var db = new DatabaseHelper();

  final List<List<String>> _requestedGames = <List<String>>[];
  final List<List<String>> _sentRequests = <List<String>>[];
  final List _gamesInProgress = [];

  Map<String, String> nameFromId = new HashMap<String, String>();

  final FirebaseDatabase database = FirebaseDatabase.instance;
  Auth auth = new Auth();
  var userFullId;

  var noRequestedGames = false;
  var noSentRequests = false;
  var noGamesInProgress = false;

  var preventRequestsUpdate = false;
  var preventGamesUpdate = false;

  var _isAlreadyCalculatingNameFromIdMap = false;

  var mostRecentGameView;
  var mostRecentGameId;

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();

    auth.getCurrentUser().then((user) async {
      userFullId = user.uid;
      //userFullId = "1NZr5OeaPDPDJCrb0jnlI7TjMyb2"; //force my id

      readRequestedGames();
      readGamesInProgress();

      database.reference().child("requestedGames").onChildAdded.listen(_requestedGamesChanged);
      database.reference().child("requestedGames").onChildChanged.listen(_requestedGamesChanged);
      database.reference().child("requestedGames").onChildRemoved.listen(_requestedGamesChanged);
      database.reference().child("requestedGames").onChildMoved.listen(_requestedGamesChanged);
      database.reference().child("gamesInProgress").onChildAdded.listen(_currentGamesChanged);
      database.reference().child("gamesInProgress").onChildChanged.listen(_currentGamesChanged);
      database.reference().child("gamesInProgress").onChildRemoved.listen(_currentGamesChanged);
      database.reference().child("gamesInProgress").onChildMoved.listen(_currentGamesChanged);
      database.reference().child("Players").onChildAdded.listen(_playersChanged);
      database.reference().child("Players").onChildChanged.listen(_playersChanged);
      database.reference().child("Players").onChildRemoved.listen(_playersChanged);
      database.reference().child("Players").onChildMoved.listen(_playersChanged);

      updateNameFromIdMap();
    });

  }

  _requestedGamesChanged(Event event) {
    readRequestedGames();
  }
  _currentGamesChanged(Event event) {
    readGamesInProgress();
  }

  _playersChanged(Event event) {
    updateNameFromIdMap();
  }

  static PlayNavState of(BuildContext context) {
    final PlayNavState navigator =
    context.findAncestorStateOfType<PlayNavState>();

    assert(() {
      if (navigator == null) {
        throw new FlutterError(
            'MyStatefulWidgetState operation requested with a context that does '
                'not include a MyStatefulWidget.');
      }
      return true;
    }());

    return navigator;
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        body: ((_requestedGames.isEmpty && !noRequestedGames) || (_gamesInProgress.isEmpty && !noGamesInProgress))
            ? new Center(
                child: Text(
                "Loading...",
                style: new TextStyle(fontSize: 60.0, color: Colors.black),
              ))
            : new Column(
                children: <Widget>[
                  new Expanded(child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      (!noRequestedGames || !noSentRequests || !noGamesInProgress) ?
                      new Column(
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          (!noRequestedGames) ? getIncomingChallengesWidget() : Container(),
                          (!noSentRequests) ? getSentChallengesWidget() : Container(),
                          (!noGamesInProgress) ? getCurrentGamesWidget() : Container(),
                        ],
                      ):
                      new Center(
                        child: Column(
                          children: <Widget>[
                            Padding(padding: EdgeInsets.all(32)),
                            Text("Looks like there's nothing here",
                            style: TextStyle(
                              fontSize: 25.0
                            ),),
                            Padding(padding: EdgeInsets.all(8.0),),
                            Text("See below for instuctions to start a game")
                          ],
                        ),
                      )
                    ],
                  ),),
                  Divider(
                    height: 2.0,
                    thickness: 2.0,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: new Center(
                      child: RaisedButton(
                          color: Colors.deepOrange,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => new GameRequest()));
                          },
                        child: Text("Send a challenge", style: TextStyle(color: Colors.white),),
                      ),
                    ),
                  ),
                ],
              )
            );
  }

  Widget getIncomingChallengesWidget() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          Text(
            "Incoming challenges:",
            style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold),
          ),
          Padding(padding: EdgeInsets.all(4.0)),
          ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _requestedGames.length,
              itemBuilder: (_, int position) {
                return new Card(
                  color: Colors.white,
                  elevation: 5.0,
                  child: new ListTile(
                    leading: new CircleAvatar(
                      child: Icon(Icons.priority_high, color: Colors.white,),
                      backgroundColor: Colors.red,
                    ),
                    title: new Text(
                      "${_requestedGames[position][1]} challenges you!", style: TextStyle(fontWeight: FontWeight.bold),),
                    subtitle: (_requestedGames[position][2] != "")
                        ? new Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
                        Text("Gamemode: ${_requestedGames[position][4]}", style: TextStyle(color: Colors.black),),
                        Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
                        Text("Their message: \"${_requestedGames[position][2]}\"", style: TextStyle(color: Colors.black),),
                        Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
                        Text("(Tap here to defend your honor)",
                            style: new TextStyle(
                                color: Colors.red
                            )
                        ),
                      ],
                    ) : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
                        Text("Gamemode: ${_requestedGames[position][4]}", style: TextStyle(color: Colors.black),),
                        Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
                        new Text(
                          "(Tap here to defend your honor)",
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                    onTap: () => _showAcceptDialog(_requestedGames[position][0], _requestedGames[position][1], _requestedGames[position][3], _requestedGames[position][4]),
                  ),
                );
              }),
        ],
      ),
    );
  }

  Widget getSentChallengesWidget() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          Text(
            "Sent challenges:",
            style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold),
          ),
          Padding(padding: EdgeInsets.all(4.0)),
          ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _sentRequests.length,
              itemBuilder: (_, int position) {
                var daysSinceRequest = ((DateTime.now().millisecondsSinceEpoch - int.parse(_sentRequests[position][4])) / 86400000).toStringAsFixed(0);
                var s = (int.parse(daysSinceRequest) > 1) ? "s" : "";
                var decimalDaysSinceRequest = (DateTime.now().millisecondsSinceEpoch - int.parse(_sentRequests[position][4])) / 86400000;
                var timeSinceLastNudge = "-1";
                var s2 = "";
                var decimalDaysSinceLastNudge = -1.0;
                if (_sentRequests[position][5] != "-1") {
                  timeSinceLastNudge = ((DateTime.now().millisecondsSinceEpoch - int.parse(_sentRequests[position][5])) / 86400000).toStringAsFixed(0);
                  s2 = (int.parse(timeSinceLastNudge) > 1) ? "s" : "";
                  decimalDaysSinceLastNudge = (DateTime.now().millisecondsSinceEpoch - int.parse(_sentRequests[position][5])) / 86400000;
                }
                return new Card(
                  color: Colors.white,
                  elevation: 5.0,
                  child: new ListTile(
                    leading: new CircleAvatar(
                      child: Icon(Icons.more_horiz, color: Colors.white,),
                      backgroundColor: Colors.blue,
                    ),
                    title: new Text(
                        "You sent a game request to ${_sentRequests[position][1]}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(padding: EdgeInsets.fromLTRB(0, 6, 0, 0),),
                        Text("Gamemode: ${_sentRequests[position][3]}"),
                        (decimalDaysSinceRequest >= 1 && timeSinceLastNudge == "-1") ? Column(
                          children: <Widget>[
                            RaisedButton(
                              child: Text("Sent $daysSinceRequest day$s ago, nudge?", style: TextStyle(color: Colors.white),),
                              color: Colors.deepOrange,
                              onPressed: () {
                                sendGameRequestNudge(position, daysSinceRequest);
                              },
                            ),
                          ],
                        ) : (decimalDaysSinceRequest >= 1 && decimalDaysSinceLastNudge >= 0) ? Column(
                          children: <Widget>[
                            RaisedButton(
                              child: Text("Nudged $timeSinceLastNudge day$s2 ago, nudge again?", style: TextStyle(color: Colors.white),),
                              color: Colors.deepOrange,
                              onPressed: () {
                                sendGameRequestNudge(position, daysSinceRequest);
                              },
                            ),
                          ],
                        ) : Column(
                          children: <Widget>[
                            Padding(padding: EdgeInsets.fromLTRB(0, 6, 0, 0),),
                            Text("Waiting on their response..."),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              }),
        ],
      ),
    );
  }

  sendGameRequestNudge(position, daysSinceRequest) {
    var data = {
      "receiverId": _sentRequests[position][0],
      "nudgedBy": nameFromId[userFullId],
      "daysSinceRequest": daysSinceRequest,
      "type": "nudgeForGameRequest"
    };
    database.reference().child("notificationRequests").push().set(data);
    database.reference().child("requestedGames/${_sentRequests[position][6]}/lastnudge").set(DateTime.now().millisecondsSinceEpoch);
  }

  Widget getCurrentGamesWidget() {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          Text(
            "Games in progress:",
            style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold),
          ),
          Padding(padding: EdgeInsets.all(4.0)),
          ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _gamesInProgress.length,
              itemBuilder: (_, int position) {
                return new Card(
                  color: Colors.white,
                  elevation: 5.0,
                  child: new ListTile(
                    leading: new CircleAvatar(
                      child: Icon(Icons.apps, color: Colors.white,),
                      backgroundColor: Colors.deepOrange,
                    ),
                    title: new Text(
                        "You are currently playing with ${_gamesInProgress[position][0]}"),
                    subtitle: _showPlayingCard(_gamesInProgress[position][1], _gamesInProgress[position][0], _gamesInProgress[position][12],
                        _gamesInProgress[position][13], position, _gamesInProgress[position][5], _gamesInProgress[position][14]),

                    onTap: () => _showGame(_gamesInProgress[position][6], _gamesInProgress[position][5], _gamesInProgress[position][1], _gamesInProgress[position][3],
                        _gamesInProgress[position][4], _gamesInProgress[position][2], _gamesInProgress[position][7], _gamesInProgress[position][8],
                        _gamesInProgress[position][9], _gamesInProgress[position][10], _gamesInProgress[position][11]),
                  ),
                );
              }),
        ],
      ),
    );
  }

  Widget _showPlayingCard(turnType, opponentName, lastAction, lastNudge, position, opponentId, gameInProgressId) {
    var daysSinceLastAction = ((DateTime.now().millisecondsSinceEpoch - lastAction) / 86400000).toStringAsFixed(0);
    var decimalDaysSinceLastAction = (DateTime.now().millisecondsSinceEpoch - lastAction) / 86400000;
    var s = (int.parse(daysSinceLastAction) > 1) ? "s" : "";
    var daysSinceLastNudge = "-1";
    var decimalDaysSinceLastNudge = -1.0;
    var s2 = "";
    if (lastNudge != -1) {
      daysSinceLastNudge = ((DateTime.now().millisecondsSinceEpoch - lastNudge) / 86400000).toStringAsFixed(0);
      decimalDaysSinceLastNudge = (DateTime.now().millisecondsSinceEpoch - lastNudge) / 86400000;
      s2 = (int.parse(daysSinceLastNudge) > 1) ? "s" : "";
    }
    switch (turnType) {
      case "0":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
            Text("Waiting on $opponentName to give you a piece"),
            (decimalDaysSinceLastAction >= 1 && daysSinceLastNudge == "-1") ? Column(
              children: <Widget>[
                RaisedButton(
                  child: Text("They haven't played for $daysSinceLastAction day$s, nudge?", style: TextStyle(color: Colors.white),),
                  color: Colors.deepOrange,
                  onPressed: () {
                    sendCurrentGameNudge(position, daysSinceLastAction, opponentId, gameInProgressId);
                  },
                ),
              ],
            )  : (decimalDaysSinceLastAction >= 1 && decimalDaysSinceLastNudge >= 1) ? Column(
              children: <Widget>[
                RaisedButton(
                  child: Text("Nudged $daysSinceLastNudge day$s2 ago, nudge again?", style: TextStyle(color: Colors.white),),
                  color: Colors.deepOrange,
                  onPressed: () {
                    sendCurrentGameNudge(position, daysSinceLastAction, opponentId, gameInProgressId);
                  },
                ),
              ],
            ) : Column(
              children: <Widget>[
                Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
                Text("Tap here to view"),
              ],
            )

          ],
        );
        break;
      case "1":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
            Text("It's your turn!",
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold
              ),
            ),
            Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
            Text("Tap here to play"),
          ],
        );
        break;
      case "2":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
            Text("You need to give $opponentName a piece",
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold
              ),
            ),
            Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
            Text("Tap here to continue"),
          ],
        );
        break;
      case "3":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
            Text("It's their turn"),
            (decimalDaysSinceLastAction >= 1 && daysSinceLastNudge == "-1") ? Column(
              children: <Widget>[
                RaisedButton(
                  child: Text("They haven't played for $daysSinceLastAction day$s, nudge?", style: TextStyle(color: Colors.white),),
                  color: Colors.deepOrange,
                  onPressed: () {
                    sendCurrentGameNudge(position, daysSinceLastAction, opponentId, gameInProgressId);
                  },
                ),
              ],
            )  : (decimalDaysSinceLastAction >= 1 && decimalDaysSinceLastNudge >= 1) ? Column(
              children: <Widget>[
                RaisedButton(
                  child: Text("Nudged $daysSinceLastNudge day$s2 ago, nudge again?", style: TextStyle(color: Colors.white),),
                  color: Colors.deepOrange,
                  onPressed: () {
                    sendCurrentGameNudge(position, daysSinceLastAction, opponentId, gameInProgressId);
                  },
                ),
              ],
            ) : Column(
              children: <Widget>[
                Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
                Text("Tap here to view"),
              ],
            )
          ],
        );
        break;
      case "4":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
            Text("The game is over!",
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold
              ),),
            Padding(padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 0.0),),
            Text("Tap here to view"),
          ],
        );
      default:
        return new Text("Something went wrong. Error code \"derpy squirrel\"");
    }
  }

  sendCurrentGameNudge(position, daysSinceRequest, opponentId, gameInProgressId) {
    var data = {
      "receiverId": opponentId,
      "nudgedBy": nameFromId[userFullId],
      "daysSinceRequest": daysSinceRequest,
      "type": "nudgeForCurrentGame"
    };
    database.reference().child("notificationRequests").push().set(data);
    database.reference().child("gamesInProgress/$gameInProgressId/lastnudge").set(DateTime.now().millisecondsSinceEpoch);
  }

  void readRequestedGames() async {
    if (!preventRequestsUpdate) {
      preventRequestsUpdate = true;
      noSentRequests = false;
      noRequestedGames = false;
      _requestedGames.clear();
      _sentRequests.clear();
      var doneLoadingRequestedGames = false;
      var doneLoadingSentRequests = false;
      final List<List<String>> _tempRequestedGames = <List<String>>[];
      var lengthOfRequestedGames;
      final List<List<String>> _tempSentRequests = <List<String>>[];
      var lengthOfSentRequests;
      await database.reference().child("requestedGames").orderByChild("opponentId").equalTo(userFullId).once().then((DataSnapshot snapshot) {
        if (snapshot.value != null) {
          List<dynamic> list = <dynamic>[];
          List<dynamic> gameRequestIdList = <dynamic>[];
          //try {
          Map<dynamic, dynamic> data = snapshot.value;
          list = data.values.toList();
          gameRequestIdList = data.keys.toList();
//          } catch (e) {
//            List<dynamic> data = snapshot.value;
//            list = data;
//          }
          var topIndex = -1;
          var bottomIndex = 0;
          lengthOfRequestedGames = list.length;
          list.forEach((item) async {
            topIndex++;
            await database.reference().child("Players").orderByChild("playerid").equalTo(list[topIndex]["requesterId"]).once().then((DataSnapshot snapshot) {
              var name;
              try {
                name = snapshot.value.values.toList();
                name = name[0];
              } catch (e) {
                name = snapshot.value;
                name = name[0];
                name ??= snapshot.value[1]; //if null
              }
              List<String> temp = [
                list[bottomIndex]["requesterId"],
                name["playername"],
                list[bottomIndex]["message"],
                gameRequestIdList[bottomIndex],
                list[bottomIndex]["gamemode"]
              ];
              setState(() {
                _tempRequestedGames.add(temp);
              });
              if (bottomIndex == (lengthOfRequestedGames - 1)) {
                doneLoadingRequestedGames = true;
                if (doneLoadingSentRequests) {
                  preventRequestsUpdate = false;
                }
                _requestedGames.clear();
                setState(() {
                  _requestedGames.addAll(_tempRequestedGames);
                });
              }
              bottomIndex++;
            });
          });
        } else {
          setState(() {
            noRequestedGames = true;
            doneLoadingRequestedGames = true;
            if (doneLoadingSentRequests) {
              preventRequestsUpdate = false;
            }
          });
        }
      });
      await database.reference().child("requestedGames").orderByChild("requesterId").equalTo(userFullId).once().then((DataSnapshot snapshot) {
        if (snapshot.value != null) {
          List<dynamic> list = <dynamic>[];
          //try {
          Map<dynamic, dynamic> data = snapshot.value;
          list = data.values.toList();
          var keys = data.keys.toList();
//          } catch (e) {
//            List<dynamic> data = snapshot.value;
//            list = data;
//          }
          var topIndex = -1;
          var bottomIndex = 0;
          lengthOfSentRequests = list.length;
          list.forEach((item) async {
            topIndex++;
            await database.reference().child("Players").orderByChild("playerid").equalTo(list[topIndex]["opponentId"]).once().then((DataSnapshot snapshot) {
              var name;
              try {
                name = snapshot.value.values.toList();
                name = name[0];
              } catch (e) {
                name = snapshot.value;
                name = name[0];
                name ??= snapshot.value[1]; //if null
              }
              List<String> temp = [
                list[bottomIndex]["opponentId"],
                name["playername"],
                list[bottomIndex]["message"],
                list[bottomIndex]["gamemode"],
                list[bottomIndex]["timesent"].toString(),
                list[bottomIndex]["lastnudge"].toString(),
                keys[bottomIndex]
              ];
              setState(() {
                _tempSentRequests.add(temp);
              });
              if (bottomIndex == (lengthOfSentRequests - 1)) {
                doneLoadingSentRequests = true;
                if (doneLoadingRequestedGames) {
                  preventRequestsUpdate = false;
                }
                _sentRequests.clear();
                setState(() {
                  _sentRequests.addAll(_tempSentRequests);
                });
              }
              bottomIndex++;
            });
          });
        } else {
          setState(() {
            noSentRequests = true;
            doneLoadingSentRequests = true;
            if (doneLoadingRequestedGames) {
              preventRequestsUpdate = false;
            }
          });
        }
      });
    }
  }

  void readGamesInProgress() async {
    if (!preventGamesUpdate) {
      preventGamesUpdate = true;
      noGamesInProgress = false;
      var noGamesInUpper = false;
      var noGamesInLower = false;
      final List _tempGamesInProgress = [];
      var lengthOfTop;
      var lengthOfBottom;
      var doneCollectingDataInTop = false;
      var doneCollectingDataInBottom = false;
      await database.reference().child("gamesInProgress").orderByChild("player1").equalTo(userFullId).once().then((DataSnapshot snapshot) {
        if (snapshot.value != null) {
          List<dynamic> list = <dynamic>[];
          List<dynamic> currentGameIdList = <dynamic>[];
          //try {
          Map<dynamic, dynamic> data = snapshot.value;
          list = data.values.toList();
          var keys = data.keys.toList();
          currentGameIdList = data.keys.toList();
//          } catch (e) {
//            List<dynamic> data = snapshot.value;
//            list = data;
//          }
          var topIndex = -1;
          var bottomIndex = 0;
          var dismissedGames = 0;

          lengthOfTop = list.length;
          list.forEach((item) async {
            topIndex++;
            //TODO this should just use the name/id map
            //TODO duplicate code from this one and the one below should be combined into a function
            await database.reference().child("Players").orderByChild("playerid").equalTo(list[topIndex]["player2"]).once().then((DataSnapshot snapshot) {
              var name;
              try {
                name = snapshot.value.values.toList();
                name = name[0];
              } catch (e) {
                name = snapshot.value;
                name = name[0];
                name ??= snapshot.value[1]; //if null
              }
              var turnType;
              //0 = this player is waiting on a piece
              //1 = this player needs to play down a piece
              //2 = this player needs to select a piece for the opponent
              //3 = the opponent needs to play a piece
              //4 = game is over
              if (list[bottomIndex]["turn"] == userFullId && list[bottomIndex]["selectedpiece"] == -1) {
                turnType = 0;
              } else if (list[bottomIndex]["turn"] == userFullId) {
                turnType = 1;
              } else if (list[bottomIndex]["turn"] == list[bottomIndex]["player2"] && list[bottomIndex]["selectedpiece"] == -1) {
                turnType = 2;
              } else if (list[bottomIndex]["turn"] == "-1") {
                turnType = 4;
              } else {
                turnType = 3;
              }
              List<dynamic> temp = [
                name["playername"],
                turnType.toString(),
                currentGameIdList[bottomIndex],
                list[bottomIndex]["piecemap"],
                list[bottomIndex]["selectedpiece"],
                list[bottomIndex]["player2"],
                userFullId,
                true,
                list[bottomIndex]["winner"],
                list[bottomIndex]["player1dismiss"],
                list[bottomIndex]["player2dismiss"],
                list[bottomIndex]["gamemode"],
                list[bottomIndex]["lastaction"],
                list[bottomIndex]["lastnudge"],
                keys[bottomIndex]
              ];
              if (list[bottomIndex]["player1dismiss"] == 0) { //If it hasn't been dismissed
                setState(() {
                  _tempGamesInProgress.add(temp);
                });
                if (bottomIndex == (lengthOfTop - 1)) {
                  doneCollectingDataInTop = true;
                  maybeDoneRetrievingGames(doneCollectingDataInTop, noGamesInUpper, doneCollectingDataInBottom, noGamesInLower, _tempGamesInProgress);
                }
              } else {
                dismissedGames++;
                if (dismissedGames == list.length) {
                  setState(() {
                    noGamesInUpper = true;
                    maybeDoneRetrievingGames(doneCollectingDataInTop, noGamesInUpper, doneCollectingDataInBottom, noGamesInLower, _tempGamesInProgress);
                  });
                  if (noGamesInLower) {
                    setState(() {
                      noGamesInProgress = true;
                    });
                  }
                } else if (bottomIndex == (lengthOfTop - 1)) {
                  setState(() {
                    doneCollectingDataInTop = true;
                    maybeDoneRetrievingGames(doneCollectingDataInTop, noGamesInUpper, doneCollectingDataInBottom, noGamesInLower, _tempGamesInProgress);
                  });
                }
              }
              if (mostRecentGameView != null && mostRecentGameId == currentGameIdList[bottomIndex]) {
                mostRecentGameView.updateGameInfo(turnType.toString(), list[bottomIndex]["piecemap"], list[bottomIndex]["selectedpiece"], list[bottomIndex]["winner"],
                    list[bottomIndex]["player1dismiss"], list[bottomIndex]["player2dismiss"]);
              }
              bottomIndex++;
            });
          });

        } else {
          setState(() {
            noGamesInUpper = true;
            maybeDoneRetrievingGames(doneCollectingDataInTop, noGamesInUpper, doneCollectingDataInBottom, noGamesInLower, _tempGamesInProgress);
          });
        }
      });
      await database.reference().child("gamesInProgress").orderByChild("player2").equalTo(userFullId).once().then((DataSnapshot snapshot) {
        if (snapshot.value != null) {
          List<dynamic> list = <dynamic>[];
          List<dynamic> currentGameIdList = <dynamic>[];
          //try {
          Map<dynamic, dynamic> data = snapshot.value;
          list = data.values.toList();
          var keys = data.keys.toList();
          currentGameIdList = data.keys.toList();
//          } catch (e) {
//            List<dynamic> data = snapshot.value;
//            list = data;
//          }
          var topIndex = -1;
          var bottomIndex = 0;
          var dismissedGames = 0;

          lengthOfBottom = list.length;
          list.forEach((item) async {
            topIndex++;
            //TODO this should just use the name/id map
            await database.reference().child("Players").orderByChild("playerid").equalTo(list[topIndex]["player1"]).once().then((DataSnapshot snapshot) {
              var name;
              try {
                name = snapshot.value.values.toList();
                name = name[0];
              } catch (e) {
                name = snapshot.value;
                name = name[0];
                name ??= snapshot.value[1]; //if null
              }
              var turnType;
              //0 = this player is waiting on a piece
              //1 = this player needs to play down a piece
              //2 = this player needs to select a piece for the opponent
              //3 = the opponent needs to play a piece
              //4 = game is over
              if (list[bottomIndex]["turn"] == userFullId && list[bottomIndex]["selectedpiece"] == -1) {
                turnType = 0;
              } else if (list[bottomIndex]["turn"] == userFullId) {
                turnType = 1;
              } else if (list[bottomIndex]["turn"] == list[bottomIndex]["player1"] && list[bottomIndex]["selectedpiece"] == -1) {
                turnType = 2;
              } else if (list[bottomIndex]["turn"] == "-1") {
                turnType = 4;
              } else {
                turnType = 3;
              }
              List<dynamic> temp = [
                name["playername"],
                turnType.toString(),
                currentGameIdList[bottomIndex],
                list[bottomIndex]["piecemap"],
                list[bottomIndex]["selectedpiece"],
                list[bottomIndex]["player1"],
                userFullId,
                false,
                list[bottomIndex]["winner"],
                list[bottomIndex]["player1dismiss"],
                list[bottomIndex]["player2dismiss"],
                list[bottomIndex]["gamemode"],
                list[bottomIndex]["lastaction"],
                list[bottomIndex]["lastnudge"],
                keys[bottomIndex]
              ];
              if (list[bottomIndex]["player2dismiss"] == 0) { //If it hasn't been dismissed
                setState(() {
                  _tempGamesInProgress.add(temp);
                });
                if (bottomIndex == (lengthOfBottom - 1)) {
                  doneCollectingDataInBottom = true;
                  maybeDoneRetrievingGames(doneCollectingDataInTop, noGamesInUpper, doneCollectingDataInBottom, noGamesInLower, _tempGamesInProgress);
                }
              } else {
                dismissedGames++;
                if (dismissedGames == list.length) {
                  setState(() {
                    noGamesInLower = true;
                    maybeDoneRetrievingGames(doneCollectingDataInTop, noGamesInUpper, doneCollectingDataInBottom, noGamesInLower, _tempGamesInProgress);
                  });
                  if (noGamesInUpper) {
                    setState(() {
                      noGamesInProgress = true;
                    });
                  }
                } else if (bottomIndex == (lengthOfBottom - 1)) {
                  setState(() {
                    doneCollectingDataInBottom = true;
                    maybeDoneRetrievingGames(doneCollectingDataInTop, noGamesInUpper, doneCollectingDataInBottom, noGamesInLower, _tempGamesInProgress);
                  });
                }
              }
              if (mostRecentGameView != null && mostRecentGameId == currentGameIdList[bottomIndex]) {
                mostRecentGameView.updateGameInfo(turnType.toString(), list[bottomIndex]["piecemap"], list[bottomIndex]["selectedpiece"], list[bottomIndex]["winner"],
                    list[bottomIndex]["player1dismiss"], list[bottomIndex]["player2dismiss"]);
              }
              bottomIndex++;
            });
          });
        } else {
          setState(() {
            noGamesInLower = true;
            maybeDoneRetrievingGames(doneCollectingDataInTop, noGamesInUpper, doneCollectingDataInBottom, noGamesInLower, _tempGamesInProgress);
          });
        }
      });
      if (noGamesInUpper && noGamesInLower) {
        noGamesInProgress = true;
      }
    }
  }

  maybeDoneRetrievingGames(doneCollectingDataInTop, noGamesInUpper, doneCollectingDataInBottom, noGamesInLower, temp) {
    if ((doneCollectingDataInTop || noGamesInUpper) && (doneCollectingDataInBottom || noGamesInLower)) {
      preventGamesUpdate = false;
      _gamesInProgress.clear();
      setState(() {
        _gamesInProgress.addAll(temp);
      });
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

  _showAcceptDialog(playerId, playerName, gameRequestId, gamemode) {
    var alert = new AlertDialog (
        title: new Text("Accept Challenge"),
        content: new Text("Do you accept $playerName's challenge?"),
        actions: <Widget>[
          FlatButton(
              onPressed: () {
                Navigator.pop(context);
                _startGame(playerId, gameRequestId, gamemode);
              },
              child: Text("Accept")),
          FlatButton(
              onPressed: () {
                Navigator.pop(context);
                database.reference().child("requestedGames/$gameRequestId").remove();
              },
              child: Text("Reject", style: TextStyle(color: Colors.red),)),
          FlatButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Close")),
        ]);
    showDialog(context: context, builder: (context) => alert);
  }

  _startGame(playerId, gameRequestId, gamemode) {
    //Delete challenge
    database.reference().child("requestedGames/$gameRequestId").remove();
    //Add gameInProgress
    var data = {
      'player1': userFullId, //This person is going first
      'player2': playerId,
      'turn': playerId,
      'piecemap': (gamemode != "5x5") ? [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1] : [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1],
      'selectedpiece': -1,
      'winner': "-1",
      'player1dismiss': 0,
      'player2dismiss': 0,
      'gamemode': gamemode,
      'lastaction': DateTime.now().millisecondsSinceEpoch,
      'lastnudge': -1
    };
    String gameKey = database.reference().child("gamesInProgress").push().key;
    database.reference().child("gamesInProgress/$gameKey").set(data);
    _showGame(userFullId, playerId, "2" ,(gamemode != "5x5") ? [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1]
        : [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1], 0, gameKey, true, "-1", 0, 0, gamemode);

  }

  _showGame(userFullId, opponentId, turnType, piecemap, selectedpiece, gameInProgressId, isPlayer1, winner, player1dismiss, player2dismiss, gamemode) {
    mostRecentGameView = new GameView(userFullId, opponentId, turnType, piecemap, selectedpiece, gameInProgressId, nameFromId[opponentId], isPlayer1, winner,
        player1dismiss, player2dismiss, gamemode);
    mostRecentGameId = gameInProgressId;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => mostRecentGameView),
    );
  }
}
