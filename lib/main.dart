import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obd_log/ui/screens/home/home_page.dart';
import 'bloc/Bluetooth/device_cubit.dart';
import 'bloc/OBD/obd_cubit.dart';

void main() {
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ObdDeviceCubit()),
        BlocProvider(create: (_) => ObdLogCubit()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'OBD Sniffer',
      home: HomePage(),
    );
  }
}
