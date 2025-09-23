import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obd_log/bloc/Bluetooth/device_cubit.dart';
import 'package:obd_log/bloc/Bluetooth/device_state.dart';
import 'package:obd_log/bloc/OBD/obd_cubit.dart';

class ConnectButton extends StatelessWidget {
  const ConnectButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      child: const Text("Scan & Connect OBD"),
      onPressed: () {
        context.read<ObdDeviceCubit>().scan();
        showModalBottomSheet(
          context: context,
          builder: (_) {
            return BlocBuilder<ObdDeviceCubit, ObdDeviceState>(
              builder: (context, state) {
                if (state.status == ConnectionStatus.connecting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.devices.isEmpty) {
                  return const Center(
                      child: Text("Nenhum dispositivo encontrado"));
                }

                return ListView.builder(
                  itemCount: state.devices.length,
                  itemBuilder: (_, index) {
                    final device = state.devices[index];
                    return ListTile(
                      title: Text(device.name),
                      subtitle: Text(device.id),
                      onTap: () {
                        final logCubit = context.read<ObdLogCubit>();
                        context
                            .read<ObdDeviceCubit>()
                            .connect(device, logCubit);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
