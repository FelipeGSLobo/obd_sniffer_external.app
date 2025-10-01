import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obd_log/bloc/Bluetooth/device_cubit.dart';
import 'package:obd_log/bloc/OBD/obd_cubit.dart';
import 'package:obd_log/data/models/obd_protocol.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class PanelContainer extends StatefulWidget {
  const PanelContainer({super.key});

  @override
  State<PanelContainer> createState() => _PanelContainerState();
}

class _PanelContainerState extends State<PanelContainer> {
  ObdProtocol? selectedProtocol;
  Timer? timer;
  double rpm = 0;
  StreamSubscription<String>? subscription;
  final protocols = [
    ObdProtocol(name: 'Automático', code: 'AT SP 0', rpm: '010C'),
    ObdProtocol(name: 'ISO 15765-4 (CAN 11-bit 500kb/s) Padrão', code: 'AT SP 6', rpm: '010C'),
    ObdProtocol(name: 'ISO 15765-4 (CAN 29-bit 500kb/s)', code: 'AT SP 7', rpm: '010C'),
    ObdProtocol(name: 'ISO 15765-4 (CAN 29-bit 250kb/s)', code: 'AT SP 8', rpm: '010C'),
    ObdProtocol(name: 'SAE J1939 (Caminhões 29-bit)', code: 'AT SP A', rpm: '0300F004'),
    ObdProtocol(name: 'ISO 14230 / KWP2000 (K-line lenta)', code: 'AT SP 3', rpm: '010C'),
    ObdProtocol(name: 'ISO 9141-2 (K-line padrão)', code: 'AT SP 1', rpm: '010C'),
    ObdProtocol(name: 'J1850 PWM (Ford antigo)', code: 'AT SP 2', rpm: '010C'),
    ObdProtocol(name: 'J1850 VPW (GM antigo)', code: 'AT SP 4', rpm: '010C'),
    ObdProtocol(name: 'ISO 15765-4', code: 'AT SP 6', rpm: '010C'),
  ];

  @override
  dispose() {
    timer?.cancel();
    timer = null;
    super.dispose();
    subscription?.cancel();
    subscription = null;
  }

  @override
  Widget build(BuildContext context) {
    final deviceCubit = context.read<ObdDeviceCubit>();
    final logCubit = context.read<ObdLogCubit>();

    if (deviceCubit.state.connectedDevice == null) {
      return const Text('Nenhum dispositivo conectado.');
    }

    void startListening() {
      deviceCubit.sendCommand(selectedProtocol!.code, logCubit);
      if (timer != null) {
        timer!.cancel();
        timer = null;
        return;
      }
      timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        deviceCubit.sendCommand(selectedProtocol!.rpm, logCubit);
      });
      //Ler retorno
      subscription = deviceCubit.listen((resp) {
        print("Lendo retorno: $resp");
        try {
          if (selectedProtocol!.name.startsWith("SAE J1939")) {
            //Caminhão
            // RPM = ((byte4 << 8) + byte3) * 0.125
            final bytes = resp.split(' ');
            if (bytes.length >= 6) {
              final byte3 = int.tryParse(bytes[4], radix: 16) ?? 0;
              final byte4 = int.tryParse(bytes[5], radix: 16) ?? 0;
              setState(() {
                rpm = ((byte4 << 8) + byte3) * 0.125;
              });
            }
          } else if (selectedProtocol!.name.startsWith("ISO 15765-4")) {
            //Carro
            // RPM = ((byte2*256)+byte3)/4
            final bytes = resp.split(' ');
            if (bytes.length >= 5) {
              final byte2 = int.tryParse(bytes[3], radix: 16) ?? 0;
              final byte3 = int.tryParse(bytes[4], radix: 16) ?? 0;
              setState(() {
                rpm = ((byte2 * 256) + byte3) / 4;
              });
            }
          }
        } catch (e) {}
      }, logCubit);
    }

    Container buildGaugeContainer() {
      startListening();
      double max = 8000;
      double mid = max / 2;
      double preMax = max - mid / 2;
      double pointer = rpm;
      return Container(
          height: 200,
          child: Center(
              child: SfRadialGauge(axes: <RadialAxis>[
            RadialAxis(minimum: 0, maximum: max, ranges: <GaugeRange>[
              GaugeRange(startValue: 0, endValue: mid, color: Colors.green),
              GaugeRange(
                  startValue: mid, endValue: preMax, color: Colors.orange),
              GaugeRange(startValue: preMax, endValue: max, color: Colors.red)
            ], pointers: <GaugePointer>[
              NeedlePointer(value: pointer)
            ], annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                  widget: Text(pointer.toStringAsFixed(0),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  angle: 90,
                  positionFactor: 0.5)
            ])
          ])));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          DropdownButton<ObdProtocol>(
            hint: const Text('Selecione um protocolo'),
            value: selectedProtocol,
            items: protocols
                .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedProtocol = value;
              });
            },
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                selectedProtocol?.name ?? 'Nenhum protocolo selecionado',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (selectedProtocol != null) buildGaugeContainer(),
        ],
      ),
    );
  }
}
