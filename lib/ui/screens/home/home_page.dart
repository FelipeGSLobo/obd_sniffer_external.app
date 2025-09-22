import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/obd_device.dart';
import '../../../data/models/obd_log.dart';
import '../../../bloc/OBD/obd_cubit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<ObdDevice> devices = [];
  ObdDevice? selected;
  final _customController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ObdCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('OBD Sniffer'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<ProtocolType>(
              value: cubit.currentProtocol,
              onChanged: (v) {
                if (v != null) {
                  cubit.setProtocol(v);
                  setState(() {
                    selected = null;
                    devices = [];
                  });
                }
              },
              items: const [
                DropdownMenuItem(
                    value: ProtocolType.classic, child: Text('Classic (SPP)')),
                DropdownMenuItem(value: ProtocolType.ble, child: Text('BLE')),
              ],
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: () async {
                  final list = await cubit.scan();
                  setState(() {
                    devices = list;
                  });
                },
                child: const Text('Scan'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  await cubit.disconnect();
                  setState(() {
                    selected = null;
                  });
                },
                child: const Text('Disconnect'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  await cubit.clear();
                },
                child: const Text('Clear Log'),
              ),
            ],
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Flexible(
                  flex: 1,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        const ListTile(title: Text('Devices')),
                        Expanded(
                          child: ListView.builder(
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              final d = devices[index];
                              return ListTile(
                                title: Text(d.name),
                                subtitle: Text(d.id),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    setState(() {
                                      selected = d;
                                    });
                                    try {
                                      await cubit.connect(d);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  'Erro ao conectar: \$e')));
                                    }
                                  },
                                  child: const Text('Connect'),
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                              'Connected: ${cubit.connectedDevice?.name ?? "Nenhum"}'),
                          subtitle: Text(
                              'Bluetooth: ${cubit.currentProtocol == ProtocolType.classic ? "Classic" : "BLE"}'),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton(
                                onPressed: () => cubit.sendCommand('ATZ'),
                                child: const Text('ATZ')),
                            ElevatedButton(
                                onPressed: () => cubit.sendCommand('ATI'),
                                child: const Text('ATI')),
                            ElevatedButton(
                                onPressed: () => cubit.sendCommand('0100'),
                                child: const Text('0100')),
                            ElevatedButton(
                                onPressed: () => cubit.sendCommand('010C'),
                                child: const Text('RPM')),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                  child: TextField(
                                      controller: _customController,
                                      decoration: const InputDecoration(
                                          hintText:
                                              'Comando custom (ex: 0120 ou ATSP0)'))),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                  onPressed: () {
                                    final txt = _customController.text.trim();
                                    if (txt.isNotEmpty) cubit.sendCommand(txt);
                                  },
                                  child: const Text('Send'))
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const ListTile(title: Text('Logs')),
                  Expanded(
                    child: BlocBuilder<ObdCubit, List<ObdLogModel>>(
                        builder: (context, logs) {
                      return ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final l = logs[index];
                          return ListTile(
                            leading:
                                Icon(l.sent ? Icons.upload : Icons.download),
                            title: Text(l.frame),
                            subtitle: Text(l.timestamp.toIso8601String()),
                          );
                        },
                      );
                    }),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
