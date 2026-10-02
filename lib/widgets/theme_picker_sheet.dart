import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/theme_root.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:belive/widgets/preloader.dart';

void showThemePickerSheet(
  BuildContext context, {
  required ValueChanged<String> onSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ThemePickerSheet(onSelected: onSelected),
  );
}

class _ThemePickerSheet extends StatefulWidget {
  const _ThemePickerSheet({required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  State<_ThemePickerSheet> createState() => _ThemePickerSheetState();
}

class _ThemePickerSheetState extends State<_ThemePickerSheet> {
  final _themes = <ThemeItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    try {
      final root = await ApiService.getTheme();
      if (mounted) {
        setState(() {
          _themes.addAll(root.theme);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: AppTheme.themed(context, 0xFF1A1A2E, 0xFFF8F7FE),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppTheme.fg(context, 0.3), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Choose Background',
              style: TextStyle(color: AppTheme.fg(context), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_loading)
            const Expanded(child: Center(child: Preloader()))
          else if (_themes.isEmpty)
            Expanded(child: Center(child: Text('No themes available', style: TextStyle(color: AppTheme.fg(context, 0.54)))))
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _themes.length,
                itemBuilder: (_, i) {
                  final theme = _themes[i];
                  final url = theme.theme ?? '';
                  final name = (theme.name ?? '').trim();
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSelected(url);
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (_, __) => Container(color: AppTheme.fg(context, 0.1)),
                              errorWidget: (_, __, ___) => Container(color: AppTheme.fg(context, 0.1), child: Icon(Icons.broken_image, color: AppTheme.fg(context, 0.24))),
                            ),
                          ),
                        ),
                        if (name.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(name, style: TextStyle(color: AppTheme.fg(context), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
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
