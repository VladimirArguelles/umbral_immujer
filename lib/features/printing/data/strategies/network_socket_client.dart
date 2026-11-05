import 'network_socket_client_stub.dart'
    if (dart.library.io) 'network_socket_client_io.dart'
    if (dart.library.js_interop) 'network_socket_client_web.dart';

abstract class NetworkSocketClient {
  factory NetworkSocketClient() => getNetworkSocketClient();
  Future<bool> sendData(String host, int port, List<int> data);
  Future<bool> testConnection(String host, int port);
}
