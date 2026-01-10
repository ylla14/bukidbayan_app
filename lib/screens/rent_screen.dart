import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:flutter/material.dart';

class RentScreen extends StatelessWidget {
  const RentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      drawer: CustomDrawer(),
      body: Center(
        child: Padding(
          padding: EdgeInsetsGeometry.fromLTRB(30, 30, 30, 30),
          child: Column(
            children: [
              Text('Rent?'),
              Row(
                children: [
                  ElevatedButton(onPressed: doSomething, child: Text('Button 1'),
                  ),
                  ElevatedButton(onPressed: doSomething, child: Text('Button 2'))
                ],
              )
            ],
          ),
        ),
      )
    );
  }

  void doSomething() {
    print("Rent function called!");
  }
}