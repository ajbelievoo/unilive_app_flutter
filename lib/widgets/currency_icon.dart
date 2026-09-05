import 'package:flutter/material.dart';
import 'package:belive/constants/const.dart';

/// Currency types shown in the UI.
///
/// Backend keys are unchanged (`coin`, `diamond`, `rCoin`); only the
/// user-facing names + icons are swapped:
///   - [diamond]  -> purchasable currency (backend `coin`) shown as "Diamonds"
///   - [bean]     -> host earning currency (backend `rCoin`) shown as "Beans"
enum CurrencyType { diamond, bean }

/// A small inline icon for a currency. Use next to balances / prices.
///
/// ```dart
/// Row(children: [
///   const CurrencyIcon(CurrencyType.diamond, size: 16),
///   Text('$balance'),
/// ])
/// ```
class CurrencyIcon extends StatelessWidget {
  const CurrencyIcon(this.type, {super.key, this.size = 16});

  final CurrencyType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = type == CurrencyType.diamond
        ? Const.diamondIconAsset
        : Const.beanIconAsset;
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        type == CurrencyType.diamond ? Icons.diamond : Icons.grain,
        size: size,
        color: type == CurrencyType.diamond
            ? const Color(0xFF00E5FF)
            : const Color(0xFF8D6E63),
      ),
    );
  }
}
