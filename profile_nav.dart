import 'dart:async';
import 'dart:collection';

import 'package:database_intro/models/player.dart';
import 'package:database_intro/utils/authentication.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:database_intro/utils/database_helper.dart';
import 'package:flutter_image/network.dart';
import 'package:flutter/material.dart';
import 'package:database_intro/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class ProfileNav extends StatefulWidget {
  @override
  _ProfileNavState createState() => _ProfileNavState();
}

class _ProfileNavState extends State<ProfileNav> {
  var db = new DatabaseHelper();

  final FirebaseDatabase database = FirebaseDatabase.instance;

  var piecesPlayed = -1;

  TextEditingController _usernameController = new TextEditingController();

  Auth auth = new Auth();
  var isSignedOut = false;
  var _isLoading = true;
  var userDisplayName = '';
  var userEmail = '';
  var userIsEmailVerified = true; //Might as well not show anything if we don't no whether or not to yet
  var userPhotoURL = '';
  var userFullId = '';
  var userPartialId = '';

  @override
  void initState() {
    super.initState();
    //_readIdMap();
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
        body: Stack(
          children: <Widget>[
            showProfile(),
            showCircularProgress(),
          ],
        ));
  }

  Widget showProfile() {
    if (!isSignedOut) {
      getProfileData(); //updates text
    }
    return Column(
      children: <Widget>[
        Expanded(flex: 15, child: topInfo()),
        Expanded(flex: 85, child: mainContainer()),
      ],
    );
  }

  Widget topInfo() {
    return Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.deepOrange,
              width: 3.0,
            ),
          ),
        ),
        child: SizedBox.expand(
          child: Center(
              child: Stack(
                children: <Widget>[
              Row(
              mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Flexible(
                    flex: 20,
                    child: Text(
                      (userDisplayName?.isNotEmpty ?? false) ? userDisplayName : "Player",
                      style: TextStyle(color: Colors.black, fontSize: 24.0),
                    ),
                  ),
                  Flexible(
                    flex: 10,
                    child: ButtonTheme(
                      minWidth: 36.0,
                      height: 36.0,
                      child: FlatButton(
                        onPressed: () => _showUsernameEdit(context),
                        child: new Icon(Icons.edit),
                      ),
                    ),
                  ),
                ],
              ),
                  Positioned(
                    right: 16.0,
                    child: FlatButton(
                      onPressed: () async {
                        isSignedOut = true;
                        Auth auth = new Auth();
                        await auth.signOut();
                        HomeState homestate = new HomeState();
                        homestate.logoutCallback();
                        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                      },
                      child: Text("Sign out"),
                      padding: new EdgeInsets.fromLTRB(64.0, 0, 0, 0),),
                  )
          ],
        ))
    ),);
  }

  Widget mainContainer() {
    return Container(
      child: Column(
        children: <Widget>[
          Padding(padding: EdgeInsets.all(8.0),),
          Row(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Expanded(
                flex: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("Pieces played:", style: TextStyle(fontSize: 20.0),),
                    )
                  ],
                ),
              ),
              Expanded(
                flex: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: (piecesPlayed == -1) ? Text("Loading...") : Text(piecesPlayed.toString(), style: TextStyle(fontSize: 20.0),),
                    )
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
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

  void getProfileData() {
    auth.getCurrentUser().then((user) {
      setState(() {
        _isLoading = false;
        userDisplayName = user.displayName;
        userEmail = user.email;
        userIsEmailVerified = user.isEmailVerified;
        userPhotoURL = user.photoUrl;
        userFullId = user.uid;
        userPartialId = user.uid.substring(0, 8);
      });
      _readPiecesPlayed();
    });
  }

  void _showUsernameEdit(BuildContext context) {
    _usernameController.text =
    (userDisplayName?.isNotEmpty ?? false) ? userDisplayName : "Player";
    var alert = new AlertDialog(
      title: new Text("Edit Username"),
      content: new Container(
        width: 200.0,
        height: 50.0,
        child: new Column(
          children: <Widget>[
            new Container(
              height: 36.0,
              width: 200.0,
              child: TextField(
                controller: _usernameController,
                autofocus: true,
              ),
            )
          ],
        ),
      ),
      actions: <Widget>[
        FlatButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text("Cancel")),
        FlatButton(
            onPressed: () async {
              /*
              database.reference().child("Players").orderByChild("playernumber").once().then((DataSnapshot snapshot) {
                List items = snapshot.value;
                items.forEach((item) {
                  setState(() {
                    _idMap[item["playerid"]] = item["playernumber"];
                  });
                }); */
                auth.getCurrentUser().then((user) {
                  UserUpdateInfo updateInfo = UserUpdateInfo();
                  updateInfo.displayName = _usernameController.text;
                  user.updateProfile(updateInfo);
                  database.reference().child("Players/$userFullId/playername").set(_usernameController.text);
                  Navigator.pop(context);
                });
              //});
            },
            child: Text("OK")),
      ],
    );
    showDialog(context: context, builder: (context) => alert);
  }

  /*
  _readIdMap() {
    database.reference().child("Players").orderByChild("playernumber").once().then((DataSnapshot snapshot) {
      List items = snapshot.value.values.toList();
      items.forEach((item) {
        setState(() {
          _idMap[item["playerid"]] = item["playernumber"];
        });
      });
    });
  }
  */
  
  _readPiecesPlayed() {
    database.reference().child("Pieces").orderByChild("playedby").equalTo(userFullId).once().then((DataSnapshot snapshot) {
      if (snapshot.value == null) {
        piecesPlayed = 0;
      } else {
        piecesPlayed = snapshot.value.length;
      }
    });
  }

}
