import 'package:flutter/material.dart';

class StickerPickerScreen extends StatefulWidget {
  const StickerPickerScreen({super.key});

  @override
  State<StickerPickerScreen> createState() => _StickerPickerScreenState();
}

class _StickerPickerScreenState extends State<StickerPickerScreen> {
  String _selectedCategory = 'All';
  static const _categories = ['All', 'Emojis', 'Animals', 'Food', 'Decor'];

  static const _stickers = [
    {'emoji': '😀', 'category': 'Emojis'},
    {'emoji': '😍', 'category': 'Emojis'},
    {'emoji': '🥳', 'category': 'Emojis'},
    {'emoji': '😎', 'category': 'Emojis'},
    {'emoji': '🤩', 'category': 'Emojis'},
    {'emoji': '😭', 'category': 'Emojis'},
    {'emoji': '🐱', 'category': 'Animals'},
    {'emoji': '🐶', 'category': 'Animals'},
    {'emoji': '🦁', 'category': 'Animals'},
    {'emoji': '🐼', 'category': 'Animals'},
    {'emoji': '🍕', 'category': 'Food'},
    {'emoji': '🍔', 'category': 'Food'},
    {'emoji': '🍰', 'category': 'Food'},
    {'emoji': '☕', 'category': 'Food'},
    {'emoji': '🌸', 'category': 'Decor'},
    {'emoji': '⭐', 'category': 'Decor'},
    {'emoji': '💎', 'category': 'Decor'},
    {'emoji': '🔥', 'category': 'Decor'},
  ];

  List<Map<String, String>> get _filtered =>
      _selectedCategory == 'All' ? _stickers : _stickers.where((s) => s['category'] == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Stickers', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: Colors.purple,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.white54),
                    backgroundColor: Colors.white10,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final s = _filtered[i];
                return GestureDetector(
                  onTap: () => Navigator.pop(context, s['emoji']),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(s['emoji']!, style: const TextStyle(fontSize: 32))),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
