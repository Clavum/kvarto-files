import 'dart:collection';
import 'dart:ui';

import 'package:database_intro/main.dart';
import 'package:database_intro/utils/authentication.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class GameRequest extends StatefulWidget {
  @override
  _GameRequestState createState() => _GameRequestState();
}

class _GameRequestState extends State<GameRequest> {
  final FirebaseDatabase database = FirebaseDatabase.instance;
  Auth auth = new Auth();

  var userFullId;
  var playingWith = [];
  var sentChallenge = [];
  var challengedBy = [];
  var waitingDismiss = [];
  var needToDismiss = [];
  var allPlayers = [];
  var loadingPlayerLists = true;
  var preventExtraLoading = false;
  var wantsToChallenge = "";
  var selectedGamemode = "Classic";

  Map<String, String> nameFromId = new HashMap<String, String>();
  var _isAlreadyCalculatingNameFromIdMap = false;

  @override
  void initState() {
    super.initState();

    auth.getCurrentUser().then((user) async {
      userFullId = user.uid;
      updateNameFromIdMap();
      readAvailablePlayers();

      database.reference().child("requestedGames").onChildAdded.listen(_gamesChanged);
      database.reference().child("requestedGames").onChildChanged.listen(_gamesChanged);
      database.reference().child("requestedGames").onChildRemoved.listen(_gamesChanged);
      database.reference().child("requestedGames").onChildMoved.listen(_gamesChanged);
      database.reference().child("gamesInProgress").onChildAdded.listen(_gamesChanged);
      database.reference().child("gamesInProgress").onChildChanged.listen(_gamesChanged);
      database.reference().child("gamesInProgress").onChildRemoved.listen(_gamesChanged);
      database.reference().child("gamesInProgress").onChildMoved.listen(_gamesChanged);
      database.reference().child("Players").onChildAdded.listen(_playersChanged);
      database.reference().child("Players").onChildChanged.listen(_playersChanged);
      database.reference().child("Players").onChildRemoved.listen(_playersChanged);
      database.reference().child("Players").onChildMoved.listen(_playersChanged);
    });
  }

  _gamesChanged(event) {
    readAvailablePlayers();
  }

