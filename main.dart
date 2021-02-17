import 'dart:async';
import 'dart:math';

import 'package:database_intro/models/game';
import 'package:database_intro/models/player.dart';
import 'package:database_intro/utils/authentication.dart';
import 'package:database_intro/utils/database_helper.dart';
import 'package:database_intro/widgets/games_nav.dart';
import 'package:database_intro/widgets/player_nav.dart';
import 'package:database_intro/widgets/profile_nav.dart';
import 'package:database_intro/widgets/right_nav.dart';
import 'package:database_intro/widgets/play_nav.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'dart:math' as math;
import 'dart:collection';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final version = 1.63;

List _games;
List _players;

final GoogleSignIn _googleSignIn = new GoogleSignIn();

enum AuthStatus {
  NOT_DETERMINED,
  NOT_LOGGED_IN,
  LOGGED_IN,
}

//TODO:
//Can nudge game requests infinitely, probably checks requested date, not nudge date
//Spectate games
//Undo giving piece? Edit challenge message?
//How to play page
//Languages
//Highlight winning pieces in games tab end-game board?
//Make a way to forfeit
//Most won by and most lost by win method in profile stats page
//When releasing, I'll need to do something about color blindness. "r" "g" "b" "y" on the pieces?

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var db = new DatabaseHelper();
  final FirebaseDatabase database = FirebaseDatabase.instance;

  runApp(new MaterialApp(
    title: "Kvarto",
    debugShowCheckedModeBanner: false,
    home: new Home(),
  ));
}

class Home extends StatefulWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  @override
  State<StatefulWidget> createState() {
    return new HomeState();
  }
}

class HomeState extends State<Home> {
  var currentBuildNumber = version;
  var requiredBuildNumber = 0.0;
  int _selectedIndex = 0; //Default bottom navigation bar tab
  final List<Widget> _children = [
    ProfileNav(),
    PlayNav(),
    PlayerNav(),
    GamesNav(),
    RightNav(),
  ];
  var disposed = false;
  var db = new DatabaseHelper();
  final FirebaseDatabase database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  final _formKey = new GlobalKey<FormState>();

  String _email;
  String _password;

  bool _isLoading = false;
  bool _isLoginForm = true;
  String _errorMessage = "";
  var authStatus = AuthStatus.NOT_DETERMINED;
  var _userId;

  var firebaseLoadError = false;

  @override
  void initState() {
    super.initState();

    versionCheck();
    canWriteData(10);

    database.reference().child("version").onChildChanged.listen(versionChanged);

    //If the user isn't signed in, authStatus is NOT_LOGGED_IN
    _auth.currentUser().then((user) {
      setState(() {
        if (user != null) {
          _userId = user?.uid;
        }
        authStatus =
        user?.uid == null ? AuthStatus.NOT_LOGGED_IN : AuthStatus.LOGGED_IN;
      });

      setUserToken();
    });
  }

  @override
  void dispose() {
    super.dispose();
    disposed = true;
  }

  versionChanged(Event event) {
    versionCheck();
  }

  versionCheck() async {
    await database.reference().child("version").once().then((DataSnapshot snapshot) {
      setState(() {
        try {
          requiredBuildNumber = snapshot.value["version"];
        } catch (e) {
          requiredBuildNumber = (snapshot.value["version"]).toDouble();
        }
      });
    });

  }
  
  canWriteData(timeout) async {
    //https://stackoverflow.com/questions/44298521/cant-suddenly-connect-to-my-firebase-database
    var rdm = new Random();
    var randomNumber = rdm.nextInt(1000000);
    var isInside = false;
    Timer t = Timer(Duration(seconds: timeout), () {
      if (!disposed) {
        print("just timed out");
        if (isInside) {
          setState(() {
            firebaseLoadError = false;
          });
        } else {
          setState(() {
            firebaseLoadError = true;
          });
        }
      }
    });
    //database.reference().set("test");
    await database.reference().child("onlineCheck").set(randomNumber);
    isInside = true;
  }

  setUserToken() {
    if (_userId != null) {
      _firebaseMessaging.getToken().then((token){
        database.reference().child("Players").orderByChild("playerid").equalTo(_userId).once().then((DataSnapshot snapshot) {
          List data = snapshot.value.values.toList();
          var playerId = data[0]["playerid"];
          database.reference().child("Players/$playerId/token").set(token);
        });
      });
    }
  }

