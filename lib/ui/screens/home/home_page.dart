import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:obd_log/bloc/Bluetooth/device_cubit.dart';
import 'package:obd_log/bloc/Bluetooth/device_state.dart';
import 'package:obd_log/bloc/OBD/obd_cubit.dart';
import 'package:obd_log/data/models/obd_device.dart';
import 'package:obd_log/data/models/obd_log.dart';
import 'package:obd_log/services/log_exporter.dart';
import 'package:obd_log/ui/components/panel_container.dart';
import 'package:permission_handler/permission_handler.dart';

// HomePage agora é StatelessWidget, pois o estado é 100% gerenciado pelos Cubits.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceCubit = context.read<ObdDeviceCubit>();
    final logCubit = context.read<ObdLogCubit>();
    final customController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('OBD Sniffer'),
        actions: [
          // O Dropdown agora lê o protocolo diretamente do estado do Cubit.
          BlocBuilder<ObdDeviceCubit, ObdDeviceState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButton<ProtocolType>(
                  value: deviceCubit.currentProtocol,
                  onChanged: (v) {
                    if (v != null) {
                      deviceCubit.setProtocol(v);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                        value: ProtocolType.classic,
                        child: Text('Classic (SPP)')),
                    DropdownMenuItem(
                        value: ProtocolType.ble, child: Text('BLE')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // PAINEL DE CONTROLE
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  onPressed: () async {
                    await [
                      Permission.bluetoothScan,
                      Permission.bluetoothConnect,
                      Permission.location,
                    ].request();
                    deviceCubit.scan();
                  },
                  label: const Text('Scan'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.link_off),
                  onPressed: () => deviceCubit.disconnect(),
                  label: const Text('Disconnect'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => logCubit.clear(),
                  label: const Text('Clear Log'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  onPressed: () async {
                    try {
                      final logs = context.read<ObdLogCubit>().state;
                      await LogExporter.export(logs);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erro ao exportar: $e')),
                      );
                    }
                  },
                  label: const Text('Exportar Log'),
                ),
                ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text("Command's List"),
                            content: const SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("ATZ - Reset"),
                                  Text("ATE0 - Eco OFF"),
                                  Text("ATL0 - Linefeeds OFF"),
                                  Text(
                                      "ATS0 - Espaços OFF, respostas contínuas, 1 para ativar"),
                                  Text("ATH0 - Headers OFF, 1 para ativar"),
                                  Text("AT SP 0 - Automatic Protocol"),
                                  Text("ATI - Device Info"),
                                  Text("AT RV - Batery Voltage"),
                                  Text("AT TA - Turn Adaptive Timing On"),
                                  Text("AT DP - Show Protocol"),
                                  Text("ATD - Display All Data"),
                                  Text(
                                      "AT SH EA 000 F9 - Set Header -> CAN ID: Engine ECU"),
                                  Divider(),
                                  Text(
                                    "Common OBD-II Commands:",
                                    style: TextStyle(fontSize: 17),
                                  ),
                                  Text("AT SP 6 - ISO 15765-4 CAN"),
                                  Text("AT SP 7 - ISO 15765-4 CAN Extended"),
                                  Text("AT SP 8 - ISO 15765-4 CAN Low Baud"),
                                  Text("0100 - Supported PIDs 01-20"),
                                  Text("010C - Engine RPM"),
                                  Text("010D - Vehicle Speed"),
                                  Text("0105 - Engine Coolant Temperature"),
                                  Text("010F - Intake Air Temperature"),
                                  Text("0111 - Throttle Position"),
                                  Text("012F - Fuel Level Input"),
                                  Text(
                                      "0131 - Distance Traveled Since Codes Cleared"),
                                  Text("0142 - Control Module Voltage"),
                                  Text("0144 - Ambient Air Temperature"),
                                  Text("0146 - Barometric Pressure"),
                                  Text("015C - Engine Oil Temperature"),
                                  Text("015E - Fuel Type"),
                                  Divider(),
                                  Text(
                                    "SAE J1939 Commands:",
                                    style: TextStyle(fontSize: 17),
                                  ),
                                  Text("AT SP A - SAE J1939"),
                                  Text(
                                      "AT CSM 0 - Turn of the silent monitoring"),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text("Command's List")),
              ],
            ),
          ),
          // SEÇÃO DE DISPOSITIVOS E COMANDOS
          Expanded(
            flex: 2,
            child: Row(
              children: [
                // LISTA DE DISPOSITIVOS
                Flexible(
                  flex: 2,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        const ListTile(title: Text('Dispositivos')),
                        Expanded(
                          // BlocConsumer reage a mudanças de estado E executa ações (como mostrar SnackBar).
                          child: BlocConsumer<ObdDeviceCubit, ObdDeviceState>(
                            listener: (context, state) {
                              if (state.status == ConnectionStatus.failed) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Falha ao conectar: ${state.errorMessage}')),
                                );
                              }
                            },
                            builder: (context, state) {
                              if (state.status == ConnectionStatus.connecting &&
                                  state.devices.isEmpty) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              if (state.devices.isEmpty) {
                                return const Center(
                                    child:
                                        Text('Nenhum dispositivo encontrado'));
                              }
                              return ListView.builder(
                                itemCount: state.devices.length,
                                itemBuilder: (context, index) {
                                  final device = state.devices[index];
                                  final isConnecting = state.status ==
                                          ConnectionStatus.connecting &&
                                      state.connectedDevice?.id == device.id;
                                  final isConnected = state.status ==
                                          ConnectionStatus.connected &&
                                      state.connectedDevice?.id == device.id;
                                  return ListTile(
                                    key: ValueKey(index),
                                    selected: isConnected,
                                    title: Text(device.name),
                                    subtitle: Text(device.id),
                                    trailing: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: isConnected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.green)
                                            : isConnecting
                                                ? const CircularProgressIndicator()
                                                : IconButton(
                                                    onPressed: () {
                                                      deviceCubit.connect(
                                                          device, logCubit);
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      padding: EdgeInsets.zero,
                                                      minimumSize:
                                                          const Size(24, 24),
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    ),
                                                    icon: const Icon(
                                                      Icons.link_outlined,
                                                      size: 24,
                                                    ),
                                                  )),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // PAINEL DE COMANDOS
                Flexible(
                  flex: 3,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: BlocBuilder<ObdDeviceCubit, ObdDeviceState>(
                      builder: (context, state) {
                        final isConnected =
                            state.status == ConnectionStatus.connected;
                        return Column(
                          children: [
                            ListTile(
                              title: Text(
                                  'Conectado: ${state.connectedDevice?.name ?? "Nenhum"}'),
                              subtitle: Text(
                                'Status: ${state.status.name}',
                                style: TextStyle(
                                  color:
                                      isConnected ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Mostra os botões de comando apenas se estiver conectado.
                            if (isConnected) ...[
                              Expanded(
                                  child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0),
                                      child: Wrap(
                                        spacing: 8,
                                        children: [
                                          ElevatedButton(
                                              onPressed: () => deviceCubit
                                                  .sendCommand('ATZ', logCubit),
                                              child: const Text('ATZ')),
                                          ElevatedButton(
                                              onPressed: () =>
                                                  deviceCubit.sendCommand(
                                                      'ATE0', logCubit),
                                              child: const Text('ATE0')),
                                          ElevatedButton(
                                              onPressed: () =>
                                                  deviceCubit.sendCommand(
                                                      'ATL0', logCubit),
                                              child: const Text('ATL0')),
                                          ElevatedButton(
                                              onPressed: () =>
                                                  deviceCubit.sendCommand(
                                                      'ATH0', logCubit),
                                              child: const Text('ATH0')),
                                          ElevatedButton(
                                              onPressed: () =>
                                                  deviceCubit.sendCommand(
                                                      'ATSP0', logCubit),
                                              child: const Text('ATSP0')),
                                          ElevatedButton(
                                              onPressed: () => deviceCubit
                                                  .sendCommand('ATI', logCubit),
                                              child: const Text('ATI')),
                                          ElevatedButton(
                                              onPressed: () =>
                                                  deviceCubit.sendCommand(
                                                      '0100', logCubit),
                                              child: const Text('0100')),
                                          ElevatedButton(
                                              onPressed: () =>
                                                  deviceCubit.sendCommand(
                                                      '010C', logCubit),
                                              child: const Text('RPM')),
                                          ElevatedButton(
                                              onPressed: () =>
                                                  deviceCubit.sendCommand(
                                                      '010D', logCubit),
                                              child: const Text('SPEED')),
                                          ElevatedButton(
                                              onPressed: () => deviceCubit
                                                  .sendCommand('ATA', logCubit),
                                              child: const Text('ATA')),
                                          ElevatedButton(
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    return AlertDialog(
                                                      title:
                                                          const Text("Painel"),
                                                      content:
                                                          const SingleChildScrollView(
                                                        child: PanelContainer(),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(),
                                                          child: const Text(
                                                              'Fechar'),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              },
                                              child: const Text('Panel')),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: customController,
                                              decoration: const InputDecoration(
                                                  hintText:
                                                      'Comando custom (ex: 0105)'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              final txt =
                                                  customController.text.trim();
                                              if (txt.isNotEmpty) {
                                                deviceCubit.sendCommand(
                                                    txt, logCubit);
                                                customController.clear();
                                              }
                                            },
                                            child: const Text('Enviar'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                            ] else
                              const Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Conecte-se a um dispositivo para enviar comandos.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // LOGS
          Expanded(
            flex: 1,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Column(
                children: [
                  const ListTile(title: Text('Logs')),
                  Expanded(
                    child: BlocBuilder<ObdLogCubit, List<ObdLogModel>>(
                      builder: (context, logs) {
                        if (logs.isEmpty) {
                          return const Center(child: Text('Sem logs'));
                        }
                        return ListView.builder(
                          itemCount: logs.length,
                          reverse:
                              true, // Mostra os logs mais recentes primeiro
                          itemBuilder: (context, index) {
                            // A lógica de inversão foi ajustada para funcionar corretamente com 'reverse: true'.
                            final log = logs[logs.length - 1 - index];
                            return ListTile(
                              leading: Icon(
                                  log.sent ? Icons.upload : Icons.download,
                                  color: log.sent ? Colors.blue : Colors.green),
                              title: Text(log.frame),
                              subtitle: Text(DateFormat('HH:mm:ss.SSS')
                                  .format(log.timestamp)),
                              dense: true,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
