import 'package:flutter/foundation.dart';
import 'catalog.dart';

class CartModel extends ChangeNotifier {
  final List<Item> _items = [];

  List<Item> get items => _items;

  int get totalPrice => _items.fold(0, (total, current) => total + current.price);

  void add(Item item) {
    if (!_items.contains(item)) {
      _items.add(item);
      notifyListeners();
    }
  }

  void remove(Item item) {
    _items.remove(item);
    notifyListeners();
  }
}
