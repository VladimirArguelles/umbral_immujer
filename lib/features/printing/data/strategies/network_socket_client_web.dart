import 'network_socket_client.dart';

NetworkSocketClient getNetworkSocketClient() => NetworkSocketClientWeb();

class NetworkSocketClientWeb implements NetworkSocketClient {
  @override
  Future<bool> sendData(String host, int port, List<int> data) async {
    // En navegadores web, los sockets TCP crudos están restringidos por la seguridad de la sandbox
    return false;
  }

  @override
  Future<bool> testConnection(String host, int port) async {
    return true;
  }
}
