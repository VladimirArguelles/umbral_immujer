import 'dart:io';
import 'network_socket_client.dart';

NetworkSocketClient getNetworkSocketClient() => NetworkSocketClientIo();

class NetworkSocketClientIo implements NetworkSocketClient {
  @override
  Future<bool> sendData(String host, int port, List<int> data) async {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    socket.add(data);
    await socket.flush();
    await socket.close();
    return true;
  }

  @override
  Future<bool> testConnection(String host, int port) async {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
    await socket.close();
    return true;
  }
}
