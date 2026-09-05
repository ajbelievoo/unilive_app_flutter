import 'package:flutter/material.dart';

class ReelFilterScreen extends StatefulWidget {
  const ReelFilterScreen({super.key, required this.videoPath});

  final String videoPath;

  @override
  State<ReelFilterScreen> createState() => _ReelFilterScreenState();
}

class _ReelFilterScreenState extends State<ReelFilterScreen> {
  int _selectedFilter = 0;

  static const _filters = [
    {'name': 'None', 'color': Colors.transparent},
    {'name': 'Warm', 'color': Color(0x30FF9800)},
    {'name': 'Cool', 'color': Color(0x30039BE5)},
    {'name': 'Vintage', 'color': Color(0x338D6E63)},
    {'name': 'B&W', 'color': Color(0x40000000)},
    {'name': 'Sepia', 'color': Color(0x33F0E68C)},
    {'name': 'Vivid', 'color': Color(0x26E91E63)},
    {'name': 'Fade', 'color': Color(0x33FFFFFF)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Filters', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed:
                () => Navigator.pop(context, _filters[_selectedFilter]['name']),
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.topLeft,
              fit: StackFit.expand,
              children: [
                Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(
                      Icons.video_file,
                      color: Colors.white38,
                      size: 64,
                    ),
                  ),
                ),
                if (_selectedFilter > 0)
                  Container(color: _filters[_selectedFilter]['color'] as Color),
              ],
            ),
          ),
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _selectedFilter == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border:
                          selected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: (f['color'] as Color).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.filter_vintage,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          f['name'] as String,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
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
