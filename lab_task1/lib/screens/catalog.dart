import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/cart.dart';
import '../models/catalog.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Catalog', style: TextStyle(color: Colors.black)),
            backgroundColor: Colors.yellow,
            floating: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => context.go('/catalog/cart'),
              ),
            ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= CatalogModel.itemNames.length) return null;
                var item = CatalogModel().items[index];
                return _CatalogItem(item: item);
              },
              childCount: CatalogModel.itemNames.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogItem extends StatelessWidget {
  final Item item;

  const _CatalogItem({required this.item});

  @override
  Widget build(BuildContext context) {
    var cart = context.watch<CartModel>();
    var isInCart = cart.items.contains(item);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            color: item.color,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              item.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton(
            onPressed: isInCart ? null : () => context.read<CartModel>().add(item),
            style: TextButton.styleFrom(
              foregroundColor: isInCart ? Colors.grey : Colors.blue,
            ),
            child: isInCart ? const Text('ADDED') : const Text('ADD'),
          ),
        ],
      ),
    );
  }
}
