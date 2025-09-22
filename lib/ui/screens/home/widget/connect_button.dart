import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obd_log/bloc/OBD/obd_cubit.dart';

class ConnectButton extends StatelessWidget {
  const ConnectButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      child: const Text("Scan & Connect OBD"),
      onPressed: () async {
        final devices = await context.read<ObdCubit>().scan();

        if (devices.isEmpty) {
          showModalBottomSheet(
            context: context,
            builder: (_) =>
                const Center(child: Text("Nenhum dispositivo encontrado")),
          );
          return;
        }

        showModalBottomSheet(
          context: context,
          builder: (_) => ListView.builder(
            itemCount: devices.length,
            itemBuilder: (_, index) {
              final device = devices[index];
              return ListTile(
                title: Text(device.name),
                subtitle: Text(device.id),
                onTap: () {
                  context.read<ObdCubit>().connect(device);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }
}
