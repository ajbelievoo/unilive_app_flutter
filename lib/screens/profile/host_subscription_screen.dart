import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../constants/const.dart';
import '../../models/subscription_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/log.dart';
import '../../utils/media_utils.dart';
import 'package:belive/widgets/preloader.dart';

const String _tag = 'HostSubscription';

class HostSubscriptionScreen extends StatefulWidget {
  const HostSubscriptionScreen({super.key});

  @override
  State<HostSubscriptionScreen> createState() => _HostSubscriptionScreenState();
}

class _HostSubscriptionScreenState extends State<HostSubscriptionScreen> {
  final List<SubscriptionTier> _tiers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTiers());
  }

  Future<void> _loadTiers() async {
    try {
      final session = context.read<SessionManager>();
      final res = await ApiService.getHostSubscriptionTiers(
        hostUserId: session.userId,
      );
      if (mounted) setState(() => _tiers..addAll(res.tiers));
    } catch (e, s) {
      Log.e(_tag, 'loadTiers failed', e, s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTier(SubscriptionTier tier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tier'),
        content: Text('Delete "${tier.name}"? Existing subscribers will keep access until expiry.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final res = await ApiService.deleteSubscriptionTier(tierId: tier.id ?? '');
      if (res.status) {
        Fluttertoast.showToast(msg: 'Tier deleted');
        setState(() => _tiers.removeWhere((t) => t.id == tier.id));
      } else {
        Fluttertoast.showToast(msg: res.message ?? 'Failed to delete');
      }
    } catch (e, s) {
      Log.e(_tag, 'deleteTier failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to delete tier');
    }
  }

  void _openCreateEditSheet({SubscriptionTier? edit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateTierSheet(
        existingTier: edit,
        onSaved: () {
          Navigator.pop(ctx);
          setState(() {
            _loading = true;
            _tiers.clear();
          });
          _loadTiers();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Subscriptions'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_tiers.length < 5)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _openCreateEditSheet(),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: Preloader(color: AppTheme.primary))
          : _tiers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tiers.length,
                  itemBuilder: (_, i) => _TierCard(
                    tier: _tiers[i],
                    onEdit: () => _openCreateEditSheet(edit: _tiers[i]),
                    onDelete: () => _deleteTier(_tiers[i]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.subscriptions_outlined, size: 64, color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text(
              'No Subscription Tiers Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create subscription tiers so your fans can subscribe with diamonds and unlock exclusive content.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openCreateEditSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Create Tier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Tier card ----------------------------------------------------------------
class _TierCard extends StatelessWidget {
  final SubscriptionTier tier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TierCard({required this.tier, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tier.name ?? 'Tier',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${tier.price} ${Const.coinName}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (tier.description?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(tier.description!, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${tier.durationDays} days', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 16),
                const Icon(Icons.photo_library, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${tier.images.length} photos', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            if (tier.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tier.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: VideoUtil.getFullImageUrl(tier.images[i]),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Create / Edit tier sheet -------------------------------------------------
class _CreateTierSheet extends StatefulWidget {
  final SubscriptionTier? existingTier;
  final VoidCallback onSaved;

  const _CreateTierSheet({this.existingTier, required this.onSaved});

  @override
  State<_CreateTierSheet> createState() => _CreateTierSheetState();
}

class _CreateTierSheetState extends State<_CreateTierSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final List<String> _images = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingTier != null) {
      final t = widget.existingTier!;
      _nameCtrl.text = t.name ?? '';
      _descCtrl.text = t.description ?? '';
      _priceCtrl.text = t.price.toString();
      _durationCtrl.text = t.durationDays.toString();
      _images.addAll(t.images);
    } else {
      _durationCtrl.text = '30';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;

    if (name.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter a tier name');
      return;
    }
    if (price < 1) {
      Fluttertoast.showToast(msg: 'Price must be at least 1 diamond');
      return;
    }
    if (duration < 1) {
      Fluttertoast.showToast(msg: 'Duration must be at least 1 day');
      return;
    }

    setState(() => _saving = true);
    try {
      final session = context.read<SessionManager>();
      if (widget.existingTier != null) {
        final res = await ApiService.updateSubscriptionTier(
          tierId: widget.existingTier!.id ?? '',
          name: name,
          description: _descCtrl.text.trim(),
          price: price,
          durationDays: duration,
          images: _images,
        );
        if (res.status) {
          Fluttertoast.showToast(msg: 'Tier updated');
          widget.onSaved();
        } else {
          Fluttertoast.showToast(msg: res.message ?? 'Failed');
        }
      } else {
        final res = await ApiService.createSubscriptionTier(
          hostUserId: session.userId,
          name: name,
          description: _descCtrl.text.trim(),
          price: price,
          durationDays: duration,
          images: _images,
        );
        if (res.status) {
          Fluttertoast.showToast(msg: 'Tier created');
          widget.onSaved();
        } else {
          Fluttertoast.showToast(msg: res.message ?? 'Failed');
        }
      }
    } catch (e, s) {
      Log.e(_tag, 'save tier failed', e, s);
      Fluttertoast.showToast(msg: 'Failed to save');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingTier != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetHeader(isEdit ? 'Edit Tier' : 'Create Tier'),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Tier Name'),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Premium, VIP, Basic',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Description'),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'What subscribers get...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Price (${Const.coinName})'),
                              TextField(
                                controller: _priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '500',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.diamond_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Duration (days)'),
                              TextField(
                                controller: _durationCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '30',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.access_time),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _label('Exclusive Photos (optional)'),
                    const SizedBox(height: 4),
                    Text(
                      'Add image URLs for exclusive content that subscribers will see.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    if (_images.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_images.length, (i) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: VideoUtil.getFullImageUrl(_images[i]),
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    width: 72,
                                    height: 72,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image, color: Colors.grey),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => setState(() => _images.removeAt(i)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _addImageUrl,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Image URL'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: Preloader(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(isEdit ? 'Update Tier' : 'Create Tier'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetHeader(String title) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }

  void _addImageUrl() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Image URL'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) setState(() => _images.add(url));
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
