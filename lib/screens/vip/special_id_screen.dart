/// Special ID screen — purchase a unique / vanity ID.
///
/// Upgraded with Bigo/Chamet-style features:
/// - Categories (Standard, Premium, Luxury) with different price tiers
/// - Popular suggestions
/// - Live preview of how the ID will look
/// - Min/max length validation per category
library special_id;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/vip_extended_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import 'package:belive/widgets/preloader.dart';

class SpecialIdScreen extends StatefulWidget {
  const SpecialIdScreen({super.key});

  @override
  State<SpecialIdScreen> createState() => _SpecialIdScreenState();
}

class _SpecialIdScreenState extends State<SpecialIdScreen> {
  static const String _tag = 'SpecialId';

  final _idCtrl = TextEditingController();
  bool _checking = false;
  bool _purchasing = false;
  bool? _available;
  bool _loadingConfig = true;

  final _categories = <SpecialIdCategory>[];
  final _suggestions = <String>[];
  SpecialIdCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _loadingConfig = true);
    try {
      final res = await ApiService.getSpecialIdConfig();
      if (res.status) {
        _categories.clear();
        _categories.addAll(res.categories);
        _suggestions.clear();
        _suggestions.addAll(res.suggestions);
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'loadConfig failed', e, s);
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  int get _price => _selectedCategory?.price ?? 1000;
  int get _minLen => _selectedCategory?.minLength ?? 4;
  int get _maxLen => _selectedCategory?.maxLength ?? 12;

  Future<void> _checkAvailability() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      Fluttertoast.showToast(msg: 'Enter a special ID');
      return;
    }
    if (id.length < _minLen || id.length > _maxLen) {
      Fluttertoast.showToast(msg: 'ID must be $_minLen-$_maxLen characters');
      return;
    }
    setState(() {
      _checking = true;
      _available = null;
    });
    try {
      final res = await ApiService.checkSpecialIdAvailability(id);
      setState(() => _available = res.status);
      if (res.status) {
        Fluttertoast.showToast(msg: 'ID is available!');
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'ID is not available');
      }
    } catch (e, s) {
      Log.e(_tag, 'checkAvailability failed', e, s);
      Fluttertoast.showToast(msg: 'Check failed');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _purchase() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty) {
      Fluttertoast.showToast(msg: 'Enter a special ID');
      return;
    }
    final session = context.read<SessionManager>();
    if (session.coins < _price) {
      Fluttertoast.showToast(msg: 'Insufficient diamonds. You need $_price diamonds.');
      return;
    }
    setState(() => _purchasing = true);
    try {
      final res = await ApiService.purchaseSpecialId(
        userId: session.userId,
        specialId: id,
        coin: _price,
      );
      if (res.status) {
        Fluttertoast.showToast(msg: 'Special ID purchased successfully!');
        if (mounted) context.pop();
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Purchase failed');
      }
    } catch (e, s) {
      Log.e(_tag, 'purchase failed', e, s);
      Fluttertoast.showToast(msg: 'Purchase failed');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _loadingConfig
                    ? const Center(child: Preloader())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHero(),
                            const SizedBox(height: 20),
                            _buildCategorySelector(),
                            const SizedBox(height: 16),
                            _buildIdInput(),
                            const SizedBox(height: 12),
                            if (_available != null) _buildAvailabilityIndicator(),
                            const SizedBox(height: 16),
                            if (_suggestions.isNotEmpty) _buildSuggestions(),
                            const SizedBox(height: 16),
                            _buildPreviewCard(),
                            const SizedBox(height: 16),
                            _buildPriceCard(),
                            const SizedBox(height: 20),
                            _buildPurchaseButton(),
                            const SizedBox(height: 16),
                            _buildInfoNote(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
          const Expanded(
            child: Center(
              child: Text('Special ID', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: AppTheme.goldGradient, borderRadius: BorderRadius.circular(16)),
      child: const Column(
        children: [
          Icon(Icons.diamond, size: 48, color: Colors.white),
          SizedBox(height: 12),
          Text('Get a Special ID', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Stand out with a unique vanity ID', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    if (_categories.isEmpty) {
      // Fallback default categories
      return Wrap(
        spacing: 8,
        children: [
          _categoryChip('Standard', 1000, true),
          _categoryChip('Premium', 5000, false),
          _categoryChip('Luxury', 10000, false),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      children: _categories.map((c) => _categoryChip(c.name ?? 'Standard', c.price, c.id == _selectedCategory?.id)).toList(),
    );
  }

  Widget _categoryChip(String name, int price, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _available = null;
          final cat = _categories.where((c) => c.name == name).firstOrNull;
          if (cat != null) {
            _selectedCategory = cat;
          } else {
            _selectedCategory = SpecialIdCategory(name: name, price: price);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppTheme.goldGradient : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.transparent : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text('$price', style: TextStyle(color: selected ? Colors.white : const Color(0xFFFFB800), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildIdInput() {
    return TextField(
      controller: _idCtrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Enter desired ID',
        labelStyle: const TextStyle(color: Colors.white54),
        hintText: 'e.g. king123',
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.alternate_email, color: Colors.white54),
        suffixIcon: _checking
            ? const SizedBox(width: 20, height: 20, child: Center(child: Preloader(strokeWidth: 2, color: Colors.white)))
            : IconButton(icon: const Icon(Icons.search, color: Colors.white54), onPressed: _checkAvailability),
      ),
      onChanged: (_) {
        if (_available != null) setState(() => _available = null);
      },
    );
  }

  Widget _buildAvailabilityIndicator() {
    if (_available == true) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
        child: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Available!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600))]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)),
      child: const Row(children: [Icon(Icons.cancel, color: Colors.red), SizedBox(width: 8), Text('Not available', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600))]),
    );
  }

  Widget _buildSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Popular Suggestions', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.take(10).map((s) {
            return GestureDetector(
              onTap: () {
                _idCtrl.text = s;
                setState(() => _available = null);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
                child: Text('@$s', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    final id = _idCtrl.text.trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primary.withValues(alpha: 0.15), Colors.transparent]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('Preview', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, color: Colors.white54, size: 40),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id.isEmpty ? '@your_id' : '@$id',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text('Special ID Holder', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Price', style: TextStyle(color: Colors.white70, fontSize: 16)),
          Row(
            children: [
              const Icon(Icons.diamond, color: Color(0xFFFFB800), size: 20),
              const SizedBox(width: 4),
              Text('$_price diamonds', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton() {
    return FilledButton.icon(
      onPressed: _purchasing || _available != true ? null : _purchase,
      icon: _purchasing ? const SizedBox(width: 18, height: 18, child: Preloader(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.diamond),
      label: const Text('Purchase Special ID', style: TextStyle(fontSize: 16)),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppTheme.primary),
    );
  }

  Widget _buildInfoNote() {
    return Text(
      'Note: Special IDs are unique and cannot be changed once purchased. '
      'Length: $_minLen-$_maxLen characters. '
      'Make sure to check availability before purchasing.',
      style: const TextStyle(color: Colors.white38, fontSize: 12),
      textAlign: TextAlign.center,
    );
  }
}
