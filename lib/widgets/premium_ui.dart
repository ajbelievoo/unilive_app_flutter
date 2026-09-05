/// Phase 9: Premium reusable UI components â€” Bigo Live style.
///
/// These widgets provide the premium look across the entire app:
/// - GradientCard: card with gradient background + shadow
/// - PremiumAppBar: transparent app bar with gradient
/// - StatChip: small stat badge
/// - GradientButton: gradient-filled button
/// - PremiumBottomNav: bottom nav with center FAB
/// - SectionHeader: section title with optional action
/// - EmptyState: premium empty state illustration
/// - LoadingIndicator: gradient loading spinner
library premium_ui;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:belive/widgets/preloader.dart';

/// Card with gradient background and soft shadow.
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    this.gradient = AppTheme.primaryGradient,
    this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.shadow,
  });

  final Gradient gradient;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow ?? AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}

/// Glassmorphism card â€” frosted glass effect.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.color,
  });

  final Widget? child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }
}

/// Gradient-filled button.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient = AppTheme.primaryGradient,
    this.icon,
    this.width = double.infinity,
    this.height = 48,
    this.borderRadius = 24,
    this.loading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final Gradient gradient;
  final IconData? icon;
  final double width;
  final double height;
  final double borderRadius;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: loading ? null : gradient,
        color: loading ? Colors.grey.shade400 : null,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: loading ? null : AppTheme.primaryShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Preloader(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Small stat chip â€” shows label + value.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppTheme.primary,
    this.gradient,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? color.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: gradient == null ? color : Colors.white),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: gradient == null ? color : Colors.white70)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: gradient == null ? color : Colors.white)),
        ]),
      ]),
    );
  }
}

/// Section header with optional action button.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

/// Premium empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.purpleGradient,
                shape: BoxShape.circle,
                boxShadow: AppTheme.primaryShadow,
              ),
              child: Icon(icon, size: 36, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              GradientButton(label: actionLabel!, onPressed: onAction!, width: 200, height: 44),
            ],
          ],
        ),
      ),
    );
  }
}

/// Premium loading indicator with gradient.
class PremiumLoading extends StatelessWidget {
  const PremiumLoading({super.key, this.size = 40, this.strokeWidth = 3});

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Preloader(
        strokeWidth: strokeWidth,
        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
      ),
    );
  }
}

/// Premium badge â€” small rounded badge with gradient.
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({
    super.key,
    required this.text,
    this.gradient = AppTheme.goldGradient,
    this.icon,
    this.fontSize = 11,
  });

  final String text;
  final Gradient gradient;
  final IconData? icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: fontSize + 2, color: Colors.white),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w700),
        ),
      ]),
    );
  }
}

/// Premium list tile with gradient leading icon.
class PremiumTile extends StatelessWidget {
  const PremiumTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.gradient = AppTheme.purpleGradient,
    this.trailing,
    this.isDanger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Gradient gradient;
  final Widget? trailing;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: isDanger ? null : gradient,
          color: isDanger ? Colors.red.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isDanger ? Colors.red : Colors.white, size: 22),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDanger ? Colors.red : null)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}

/// Special entry effect for Top Family members.
class FamilyEntryEffect extends StatefulWidget {
  const FamilyEntryEffect({super.key, required this.name, required this.familyName, this.familyImage, required this.onFinished});
  final String name;
  final String familyName;
  final String? familyImage;
  final VoidCallback onFinished;

  @override
  State<FamilyEntryEffect> createState() => _FamilyEntryEffectState();
}

class _FamilyEntryEffectState extends State<FamilyEntryEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  late final Animation<double> _slide = Tween<double>(begin: -350, end: 16).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _ctrl.forward().then((_) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _ctrl.reverse().then((_) => widget.onFinished());
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slide,
      builder: (ctx, child) => Positioned(
        top: MediaQuery.of(context).padding.top + 80,
        left: _slide.value,
        child: Container(
          width: 280,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3F1682), Color(0xFF1A0B6E)]),
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: Colors.amber.withOpacity(0.6), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Container(
                width: 46, height: 46,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.amber),
                padding: const EdgeInsets.all(1.5),
                child: ClipOval(child: widget.familyImage != null ? Image.network(widget.familyImage!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.white)) : const Icon(Icons.shield, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, overflow: TextOverflow.ellipsis)),
                    Text('Family: ${widget.familyName}', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.workspace_premium, color: Colors.amber, size: 24),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

