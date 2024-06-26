import 'dart:io';
import 'package:flutter/material.dart';
import '../logging/exercise_logger.dart';
import 'sensor_page.dart';
import 'host_page.dart';
import 'join_page.dart';

class PartnerWorkout extends StatefulWidget {
  const PartnerWorkout({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<PartnerWorkout> createState() => _PartnerWorkout();
}

class _PartnerWorkout extends State<PartnerWorkout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: SizedBox(
          child: FloatingActionButton(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            child: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              ExerciseLogger.instance?.logButtonPressed("BackButton");
              ExerciseLogger.instance?.logPageNavigate("paired_workout", "home_page");
              Navigator.pop(context);
            },
          ),
        ),
        body: Center(
            child: SizedBox(
                width: 175,
                child: Container(
                    alignment: Alignment.center,
                    child: ListView(shrinkWrap: true,children: <Widget>[
                      SizedBox(
                          height: 65,
                          width: 10,
                          child: Center(
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30)),
                                      padding: const EdgeInsets.all(0)),
                                  onPressed: () {
                                    ExerciseLogger.instance?.logButtonPressed("HostWorkoutButton");
                                    ExerciseLogger.instance?.logPageNavigate("paired_workout", "host_page");
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const HostPage(
                                                    title: 'Start a session')));
                                  },
                                  child: const ListTile(
                                    title: Text("START A SESSION",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                        )),
                                  )))),
                      SizedBox(
                          height: 65,
                          width: 10,
                          child: Center(
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30)),
                                      padding: const EdgeInsets.all(0)),
                                  onPressed: () {
                                    ExerciseLogger.instance?.logButtonPressed("JoinWorkoutButton");
                                    ExerciseLogger.instance?.logPageNavigate("paired_workout", "join_workout");
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const JoinPage(
                                                    title: 'Join existing session')));
                                  },
                                  child: const ListTile(
                                    title: Text("JOIN EXISTING SESSION",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                        )),
                                  )))
                      ),
                    ],
                    )
                )
            )
        )
    );
  }
}
