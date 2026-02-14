import 'package:intl/intl.dart';

/// Utility class for formatting monetary amounts.
/// 
/// All amounts are stored as integers in paise (1 ₹ = 100 paise).
/// This class provides methods to convert and format amounts for display
/// using Indian number grouping (1,00,000).
class AmountFormatter {
  AmountFormatter._();

  /// Formatter for Indian number system (lakhs and crores)
  /// Pattern: ##,##,###.## (e.g., 1,00,000.00)
  static final NumberFormat _indianFormat = NumberFormat(
    '##,##,###.##',
    'en_IN',
  );

  /// Formats an amount from paise to rupees with Indian number grouping.
  /// 
  /// Examples:
  /// - 0 → "₹0"
  /// - 10050 → "₹100.50"
  /// - 100000 → "₹1,000"
  /// - 10000000 → "₹1,00,000"
  /// 
  /// [paise] The amount in paise (integer).
  /// [showDecimals] Whether to show decimal places. Default is true.
  /// If false, rounds to nearest rupee.
  static String formatAmount(int paise, {bool showDecimals = true}) {
    final rupees = paise / 100.0;
    
    if (!showDecimals) {
      return '₹${_indianFormat.format(rupees.round())}';
    }
    
    // If the decimal part is 0, don't show it
    if (paise % 100 == 0) {
      return '₹${_indianFormat.format(rupees.round())}';
    }
    
    return '₹${_indianFormat.format(rupees)}';
  }

  /// Formats an amount in compact form for large amounts.
  /// 
  /// Examples:
  /// - 120000 (₹1,200) → "₹1.2K"
  /// - 10000000 (₹1,00,000) → "₹1L"
  /// - 10000000000 (₹1,00,00,000) → "₹1Cr"
  /// 
  /// [paise] The amount in paise (integer).
  static String formatAmountCompact(int paise) {
    final rupees = paise / 100.0;
    
    // For amounts less than 1000, show full amount
    if (rupees < 1000) {
      return formatAmount(paise);
    }
    
    // For Indian system, use custom logic
    if (rupees >= 10000000) {
      // Crores (1 Cr = 1,00,00,000)
      final crores = rupees / 10000000;
      return '₹${_formatDecimal(crores)}Cr';
    } else if (rupees >= 100000) {
      // Lakhs (1 L = 1,00,000)
      final lakhs = rupees / 100000;
      return '₹${_formatDecimal(lakhs)}L';
    } else {
      // Thousands
      final thousands = rupees / 1000;
      return '₹${_formatDecimal(thousands)}K';
    }
  }

  /// Formats a decimal number with appropriate precision.
  /// Shows 1 decimal place if needed, otherwise rounds.
  static String _formatDecimal(double value) {
    if (value >= 10) {
      return value.round().toString();
    } else if (value % 1 == 0) {
      return value.toInt().toString();
    } else {
      return value.toStringAsFixed(1);
    }
  }

  /// Parses a rupee amount string and converts to paise.
  /// 
  /// Examples:
  /// - "100" → 10000
  /// - "100.50" → 10050
  /// - "1,000" → 100000
  /// 
  /// [amountStr] The amount string (without ₹ symbol).
  /// Returns null if parsing fails.
  static int? parseAmount(String amountStr) {
    try {
      // Remove commas and whitespace
      final cleanStr = amountStr.replaceAll(RegExp(r'[,\s₹]'), '');
      final rupees = double.parse(cleanStr);
      return (rupees * 100).round();
    } catch (e) {
      return null;
    }
  }

  /// Formats amount with sign prefix (+ or -) for balance displays.
  /// 
  /// Examples:
  /// - 10050 → "+₹100.50" (positive - user is owed)
  /// - -10050 → "-₹100.50" (negative - user owes)
  /// - 0 → "₹0" (settled)
  static String formatAmountWithSign(int paise, {bool showDecimals = true}) {
    if (paise == 0) {
      return formatAmount(0, showDecimals: showDecimals);
    }
    
    final sign = paise > 0 ? '+' : '-';
    final absAmount = formatAmount(paise.abs(), showDecimals: showDecimals);
    
    // Remove ₹ and add sign before it
    return '$sign$absAmount';
  }

  /// Formats amount for input fields (without ₹ symbol).
  /// 
  /// Examples:
  /// - 10050 → "100.50"
  /// - 100000 → "1,000"
  static String formatAmountForInput(int paise) {
    final rupees = paise / 100.0;
    return _indianFormat.format(rupees);
  }

  /// Converts paise to rupees as double (for calculations if needed).
  /// 
  /// WARNING: Only use this for display or intermediate calculations.
  /// Never store monetary values as doubles!
  static double paiseToRupees(int paise) {
    return paise / 100.0;
  }

  /// Converts rupees to paise as int.
  static int rupeesToPaise(double rupees) {
    return (rupees * 100).round();
  }
}
