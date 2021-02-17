import 'package:database_intro/main.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GameView extends StatefulWidget {
  GameView(this.userFullId, this.opponentId, this.turnType, this.piecemap, this.selectedpiece, this.gameInProgressId, this.opponentName,
      this.isPlayer1, this.winner, this.player1dismiss, this.player2dismiss, this.gamemode);

  String userFullId;
  String opponentId;
  String turnType;
  List<dynamic> piecemap;
  int selectedpiece;
  String gameInProgressId;
  String opponentName;
  bool isPlayer1;
  String winner;
  int player1dismiss;
  int player2dismiss;
  String gamemode;

  var selectedToGive = -1;
  var piecePlacedAt = -1;


  GameViewState gameViewState = GameViewState();
  @override
  State<StatefulWidget> createState() => gameViewState;

  updateGameInfo(turnType, piecemap, selectedpiece, winner, player1dismiss, player2dismiss) {
    this.turnType = turnType;
    this.piecemap = piecemap;
    this.selectedpiece = selectedpiece;
    this.winner = winner;
    this.player1dismiss = player1dismiss;
    this.player2dismiss = player2dismiss;
    gameViewState.updateScreen();
  }
}

class GameViewState extends State<GameView> {

  final FirebaseDatabase database = FirebaseDatabase.instance;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _messageController = new TextEditingController();

  var chat = <dynamic>[];
  var noChat = false;
  var anyUnreadMessages = false;
  var unreadMessages = [];

  var allowOnlyOneChatUpdate = false;

  var showPiecesLeft = false;

  @override
  void initState() {
    super.initState();

    database.reference().child("Chat").onChildAdded.listen(_chatChanged);
    database.reference().child("Chat").onChildChanged.listen(_chatChanged);
    database.reference().child("Chat").onChildRemoved.listen(_chatChanged);
    database.reference().child("Chat").onChildMoved.listen(_chatChanged);

    updateChat(widget.gameInProgressId);
  }

  _chatChanged(Event event) {
    updateChat(widget.gameInProgressId);
  }