  _playersChanged(Event event) {
    updateNameFromIdMap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Game Request"),
        backgroundColor: Colors.deepOrange,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (wantsToChallenge == "") {
              Navigator.pop(context);
            } else {
              setState(() {
                wantsToChallenge = "";
                selectedGamemode = "Classic";
              });
            }
          },
        ),
      ),
      body: Builder(
        builder: (context) =>
        (wantsToChallenge == "")
            ? showChallengeList()
            : showChallengeMenu()
      )
    );
  }

  Widget showChallengeList() {
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Challenge a player:", style: TextStyle(fontSize: 20.0), textAlign: TextAlign.center,),
          ),
          (!loadingPlayerLists) ? Divider(height: 2.0, thickness: 2.0,) : Container(),
          (!loadingPlayerLists) ? Expanded(
            child: ListView.builder(
                shrinkWrap: true,
                itemCount: allPlayers.length,
                itemBuilder: (_, position) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(24.0, (position == 0) ? 16.0 : 2.0, 24.0, (position == allPlayers.length - 1) ? 16.0 : 2.0),
                    child: Card(
                      elevation: 2.0,
                      color: (allPlayers[position] == "IOGhtkq1iEaLWfsXdhMkf3LACgS2") ? Colors.grey[300] : Colors.grey[100], //Bot
                      child: ListTile(
                        title: Text("${nameFromId[allPlayers[position]]}", style: TextStyle(color: Colors.black,
                            fontWeight: (isAvailableToChallenge(position)) ? FontWeight.bold : FontWeight.normal),),
                        subtitle: getPlayerTypeDescription(position),
                        onTap: (isAvailableToChallenge(position)) ? () {
                          setState(() {
                            wantsToChallenge = allPlayers[position];
                          });
                        } : null,
                      ),
                    ),
                  );
                }
            ),
          ) : Text("Loading...")
        ],
      ),
    );
  }

  Widget showChallengeMenu() {
    TextEditingController _messageController = new TextEditingController();
    return SizedBox.expand(
      child: ListView(
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text("Challenge ${nameFromId[wantsToChallenge]}", style: TextStyle(fontSize: 25.0), textAlign: TextAlign.center,),
                    ),
                    Text("Gamemodes:", style: TextStyle(fontSize: 20.0)),
                    Padding(padding: EdgeInsets.all(8.0),),
                    showGamemodeContainer("Classic"),
                    showGamemodeContainer("16 Pieces"),
                    showGamemodeContainer("Opposites"),
                    showGamemodeContainer("5x5"),
                    Padding(padding: EdgeInsets.all(8.0)),
                    Text("Optional: Include a message:", style: TextStyle(fontSize: 20.0)),
                    Padding(padding: EdgeInsets.all(8.0)),
                    TextField(
                      controller: _messageController,
                      autofocus: false,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        border: new OutlineInputBorder(
                            borderSide: new BorderSide(color: Colors.blue)
                        ),
                        hintText: 'Eg. "You will lose"',
                        labelText: 'Message:',
                        prefixText: ' ',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: RaisedButton(
                  color: Colors.deepOrange,
                  onPressed: () async {
                    var data = {
                      'requesterId': userFullId,
                      'opponentId': wantsToChallenge,
                      'message': _messageController.text,
                      'gamemode': selectedGamemode,
                      'timesent': DateTime.now().millisecondsSinceEpoch,
                      'lastnudge': -1
                    };
                    await database.reference().child("requestedGames").push().set(data);
                    Navigator.pop(context);
                  },
                  child: Text("Send Challenge", style: TextStyle(color: Colors.white),),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  showGamemodeContainer(gamemode) {
    //Bot: lots in here
    var bottomText;
    var topLeftRadius = Radius.circular(0);
    var topRightRadius = Radius.circular(0);
    var bottomLeftRadius = Radius.circular(0);
    var bottomRightRadius = Radius.circular(0);
    switch (gamemode) {
      case "Classic":
        topLeftRadius = Radius.circular(10);
        topRightRadius = Radius.circular(10);
        bottomText = "64 pieces, win with a 4 in a row (including diagonals) or 2x2 of peices with the same attributes";
        break;
      case "16 Pieces":
        if (wantsToChallenge != "IOGhtkq1iEaLWfsXdhMkf3LACgS2") { //Bot
          bottomText = "There are only two colors and shapes, which means there are only 16 pieces";
        } else {
          bottomText = "For now, the bot can't play 16 Pieces";
        }
        break;
      case "Opposites":
        bottomText = "Additionally win with a 4 in a row or 2x2 of pieces that are all different colors or all different shapes";
        break;
      case "5x5":
        bottomLeftRadius = Radius.circular(10);
        bottomRightRadius = Radius.circular(10);
        bottomText = "Play on a 5x5 board!";
        break;
    }
    return GestureDetector(
      child: Container(
        decoration: new BoxDecoration(
          color: (selectedGamemode == gamemode) ? Colors.deepOrange : Colors.blueGrey[50],
          borderRadius: new BorderRadius.only(topLeft: topLeftRadius, topRight: topRightRadius, bottomLeft: bottomLeftRadius, bottomRight: bottomRightRadius),
          border: new Border.all(
            width: 2.0,
            color: Colors.black26,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              RichText(
                text: TextSpan(
                    style: TextStyle(
                        fontSize: 12.0,
                        color: (selectedGamemode == gamemode)
                            ? Colors.white
                            : (wantsToChallenge != "IOGhtkq1iEaLWfsXdhMkf3LACgS2" || gamemode == "Opposites" || gamemode == "Classic") //Change below too
                              ? Colors.black
                              : Colors.grey
                    ),
                    children: <TextSpan>[
                      TextSpan(text: "$gamemode\n", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),),
                      TextSpan(text: "$bottomText")
                    ]
                ),
              )
            ],
          ),
        ),
      ),
      onTap: (wantsToChallenge != "IOGhtkq1iEaLWfsXdhMkf3LACgS2" || gamemode == "Opposites" || gamemode == "Classic") ? () {
        setState(() {
          selectedGamemode = gamemode;
        });
      } : null
    );
  }

  getPlayerTypeDescription(position) {
    if (allPlayers[position] == "IOGhtkq1iEaLWfsXdhMkf3LACgS2") { //Bot
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(padding: EdgeInsets.all(4.0),),
          Text("Play for practice   |   Games and pieces not saved", style: TextStyle(color: Colors.black),),
          Padding(padding: EdgeInsets.all(4.0),),
          Text("The bot gives random pieces, and plays on random tiles", style: TextStyle(color: Colors.black),)
        ],
      );
    } else if (playingWith.contains(allPlayers[position])) {
      return Text("You're already playing with this player");
    } else if (sentChallenge.contains(allPlayers[position])) {
      return Text("You already sent this player a challenge");
    } else if (challengedBy.contains(allPlayers[position])) {
      return Text("This player already sent you a challenge");
    } else if (waitingDismiss.contains(allPlayers[position])) {
      return Text("This player needs to dismiss a game with you first");
    } else if (needToDismiss.contains(allPlayers[position])) {
      return Text("You need to dismiss a game with this player first");
    } else if (allPlayers[position] == userFullId) {
      return Text("This is you", style: TextStyle(color: Colors.black),);
    } else {
      return Text("Tap here to challenge this player!", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),);
    }
  }

  isAvailableToChallenge(position) {
    if (!playingWith.contains(allPlayers[position]) && !sentChallenge.contains(allPlayers[position]) && !challengedBy.contains(allPlayers[position])
      && !waitingDismiss.contains(allPlayers[position]) && !needToDismiss.contains(allPlayers[position])) {
      return true;
    } else {
      return false;
    }
  }

  readAvailablePlayers() async {
    if (!preventExtraLoading) {
      preventExtraLoading = true;
      var tempPlayingWith = [];
      var tempSentChallenge = [];
      var tempChallengedBy = [];
      var tempWaitingDismiss = [];
      var tempNeedToDismiss = [];
      await database.reference().child("gamesInProgress").orderByChild("player1").equalTo(userFullId).once().then((DataSnapshot snapshot) {
        var list = snapshot.value?.values?.toList();
        list?.forEach((item) {
          if (item["player1dismiss"] == 1 && item["player2dismiss"] == 0) {
            if (!tempWaitingDismiss.contains(item["player2"])) {
              tempWaitingDismiss.add(item["player2"]);
            }
          } else if (item["player1dismiss"] == 0 && item["player2dismiss"] == 1) {
            if (!tempNeedToDismiss.contains(item["player2"])) {
              tempNeedToDismiss.add(item["player2"]);
            }
          } else {
            if (!tempPlayingWith.contains(item["player2"])) {
              tempPlayingWith.add(item["player2"]);
            }
          }
        });
      });
      await database.reference().child("gamesInProgress").orderByChild("player2").equalTo(userFullId).once().then((DataSnapshot snapshot) {
        var list = snapshot.value?.values?.toList();
        list?.forEach((item) {
          if (item["player1dismiss"] == 0 && item["player2dismiss"] == 1) {
            if (!tempWaitingDismiss.contains(item["player1"])) {
              tempWaitingDismiss.add(item["player1"]);
            }
          } else if (item["player1dismiss"] == 1 && item["player2dismiss"] == 0) {
            if (!tempNeedToDismiss.contains(item["player1"])) {
              tempNeedToDismiss.add(item["player1"]);
            }
          } else {
            if (!tempPlayingWith.contains(item["player1"])) {
              tempPlayingWith.add(item["player1"]);
            }
          }
        });
      });
      await database.reference().child("requestedGames").orderByChild("requesterId").equalTo(userFullId).once().then((DataSnapshot snapshot) {
        var list = snapshot.value?.values?.toList();
        list?.forEach((item) {
          if (!tempSentChallenge.contains(item["opponentId"])) {
            tempSentChallenge.add(item["opponentId"]);
          }
        });
      });
      await database.reference().child("requestedGames").orderByChild("opponentId").equalTo(userFullId).once().then((DataSnapshot snapshot) {
        var list = snapshot.value?.values?.toList();
        list?.forEach((item) {
          if (!tempChallengedBy.contains(item["requesterId"])) {
            tempChallengedBy.add(item["requesterId"]);
          }
        });
      });
      await database.reference().child("Players").once().then((DataSnapshot snapshot) {
        Map<dynamic, dynamic> map = snapshot.value;
        var sortedKeys = map.keys.toList(growable:false)
          ..sort((k1, k2) => map[k1]["playernumber"].compareTo(map[k2]["playernumber"]));
        LinkedHashMap sortedMap = new LinkedHashMap
            .fromIterable(sortedKeys, key: (k) => k, value: (k) => map[k]);
        sortedMap.remove(userFullId);
        allPlayers.clear();
        allPlayers.addAll(sortedMap.keys.toList());
      });
      playingWith.clear();
      sentChallenge.clear();
      challengedBy.clear();
      waitingDismiss.clear();
      needToDismiss.clear();
      playingWith.addAll(tempPlayingWith);
      sentChallenge.addAll(tempSentChallenge);
      challengedBy.addAll(tempChallengedBy);
      waitingDismiss.addAll(tempWaitingDismiss);
      needToDismiss.addAll(tempNeedToDismiss);
      try {
        setState(() {
          loadingPlayerLists = false;
        });
      } catch (e) {
        //Widget not in view
      }
      //print("playing with $playingWith");
      //print("sent challenge $sentChallenge");
      //print("challenged by $challengedBy");
      //print("waiting to dismiss $waitingDismiss");
      //print("need to dismiss $needToDismiss");
      preventExtraLoading = false;
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
}
