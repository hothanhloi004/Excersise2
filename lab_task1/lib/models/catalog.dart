import 'package:flutter/material.dart';

class Item {
  final int id;
  final String name;
  final Color color;
  final int price = 42;

  Item({required this.id, required this.name, required this.color});

  @override
  int get hashCode => id;

  @override
  bool operator ==(Object other) => other is Item && other.id == id;
}

class CatalogModel {
  static final List<String> itemNames = [
    'Code Smell',
    'Control Flow',
    'Interpreter',
    'Recursion',
    'Sprint',
    'Heisenbug',
    'Spaghetti',
    'Hydra Code',
    'Off-By-One',
    'Scope',
    'Callback',
    'Closure',
    'Automata',
    'Bit Shift',
    'Boilerplate',
  ];

  List<Item> get items => List.generate(
        itemNames.length,
        (index) => Item(
          id: index,
          name: itemNames[index],
          color: Colors.primaries[index % Colors.primaries.length],
        ),
      );
}