  static HomeState of(BuildContext context) {
    final HomeState navigator =
    context.findAncestorStateOfType<HomeState>();

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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    //Show different pages depending on authStatus
    //Most authentication code credit to https://medium.com/flutterpub/flutter-how-to-do-user-login-with-firebase-a6af760b14d5
    if (currentBuildNumber >= requiredBuildNumber && !firebaseLoadError) {
      switch (authStatus) {
        case AuthStatus.NOT_DETERMINED:
          return new Scaffold(
            appBar: new AppBar(
              title: new Text("Kvarto"),
              centerTitle: true,
              backgroundColor: Colors.deepOrange,
            ),
            body: new Center(child: Text("Loading...", style: new TextStyle(fontSize: 60.0, color: Colors.white),)),
          );
          break;
        case AuthStatus.NOT_LOGGED_IN:
          return new Scaffold(
              appBar: new AppBar(
                title: new Text("Kvarto"),
                centerTitle: true,
                backgroundColor: Colors.deepOrange,
              ),
              body: Stack(
                children: <Widget>[
                  _showForm(),
                  showCircularProgress(),
                ],
              ));
          break;
        case AuthStatus.LOGGED_IN:
        //Signed in
          return new Scaffold(
            appBar: new AppBar(
              title: new Text("Kvarto"),
              centerTitle: true,
              backgroundColor: Colors.deepOrange,
            ),
            body: _children[_selectedIndex],
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                    icon: Icon(Icons.person), title: Text("Profile")),
                BottomNavigationBarItem(
                    icon: Icon(Icons.play_arrow), title: Text("Play")),
                BottomNavigationBarItem(
                    icon: Icon(Icons.person_pin), title: Text("Players")),
                BottomNavigationBarItem(
                    icon: Icon(Icons.list), title: Text("Games")),
                BottomNavigationBarItem(
                    icon: Icon(Icons.apps), title: Text("Pieces"))
              ],
              currentIndex: _selectedIndex,
              fixedColor: Colors.deepOrangeAccent,
              onTap: _onNavItemTapped,
            ),
          );
          break;
      }
    } else if (!firebaseLoadError) {
      return new Scaffold(
        appBar: new AppBar(
          title: new Text("Kvarto"),
          centerTitle: true,
          backgroundColor: Colors.deepOrange,
        ),
        body: Container(
          child: Center(
            child: Text("You need to update from version $currentBuildNumber to $requiredBuildNumber", style: TextStyle(fontSize: 20),),
          ),
        ),
      );
    } else {
      return new Scaffold(
        appBar: new AppBar(
          title: new Text("Kvarto"),
          centerTitle: true,
          backgroundColor: Colors.deepOrange,
        ),
        body: Container(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text("Something went wrong when communicating with the server.\n\n"
                      "Make sure you are connected to the internet.\n\n"
                      "If you are connected but you're still getting this error, "
                      "then my database must not be responding (I'm not sure why, "
                      "it happens every now and then). Expect it to be back in "
                      "10-15 minutes.", style: TextStyle(fontSize: 20),),
                  Padding(padding: EdgeInsets.all(8.0),),
                  RaisedButton(
                    onPressed: () {
                      canWriteData(1);
                    },
                    child: Text("Refresh", style: TextStyle(color: Colors.white),),
                    color: Colors.deepOrange[800],
                  )
                ],
              )
            )
          ),
        ),
      );
    }
  }

  Widget showCircularProgress() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    return Container(
      height: 0.0,
      width: 0.0,
    );
  }

  Widget _showForm() {
    return new Container(
        padding: EdgeInsets.all(16.0),
        child: new Form(
          key: _formKey,
          child: new ListView(
            shrinkWrap: true,
            children: <Widget>[
              showLogo(),
              showEmailInput(),
              showPasswordInput(),
              showPrimaryButton(),
              showSecondaryButton(),
              showErrorMessage(),
            ],
          ),
        ));
  }

  Widget showLogo() {
    return new Hero(
      tag: 'hero',
      child: Padding(
        padding: EdgeInsets.fromLTRB(0.0, 40.0, 0.0, 0.0),
        child: CircleAvatar(
          backgroundColor: Colors.transparent,
          radius: 72.0,
          child: Image.asset('lib/images/logo1.png'),
        ),
      ),
    );
  }

  Widget showEmailInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 40.0, 0.0, 0.0),
      child: new TextFormField(
        maxLines: 1,
        keyboardType: TextInputType.emailAddress,
        autofocus: false,
        decoration: new InputDecoration(
            hintText: 'Email',
            icon: new Icon(
              Icons.mail,
              color: Colors.grey,
            )),
        validator: (value) => value.isEmpty ? 'Email can\'t be empty' : null,
        onSaved: (value) => _email = value.trim(),
      ),
    );
  }

  Widget showPasswordInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 15.0, 0.0, 0.0),
      child: new TextFormField(
        maxLines: 1,
        obscureText: true,
        autofocus: false,
        decoration: new InputDecoration(
            hintText: 'Password',
            icon: new Icon(
              Icons.lock,
              color: Colors.grey,
            )),
        validator: (value) => value.isEmpty ? 'Password can\'t be empty' : null,
        onSaved: (value) => _password = value.trim(),
      ),
    );
  }

  Widget showPrimaryButton() {
    return new Padding(
        padding: EdgeInsets.fromLTRB(0.0, 45.0, 0.0, 0.0),
        child: SizedBox(
          height: 40.0,
          child: new RaisedButton(
            elevation: 5.0,
            shape: new RoundedRectangleBorder(
                borderRadius: new BorderRadius.circular(30.0)),
            color: Colors.deepOrange,
            child: new Text(_isLoginForm ? 'Login' : 'Create account',
                style: new TextStyle(fontSize: 20.0, color: Colors.white)),
            onPressed: validateAndSubmit,
          ),
        ));
  }

  Widget showSecondaryButton() {
    return new FlatButton(
        child: new Text(
            _isLoginForm ? 'Create an account' : 'Have an account? Sign in',
            style: new TextStyle(fontSize: 18.0, fontWeight: FontWeight.w300)),
        onPressed: toggleFormMode);
  }

  void toggleFormMode() {
    //resetForm();
    setState(() {
      _isLoginForm = !_isLoginForm;
    });
  }

  Widget showErrorMessage() {
    if (_errorMessage.length > 0 && _errorMessage != null) {
      return new Text(
        _errorMessage,
        style: TextStyle(
            fontSize: 13.0,
            color: Colors.red,
            height: 1.0,
            fontWeight: FontWeight.w300),
      );
    } else {
      return new Container(
        height: 0.0,
      );
    }
  }

  void loginCallback() {
    _auth.currentUser().then((user) {
      setState(() {
        _userId = user.uid.toString();
      });
    });
    setState(() {
      authStatus = AuthStatus.LOGGED_IN;
    });
  }

  void logoutCallback() {
    //setState(() {
      authStatus = AuthStatus.NOT_LOGGED_IN;
      _userId = "";
    //});
  }

  bool validateAndSave() {
    final form = _formKey.currentState;
    if (form.validate()) {
      form.save();
      return true;
    }
    return false;
  }

  void validateAndSubmit() async {
    Auth auth = new Auth();

    setState(() {
      _errorMessage = "";
      _isLoading = true;
    });
    if (validateAndSave()) {
      String userId = "";
      try {
        if (_isLoginForm) {
          userId = await auth.signIn(_email, _password);
          print('Signed in: $userId');
        } else {
          userId = await auth.signUp(_email, _password);
          //widget.auth.sendEmailVerification();
          //_showVerifyEmailSentDialog();
          var highestPlayerNo;
          database.reference().child("Players").orderByChild("playernumber").limitToLast(1).once().then((DataSnapshot snapshot) {
            try {
              var map = new Map<String, dynamic>.from(snapshot.value);
              var list = map.values.toList();
              highestPlayerNo = list[0]["playernumber"];
            } catch (e) {
              List<dynamic> list = snapshot.value;
              highestPlayerNo = list[0]["playernumber"];
            }
            var playerData = {
              'playerid': userId.toString(),
              'playername': "Player",
              'playernumber': (highestPlayerNo + 1)
            };
            database.reference().child("/Players/${userId.toString()}").set(playerData);
          });

          print('Signed up user: $userId');
        }
        setState(() {
          _isLoading = false;
        });

        if (userId.length > 0 && userId != null) {
          loginCallback();
        }
      } catch (e) {
        print('Error: $e');
        setState(() {
          _isLoading = false;
          try {
            _errorMessage = e.message;
          } catch (e) {
           _errorMessage = e.toString();
          }
          _formKey.currentState.reset();
        });
      }

    }
  }

//  Future<int> deleteGame(int id) async {
//    int gameDeleted = await db.deleteGame(id);
//    return gameDeleted;
//  }

//  Future<int> deletePlayer(int id) async {
//    int playerDeleted = await db.deletePlayer(id);
//    return playerDeleted;
//  }

//  Future<String> getWins(int id) async {
//    String wins = await db.getWins(id);
//
//    return wins;
//  }

//  Future<String> getPlayed(int id) async {
//    String played = await db.getPlayed(id);
//
//    return played;
//  }

  void _onNavItemTapped(int index) {
    canWriteData(10);
    setState(() {
      _selectedIndex = index;
    });
  }

//  List get getGames {
//    return _games;
//  }
//
//  List get getPlayers {
//    return _players;
//  }

//  void addGame(var player1, var player2, var winner, var date, var winmethod) async {
//    await db.saveGame(new Game("$player1", "$player2", "$winner", "$date", "$winmethod"));
//  }

//  void addPlayer(var name) async {
//    await db.savePlayer(new Player("$name"));
//  }

}

//Copyright 2021, Joseph Winningham, All rights reserved.