  @override
  Widget build(BuildContext context) {
    double drawerWidth = MediaQuery.of(context).size.width*0.7;
    return Scaffold(
        key: _scaffoldKey,
        drawerEdgeDragWidth: 0,
        appBar: AppBar(
          title: Text("You vs. ${widget.opponentName}"),
          backgroundColor: Colors.deepOrange,
          leading: new IconButton(icon: Icon(Icons.arrow_back), onPressed: () {
            Navigator.pop(context);
          }),
          actions: <Widget>[
            Stack(
              children: <Widget>[
                Center(
                  child: IconButton(icon: Icon(Icons.chat), onPressed: () {
                    clearUnreadMessages();
                    _scaffoldKey.currentState.openDrawer();
                  },),
                ),
                (anyUnreadMessages) ?
                IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(28.0, 25.0, 0.0, 0.0),
                    child: Container(
                      width: 10.0,
                      height: 10.0,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: Colors.blue
                      ),
                    ),
                  ),
                ) : Container()
              ],
            )
          ],
        ),
        drawer: Container(
          width: drawerWidth,
          child: Drawer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: ListView(
                      physics: NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: <Widget>[
                        Container(
                          height: 150.0,
                          child: DrawerHeader(
                            child: Text('Chat with ${widget.opponentName}', style: TextStyle(fontSize: 20.0),),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange[400],
                            ),
                          ),
                        ),
                        (chat.isNotEmpty && !noChat) ? Container(
                          height: MediaQuery.of(context).size.height - 150 - 90 - 8,
                          child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: AlwaysScrollableScrollPhysics(),
                              itemCount: chat.length,
                              itemBuilder: (_, position) {
                                var date = new DateTime.fromMillisecondsSinceEpoch(chat[position]["time"]);
                                var format = new DateFormat("MMM d,").add_jm();
                                var formattedDate = format.format(date);
                                double containerWidth = MediaQuery.of(context).size.width*0.7 - 40;
                                return Container(
                                  child: ListTile(
                                    title: Row(
                                      mainAxisAlignment: (chat[position]["sender"] == widget.userFullId) ? MainAxisAlignment.end : MainAxisAlignment.start,
                                      children: <Widget>[
                                        (chat[position]["sender"] == widget.userFullId)
                                            ? Text("You ")
                                            : Text("${widget.opponentName} "),
                                        Text(formattedDate, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),)
                                      ],

                                    ),
                                    subtitle: Container(
                                        width: containerWidth,
                                        child: Text(chat[position]["message"], textAlign: (chat[position]["sender"] == widget.userFullId) ? TextAlign.end : TextAlign.start,)
                                    ),
                                  ),
                                );
                              }
                          ),
                        ) :
                        (noChat) ? Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("Start the conversation below"),
                        ) :
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("Loading..."),
                        )

                      ],
                    ),
                  ),

                  Container(
                    color: Colors.blueGrey[100],
                    height: 90 + MediaQuery.of(context).viewInsets.bottom,
                    child: Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                autofocus: false,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  border: new OutlineInputBorder(
                                      borderSide: new BorderSide(color: Colors.white)
                                  ),
                                  labelText: 'Message:',
                                ),
                              ),
                            ),
                            ButtonTheme(
                              minWidth: 60,
                              child: FlatButton(
                                onPressed: () {
                                  if (_messageController.text.isNotEmpty) {
                                    var key = database.reference().child("Chat/${widget.gameInProgressId}").push().key;
                                    var now = DateTime.now().millisecondsSinceEpoch;
                                    var data = {
                                      "message": _messageController.text,
                                      "sender": widget.userFullId,
                                      "time": now,
                                      "viewed": false,
                                      "key": key
                                    };
                                    database.reference().child("Chat/${widget.gameInProgressId}/$key").set(data);
                                    _messageController.clear();
                                  } else {
                                    print("message was empty");
                                  }

                                },
                                child: Icon(Icons.send),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
          ),
        ),
        body: Container(
          color: Colors.blueGrey[200],
          child: Stack(
            children: <Widget>[
              SizedBox.expand(
                child: ListView(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.fromLTRB(0, 48, 0, 0),
                          child: _getUpperInstructions(),
                        ),
                        (widget.turnType != "2") ?
                        Align(
                          alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(0, 8, 16, 8),
                              child: InkWell(
                                child: Container(
                                  padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                                  child: Text((showPiecesLeft) ? "Hide pieces left" : "Show pieces left", style: TextStyle(color: Colors.white),),
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange,
                                    borderRadius: BorderRadius.circular(4)
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    if (showPiecesLeft) {
                                      showPiecesLeft = false;
                                    } else {
                                      showPiecesLeft = true;
                                    }
                                  });
                                },
                              ),
                            )
                        ) : Container(),
                        (widget.turnType != "2" && showPiecesLeft)
                            ? showPiecesLeftContainer()
                            : Container(),
                        _getKvartoBoard()
                      ],
                    ),
                  ]
                )
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: EdgeInsets.fromLTRB(32, 8, 24, 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(bottomRight: Radius.circular(10), bottomLeft: Radius.circular(10)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey,
                            blurRadius: 5.0,
                            spreadRadius: 3.0
                        )
                      ]
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text("Gamemode: ${widget.gamemode}", style: TextStyle(fontSize: 20, color: Colors.black),),
                      GestureDetector(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(8.0, 0, 0, 0),
                          child: Container(
                            width: 20.0,
                            height: 20.0,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.deepOrange
                            ),
                            child: Center(
                              child: Text("?", style: TextStyle(color: Colors.white, fontSize: 18),),
                            ),
                          ),
                        ),
                        onTap: () {
                          showGamemodeDescription();
                        },
                      )
                    ],
                  ),
                ),
              ),
            ]
          ),
        )
    );
  }

  showGamemodeDescription() {
    var content;
    switch (widget.gamemode) {
      case "Classic":
        content = "The classic version of Kvarto.\nThere are 64 pieces, and you win with a 4 in a row or 2x2 of peices with the same attributes";
        break;
      case "16 Pieces":
        content = "There are only two colors and shapes, which means there are only 16 pieces";
        break;
      case "Opposites":
        content = "Watch out! You can additionally lose (or win) from pieces that are all different colors or all different shapes";
        break;
      case "5x5":
        content = "You're playing on a 5x5 board! Still only a four in a row or 2x2 of matching pieces is required to win.";
        break;
    }
    var alert = new AlertDialog (
        title: new Text("About ${widget.gamemode}"),
        content: new Text(content),
        actions: <Widget>[
          FlatButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Close")),
        ]);
    showDialog(context: context, builder: (context) => alert);
  }

  Widget showPiecesLeftContainer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        new SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: (widget.gamemode != "16 Pieces") ? Row(
              children: <Widget>[
                new Padding(padding: EdgeInsets.all(16.0)),
                new Container(child: newButtonGrid(Colors.red, false)),
                new Padding(padding: EdgeInsets.all(16.0)),
                new Container(child: newButtonGrid(Colors.green, false)),
                new Padding(padding: EdgeInsets.all(16.0)),
                new Container(child: newButtonGrid(Colors.yellow, false)),
                new Padding(padding: EdgeInsets.all(16.0)),
                new Container(child: newButtonGrid(Colors.blue, false)),
                new Padding(padding: EdgeInsets.all(16.0)),
              ],
            ) : Column(
              children: <Widget>[
                new Container(child: newButtonGrid(Colors.red, false)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(child: newButtonGrid(Colors.blue, false)),
              ],
            )
        ),
      ],
    );
  }

  updateChat(gameInProgressId) async {
    if (!allowOnlyOneChatUpdate) {
      allowOnlyOneChatUpdate = true;
      await database.reference().child("Chat/$gameInProgressId").once().then((DataSnapshot snapshot) {
        allowOnlyOneChatUpdate = false;
        try {
          if (snapshot.value == null) {
            setState(() {
              noChat = true;
            });
          } else {
            setState(() {
              noChat = false;
              chat = snapshot.value.values.toList()
                ..sort((a, b) => a['time'].toString().compareTo(b['time'].toString()));
              determineUnreadMessages();
            });
          }
        } catch (e) {
          //Not in view
        }
      });
    }
  }

  determineUnreadMessages() {
    unreadMessages.clear();
    var anyUnreadMessagesTemp = false;
    chat.forEach((item) {
      if (item["sender"] != widget.userFullId && !item["viewed"]) {
        anyUnreadMessagesTemp = true;
        unreadMessages.add(item["key"]);
      }
    });
    if (anyUnreadMessagesTemp) {
      setState(() {
        anyUnreadMessages = true;
      });
    } else {
      setState(() {
        anyUnreadMessages = false;
      });
    }
  }

  clearUnreadMessages() {
    unreadMessages.forEach((item) {
      database.reference().child("Chat/${widget.gameInProgressId}/$item/viewed").set(true);
    });
  }

  Widget _getUpperInstructions() {
    switch (widget.turnType) {
      case "0":
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text("Your turn",
              style: TextStyle(
                  fontSize: 25.0
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
            ),
            Text("Waiting on a piece from ${widget.opponentName}...",
              style: TextStyle(
                  fontSize: 20.0
              ),
            )
          ],
        );
        break;
      case "1":
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text("Your turn to play!",
              style: TextStyle(
                  fontSize: 25.0
              ),
            ),
            (widget.piecePlacedAt == -1) ?
            Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 8.0),
                  child: Text("${widget.opponentName} gave you:"),
                ),
                Container(
                  child: _getPieceImageFromId(widget.selectedpiece),
                  width: 70.0,
                  height: 70.0,
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(0.0, 16.0, 0.0, 0.0),
                  child: Text("Tap an empty tile to play it"),
                ),
              ],
            ) :
            Padding(
              padding: EdgeInsets.fromLTRB(0.0, 50.0, 0.0, 32.0),
              child: RaisedButton(
                onPressed: () async {
                  var oldPiecePlayedAt = widget.piecePlacedAt;
                  widget.piecePlacedAt = -1;
                  setState(() {
                    widget.turnType = "5";
                  });
                  var tempPieceMap = widget.piecemap;
                  tempPieceMap[oldPiecePlayedAt] = widget.selectedpiece;
                  widget.piecemap = tempPieceMap;

                  var player1, player2;
                  if (widget.isPlayer1) {
                    player1 = widget.userFullId;
                    player2 = widget.opponentId;
                  } else {
                    player1 = widget.opponentId;
                    player2 = widget.userFullId;
                  }

                  if (gameStatus(widget.piecemap, 'isGameOver') == 'true') {
                    var data = {
                      'player1': player1,
                      'player2': player2,
                      'turn': "-1",
                      'piecemap': widget.piecemap,
                      'selectedpiece': -1,
                      'winner': widget.userFullId,
                      'player1dismiss': 0,
                      'player2dismiss': 0,
                      'gamemode': widget.gamemode,
                      'lastaction': DateTime.now().millisecondsSinceEpoch,
                      'lastnudge': -1
                    };
                    database.reference().child("gamesInProgress/${widget.gameInProgressId}").set(data);
                    if (widget.opponentId != "IOGhtkq1iEaLWfsXdhMkf3LACgS2") { //bot
                      var notificationData = {
                        'type': 'gameOverNotification',
                        'sendTo': widget.opponentId,
                        'endedWith': widget.userFullId
                      };
                      database.reference().child("notificationRequests").push().set(notificationData);
                    }
                  } else if (gameStatus(widget.piecemap, 'isGameOver') == 'false') {
                    var data = {
                      'player1': player1,
                      'player2': player2,
                      'turn': widget.opponentId,
                      'piecemap': widget.piecemap,
                      'selectedpiece': -1,
                      'winner': "-1",
                      'player1dismiss': 0,
                      'player2dismiss': 0,
                      'gamemode': widget.gamemode,
                      'lastaction': DateTime.now().millisecondsSinceEpoch,
                      'lastnudge': -1
                    };
                    database.reference().child("gamesInProgress/${widget.gameInProgressId}").set(data);
                  } else { //Tie
                    var data = {
                      'player1': player1,
                      'player2': player2,
                      'turn': "-1",
                      'piecemap': widget.piecemap,
                      'selectedpiece': -1,
                      'winner': "Tie",
                      'player1dismiss': 0,
                      'player2dismiss': 0,
                      'gamemode': widget.gamemode,
                      'lastaction': DateTime.now().millisecondsSinceEpoch,
                      'lastnudge': -1
                    };
                    database.reference().child("gamesInProgress/${widget.gameInProgressId}").set(data);
                    if (widget.opponentId != "IOGhtkq1iEaLWfsXdhMkf3LACgS2") { //bot
                      var notificationData = {
                        'type': 'gameOverNotification',
                        'sendTo': widget.opponentId,
                        'endedWith': widget.userFullId
                      };
                      database.reference().child("notificationRequests").push().set(notificationData);
                    }
                  }
                },
                child: Text("Confirm placement", style: TextStyle(color: Colors.white),),
                color: Colors.deepOrange[800],
              ),
            )
          ],
        );
        break;
      case "2":
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text("You need to give ${widget.opponentName} a piece for their turn",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20.0
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
            ),
            new Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                new SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: (widget.gamemode != "16 Pieces") ? Row(
                    children: <Widget>[
                      new Padding(padding: EdgeInsets.all(16.0)),
                      new Container(child: newButtonGrid(Colors.red, true)),
                      new Padding(padding: EdgeInsets.all(16.0)),
                      new Container(child: newButtonGrid(Colors.green, true)),
                      new Padding(padding: EdgeInsets.all(16.0)),
                      new Container(child: newButtonGrid(Colors.yellow, true)),
                      new Padding(padding: EdgeInsets.all(16.0)),
                      new Container(child: newButtonGrid(Colors.blue, true)),
                      new Padding(padding: EdgeInsets.all(16.0)),
                    ],
                  ) : Column(
                    children: <Widget>[
                      new Container(child: newButtonGrid(Colors.red, true)),
                      new Padding(padding: EdgeInsets.all(8.0)),
                      new Container(child: newButtonGrid(Colors.blue, true)),
                    ],
                  )
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
            ),
            (widget.selectedToGive == -1) ?
            Container(
              padding: EdgeInsets.all(17.0),
              child: Text("Select a piece above"),
            ) :
            RaisedButton(
              onPressed: () {
                var oldSelectedToGive = widget.selectedToGive;
                widget.selectedToGive = -1;
                setState(() {
                  widget.turnType = "5";
                });
                database.reference().child("gamesInProgress/${widget.gameInProgressId}/selectedpiece").set(oldSelectedToGive);
                var data = {
                  'piece': oldSelectedToGive,
                  'givenby': widget.userFullId,
                  'playedby': widget.opponentId,
                  'gamemode': widget.gamemode
                };
                if (widget.opponentId != "IOGhtkq1iEaLWfsXdhMkf3LACgS2") { //Bot
                  database.reference().child("Pieces").push().set(data);
                }
              },
              child: Text("Confirm", style: TextStyle(color: Colors.white),),
              color: Colors.deepOrange[800],
            )
          ],
        );
        break;
      case "3":
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text("Waiting for ${widget.opponentName} to play",
              style: TextStyle(
                  fontSize: 25.0
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 8.0),
              child: Text("You gave them:"),
            ),
            Container(
              child: _getPieceImageFromId(widget.selectedpiece),
              width: 70.0,
              height: 70.0,
            )
          ],
        );
        break;
      case "4":
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text("Game Over",
              style: TextStyle(
                  fontSize: 25.0
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 8.0),
            ),
            (widget.winner == "Tie") ?
            Text(
              "It's a tie",
              style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold
              ),)
                : (widget.winner == widget.userFullId) ? Text(
              "You won!",
              style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold
              ),) : Text(
              "${widget.opponentName} won by ${gameStatus(widget.piecemap, 'winConditions')}",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20.0
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 8.0),
            ),
            RaisedButton(
              onPressed: () async {
                database.reference().child("gamesInProgress/${widget.gameInProgressId}").once().then((DataSnapshot snapshot) async {
                  if (snapshot.value == null) {
                    Scaffold.of(context).showSnackBar(SnackBar(
                      content: Text("This game already ended"),
                    ));
                    Navigator.pop(context);
                  } else {
                    if (widget.isPlayer1) {
                      await database.reference().child("gamesInProgress/${widget.gameInProgressId}/player1dismiss").set(1);
                      if (widget.opponentId == "IOGhtkq1iEaLWfsXdhMkf3LACgS2") { //Bot
                        database.reference().child("gamesInProgress/${widget.gameInProgressId}/player2dismiss").set(1);
                      }
                      Navigator.pop(context);
                    } else {
                      await database.reference().child("gamesInProgress/${widget.gameInProgressId}/player2dismiss").set(1);
                      if (widget.opponentId == "IOGhtkq1iEaLWfsXdhMkf3LACgS2") { //Bot
                        database.reference().child("gamesInProgress/${widget.gameInProgressId}/player1dismiss").set(1);
                      }
                      Navigator.pop(context);
                    }
                  }
                });
              },
              child: Text("Dismiss game", style: TextStyle(color: Colors.white),),
              color: Colors.deepOrange[800],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(0.0, 8.0, 0.0, 8.0),
            ),
            Text("(Both players must dismiss to end the game)\n(This ensures both players get a chance to see the ending board)", textAlign: TextAlign.center,)
          ],
        );
      case "5":
        return Text("Loading...", style: TextStyle(fontSize: 24),);
        break;
      default:
        return Text("Something went wrong. Error code \"Albino wolverine\"");
    }
  }

  dynamic gameStatus(piecemap, request) {
    var winConditions = [];
    var tilesForWin = [];
    var emptyTiles = false;
    var winPositions;
    if (widget.gamemode != "5x5") {
      winPositions = [
        [0, 1, 2, 3], //top row
        [4, 5, 6, 7], //second row
        [8, 9, 10, 11], //third row
        [12, 13, 14, 15], //fourth row
        [0, 4, 8, 12], //first column
        [1, 5, 9, 13], //second column
        [2, 6, 10, 14], //third column
        [3, 7, 11, 15], //fourth column
        [0, 1, 4, 5], //2x2 top left
        [2, 3, 6, 7], //2x2 top right
        [8, 9, 12, 13], //2x2 bottom left
        [10, 11, 14, 15], //2x2 bottom right
        [5, 6, 9, 10], //2x2 center
        [0, 5, 10, 15], //Diagonal normal
        [3, 6, 9, 12], //Diagonal reverse
        [1, 2, 5, 6], //2x2 middle top
        [4, 5, 8, 9], //2x2 middle left
        [6, 7, 10, 11], //2x2 middle right
        [9, 10, 13, 14] //2x2 middle bottom
      ];
    } else { //5x5
      winPositions = [
        //Horizontal lines
        [0, 1, 2, 3], [1, 2, 3, 4], [5, 6, 7, 8], [6, 7, 8, 9], [10, 11, 12, 13], [11, 12, 13, 14], [15, 16, 17, 18], [16, 17, 18, 19], [20, 21, 22, 23], [21, 22, 23, 24],
        //Vertical lines
        [0, 5, 10, 15], [5, 10, 15, 20], [1, 6, 11, 16], [6, 11, 16, 21], [2, 7, 12, 17], [7, 12, 17, 22], [3, 8, 13, 18], [8, 13, 18, 23], [4, 9, 14, 19], [9, 14, 19, 24],
        //2x2s
        [0, 1, 5, 6], [1, 2, 6, 7], [2, 3, 7, 8], [3, 4, 8, 9], [5, 6, 10, 11], [6, 7, 11, 12], [7, 8, 12, 13], [8, 9, 13, 14], [10, 11, 15, 16], [11, 12, 16, 17],
        [12, 13, 17, 18], [13, 14, 18, 19], [15, 16, 20, 21], [16, 17, 21, 22], [17, 18, 22, 23], [18, 19, 23, 24],
        //Diagonals
        [0, 6, 12, 18], [1, 7, 13, 19], [5, 11, 17, 23], [6, 12, 18, 24], [3, 7, 11, 15], [4, 8, 12, 16], [8, 12, 16, 20], [9, 13, 17, 21]
      ];
    }
    for (int i = 0; i < winPositions.length; i++) {
      if (piecemap[winPositions[i][0]] != -1 && piecemap[winPositions[i][1]] != -1 && piecemap[winPositions[i][2]] != -1 && piecemap[winPositions[i][3]] != -1) {
        var firstPiece = pieceAttributes(piecemap[winPositions[i][0]]);
        var secondPiece = pieceAttributes(piecemap[winPositions[i][1]]);
        var thirdPiece = pieceAttributes(piecemap[winPositions[i][2]]);
        var fourthPiece = pieceAttributes(piecemap[winPositions[i][3]]);
        var addToWinList = false;
        if (firstPiece[0] == secondPiece[0] && secondPiece[0] == thirdPiece[0] && thirdPiece[0] == fourthPiece[0]) {
          if (!winConditions.contains(firstPiece[0])) {
            winConditions.add(firstPiece[0]);
          }
          addToWinList = true;
        }
        if (firstPiece[1] == secondPiece[1] && secondPiece[1] == thirdPiece[1] && thirdPiece[1] == fourthPiece[1]) {
          if (!winConditions.contains(firstPiece[1])) {
            winConditions.add(firstPiece[1]);
          }
          addToWinList = true;
        }
        if (firstPiece[2] == secondPiece[2] && secondPiece[2] == thirdPiece[2] && thirdPiece[2] == fourthPiece[2]) {
          if (!winConditions.contains(firstPiece[2])) {
            winConditions.add(firstPiece[2]);
          }
          addToWinList = true;
        }
        if (firstPiece[3] == secondPiece[3] && secondPiece[3] == thirdPiece[3] && thirdPiece[3] == fourthPiece[3]) {
          if (!winConditions.contains(firstPiece[3])) {
            winConditions.add(firstPiece[3]);
          }
          addToWinList = true;
        }
        if (widget.gamemode == "Opposites") {
          var colors = ['Blue', 'Red', 'Green', "Yellow"];
          var shapes = ['Square', 'Circle', 'Triangle', 'Hexagon'];
          for (var j = 0; j < 4; j++) {
            if (colors.contains(firstPiece[j])) {
              colors.remove(firstPiece[j]);
            }
            if (shapes.contains(firstPiece[j])) {
              shapes.remove(firstPiece[j]);
            }
            if (colors.contains(secondPiece[j])) {
              colors.remove(secondPiece[j]);
            }
            if (shapes.contains(secondPiece[j])) {
              shapes.remove(secondPiece[j]);
            }
            if (colors.contains(thirdPiece[j])) {
              colors.remove(thirdPiece[j]);
            }
            if (shapes.contains(thirdPiece[j])) {
              shapes.remove(thirdPiece[j]);
            }
            if (colors.contains(fourthPiece[j])) {
              colors.remove(fourthPiece[j]);
            }
            if (shapes.contains(fourthPiece[j])) {
              shapes.remove(fourthPiece[j]);
            }
          }
          print("Colors after: $colors");
          print("Shapes after: $shapes");
          if (colors.isEmpty) {
            winConditions.add("Opposite Colors");
            addToWinList = true;
          }
          if (shapes.isEmpty) {
            winConditions.add("Opposite Shapes");
            addToWinList = true;
          }
        } else {
          print("gamemode was ${widget.gamemode}");
        }

        if (addToWinList) {
          if (!tilesForWin.contains(winPositions[i][0])) {
            tilesForWin.add(winPositions[i][0]);
          }
          if (!tilesForWin.contains(winPositions[i][1])) {
            tilesForWin.add(winPositions[i][1]);
          }
          if (!tilesForWin.contains(winPositions[i][2])) {
            tilesForWin.add(winPositions[i][2]);
          }
          if (!tilesForWin.contains(winPositions[i][3])) {
            tilesForWin.add(winPositions[i][3]);
          }
        }
      } else {
        emptyTiles = true;
      }
    }
    if (winConditions.isEmpty) {
      if (emptyTiles == true) {
        if (request == 'isGameOver')
          return 'false';
        if (request == 'tilesForWin')
          return [];
        return null;
      } else {
        if (request == 'isGameOver')
          return 'tie';
        if (request == 'winConditions')
          return 'Tie';
        if (request == 'tilesForWin')
          return [];
      }
    } else {
      if (request == 'isGameOver')
        return 'true';
      if (request == 'winConditions') {
        if (winConditions.length == 1) {
          return winConditions[0];
        } else {
          String returnable = '';
          for (var i = 0; i < winConditions.length; i++) {
            if (i == winConditions.length - 2) {
              returnable = returnable + winConditions[i] + " ";
            } else if (i == winConditions.length - 1) {
              returnable = returnable + "and " + winConditions[i];
            } else {
              returnable = returnable + winConditions[i] + ", ";
            }
          }
          return returnable;
        }

      }
      if (request == 'tilesForWin')
        return tilesForWin;
    }

  }

  List<String> pieceAttributes(pieceid) {
    var color;
    var shape;
    var height;
    var solidity;
    var idMinusColor;
    switch ((pieceid / 16).floor()) {
      case 0:
        color = 'Red';
        idMinusColor = pieceid;
        break;
      case 1:
        color = 'Green';
        idMinusColor = pieceid - 16;
        break;
      case 2:
        color = 'Yellow';
        idMinusColor = pieceid - 32;
        break;
      case 3:
        color = 'Blue';
        idMinusColor = pieceid - 48;
        break;
    }
    switch ((idMinusColor / 4).floor()) {
      case 0:
        shape = 'Square';
        break;
      case 1:
        shape = 'Circle';
        break;
      case 2:
        shape = 'Triangle';
        break;
      case 3:
        shape = 'Hexagon';
        break;
    }
    if ((pieceid / 2).floor() % 2 == 0) {
      height = 'Tall';
    } else {
      height = 'Short';
    }
    if (pieceid % 2 == 0) {
      solidity = 'Hollow';
    } else {
      solidity = 'Solid';
    }
    return [color, shape, height, solidity];
  }

  Widget _getKvartoBoard() {
    var pieceMap = widget.piecemap;
    var tilesForWin = gameStatus(widget.piecemap, 'tilesForWin');
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Container(
        child: GridView.count(
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: (widget.gamemode != "5x5") ? 4 : 5,
            shrinkWrap: true,
            children: List.generate((widget.gamemode != "5x5") ? 16 : 25, (index) {
              return Center(
                  child: (widget.turnType != "1") ? Container(
                    child: Padding(
                      padding: (widget.gamemode != "5x5") ? EdgeInsets.all(16.0) : EdgeInsets.all(8.0),
                      child: _getPieceImageFromId(pieceMap[index]),
                    ),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.deepOrange),
                        color: (tilesForWin.contains(index)) ? Colors.greenAccent[700] : Colors.blueGrey[100]

                    ),

                  ) :
                  Container(
                    child: (widget.piecemap[index] != -1) ? Padding(
                      padding: (widget.gamemode != "5x5") ? EdgeInsets.all(16.0) : EdgeInsets.all(8.0),
                      child: _getPieceImageFromId(pieceMap[index]),
                    ) :
                    ButtonTheme(
                      minWidth: 50.0,
                      height: 100.0,
                      child: FlatButton(
                        child: Padding(
                          padding: (widget.piecePlacedAt == index) ? EdgeInsets.all(0.0) : EdgeInsets.all(16.0),
                          child: (widget.piecePlacedAt == index) ? _getPieceImageFromId(widget.selectedpiece) : _getPieceImageFromId(pieceMap[index]) ,
                        ),
                        onPressed: () {
                          setState(() {
                            if (widget.piecePlacedAt != index) {
                              widget.piecePlacedAt = index;
                            } else {
                              widget.piecePlacedAt = -1;
                            }
                          });
                        },
                      ),
                    ),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.deepOrange),
                        color: (widget.piecePlacedAt == index) ? Colors.blueGrey[300] : Colors.blueGrey[100]

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

  updateScreen() {
    try {
      setState(() {

      });
    } catch (e) {
      //no game in view
    }
  }

  testConnection() {
    HomeState.of(context).canWriteData(10);
  }

  Container getNewContainer(colorSkip, number, asset1, color, clickable) {
    var pieceHasBeenUsed = false;
    var pieceAmount = (widget.gamemode != "5x5") ? 16 : 25;
    for (int i = 0; i < pieceAmount; i++){
      if (widget.piecemap[i] == (number + colorSkip)) {
        pieceHasBeenUsed = true;
      }
    }
    if (!pieceHasBeenUsed && clickable) {
      return new Container(
        width: 45.0,
        height: 45.0,
        decoration: new BoxDecoration(
            border: (widget.selectedToGive == (number + colorSkip)) ? Border.all(width: 1.5, color: Colors.black) : null
        ),
        child: new FlatButton(
          padding: EdgeInsets.all(0.0),
          child: new Container(
              width: 40.0,
              height: 40.0,
              child: new Image.asset(asset1)
          ),
          color: (widget.selectedToGive == (number + colorSkip)) ? color : Colors.blueGrey[200],
          shape: new RoundedRectangleBorder(),
          onPressed: () =>
              setState(() {
                if (widget.selectedToGive != (number + colorSkip)) {
                  widget.selectedToGive = (number + colorSkip);
                } else {
                  widget.selectedToGive = -1;
                }
              }),
        ),
      );
    } else if (pieceHasBeenUsed || widget.selectedpiece == (number + colorSkip)) {
      return Container(
        width: 45,
        height: 45,
        color: Colors.blueGrey[200],
      );
    } else {
      return Container(
          width: 45.0,
          height: 45.0,
          child: new Image.asset(asset1)
      );
    }
  }

  Container newButtonGrid(Color color, clickable) {
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
        child: (widget.gamemode != "16 Pieces") ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(colorSkip, 0, "lib/images/duct$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 4, "lib/images/pipe$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 8, "lib/images/tent$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 12, "lib/images/weird$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
              ],
            ),
            new Padding(padding: EdgeInsets.all(4.0)),
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(colorSkip, 1, "lib/images/cube$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 5, "lib/images/can$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 9, "lib/images/roof$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 13, "lib/images/bit$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
              ],
            ),
            new Padding(padding: EdgeInsets.all(4.0)),
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(colorSkip, 2, "lib/images/frame$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 6, "lib/images/ring$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 10, "lib/images/arrow$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 14, "lib/images/nut$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
              ],
            ),
            new Padding(padding: EdgeInsets.all(4.0)),
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(colorSkip, 3, "lib/images/plank$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 7, "lib/images/oreo$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 11, "lib/images/wedge$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 15, "lib/images/bolt$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
              ],
            ),
          ],
        ) : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(colorSkip, 0, "lib/images/duct$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 4, "lib/images/pipe$colorAddon.png", color, clickable)),
              ],
            ),
            new Padding(padding: EdgeInsets.all(8.0)),
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(colorSkip, 1, "lib/images/cube$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 5, "lib/images/can$colorAddon.png", color, clickable)),
              ],
            ),
            new Padding(padding: EdgeInsets.all(4.0)),
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(colorSkip, 2, "lib/images/frame$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 6, "lib/images/ring$colorAddon.png", color, clickable)),
              ],
            ),
            new Padding(padding: EdgeInsets.all(4.0)),
            new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                new Container(
                    child: getNewContainer(colorSkip, 3, "lib/images/plank$colorAddon.png", color, clickable)),
                new Padding(padding: EdgeInsets.all(8.0)),
                new Container(
                    child: getNewContainer(colorSkip, 7, "lib/images/oreo$colorAddon.png", color, clickable)),
              ],
            ),
          ],
        )
    );
  }

}
