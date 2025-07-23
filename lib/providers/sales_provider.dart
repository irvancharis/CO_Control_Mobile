import 'package:flutter/material.dart';

class SalesProvider extends ChangeNotifier {
  // Daftar penjualan
  List<dynamic> _sales = [];
  List<dynamic> get sales => _sales;

  // TODO: Tambahkan metode untuk fetch, add, update, delete sales menggunakan API

  void setSales(List<dynamic> salesData) {
    _sales = salesData;
    notifyListeners();
  }
}
