# Theme & Design System

This document describes the One By Two app's theme and design system components.

## Overview

The app uses Material 3 theming with custom color extensions for financial states (owe/owed/settled) and sync states. All amounts are displayed in Indian Rupees (₹) with Indian number formatting (1,00,000).

## Theme Configuration

### Colors

**Seed Color:** Teal/Green (`#00897B`) - conveys money/finance

**Custom Color Extensions:**
- `oweColor` - Red shades for amounts user owes
- `owedColor` - Green shades for amounts user is owed  
- `settledColor` - Neutral gray for zero/settled balances
- `syncPendingColor` - Amber for pending sync
- `syncErrorColor` - Red for sync errors
- `categoryColors` - 8 colors for expense categories

Each color has a light variant for backgrounds.

### Typography

Custom text styles for financial app use cases:

- `amountLarge` (32px) - Big amount displays
- `amountMedium` (20px) - List item amounts
- `amountSmall` (14px) - Secondary amounts
- `sectionHeader` (14px) - Section titles
- `cardTitle` (16px) - Card headers
- `bodyDefault` (16px) - Standard body text

All amount text uses tabular figures for aligned columns.

### Theme Usage

```dart
import 'package:one_by_two/core/design_system.dart';

// In MaterialApp
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  // ...
)

// Access custom colors
context.appColors.oweColor
context.appColors.owedColor

// Use typography
Text('Title', style: AppTypography.cardTitle(context))
AmountDisplay(amountInPaise: 10050) // ₹100.50
```

## Widgets

### Loading States

**LoadingIndicator** - Full-screen loading with optional message
```dart
LoadingIndicator(message: 'Loading expenses...')
```

**InlineLoadingIndicator** - Small loading spinner for inline use
```dart
InlineLoadingIndicator(size: 16, strokeWidth: 2)
```

### Error States

**ErrorDisplay** - Full-screen error with retry button
```dart
ErrorDisplay(
  message: 'Failed to load data',
  onRetry: () => retry(),
)
```

**InlineErrorDisplay** - Compact error for cards/lists
```dart
InlineErrorDisplay(
  message: 'Sync failed',
  onRetry: () => sync(),
)
```

### Empty States

**EmptyState** - Full-screen empty state
```dart
EmptyState(
  title: 'No expenses yet',
  subtitle: 'Add your first expense',
  icon: Icons.receipt_outlined,
  actionLabel: 'Add Expense',
  onAction: () => addExpense(),
)
```

**CompactEmptyState** - Inline empty state
```dart
CompactEmptyState(
  message: 'No members yet',
  icon: Icons.people_outline,
)
```

### Amount Display

**AmountDisplay** - Display amounts with proper formatting and colors
```dart
AmountDisplay(
  amountInPaise: 10050, // ₹100.50
  size: AmountDisplaySize.medium,
  colorType: AmountColorType.owed, // green
  showSign: true,
  compact: false,
)
```

**BalanceDisplay** - Automatic color coding for balances
```dart
BalanceDisplay(
  balanceInPaise: 10050, // +₹100.50 in green
  size: AmountDisplaySize.large,
  showSign: true,
)
```

## Utilities

### AmountFormatter

Static utility for formatting money amounts.

**All amounts are in paise (integer). 1 ₹ = 100 paise.**

```dart
// Format with Indian number grouping
AmountFormatter.formatAmount(10050) // ₹100.50
AmountFormatter.formatAmount(10000000) // ₹1,00,000

// Compact format for large amounts
AmountFormatter.formatAmountCompact(10000000) // ₹1L
AmountFormatter.formatAmountCompact(1000000000) // ₹1Cr

// With sign prefix
AmountFormatter.formatAmountWithSign(10050) // +₹100.50
AmountFormatter.formatAmountWithSign(-10050) // -₹100.50

// Parse user input
AmountFormatter.parseAmount('100.50') // 10050
AmountFormatter.parseAmount('₹1,000') // 100000

// Conversion helpers
AmountFormatter.paiseToRupees(10050) // 100.5
AmountFormatter.rupeesToPaise(100.5) // 10050
```

## Money Handling Rules

1. **Never use `double` for money** - always use `int` (paise)
2. **All calculations in paise** - convert to rupees only for display
3. **Indian number format** - 1,00,000 not 100,000
4. **₹ symbol** - always prefix rupee amounts
5. **Precision** - amounts can have up to 2 decimal places (paisa precision)

## Examples

### Display a balance
```dart
// User owes ₹100.50
BalanceDisplay(
  balanceInPaise: -10050,
  size: AmountDisplaySize.large,
) // Shows "-₹100.50" in red

// User is owed ₹250
BalanceDisplay(
  balanceInPaise: 25000,
  size: AmountDisplaySize.medium,
) // Shows "+₹250" in green
```

### Show loading state
```dart
AsyncValue<List<Expense>>.when(
  data: (expenses) => ExpenseList(expenses),
  loading: () => LoadingIndicator(message: 'Loading expenses...'),
  error: (e, _) => ErrorDisplay(
    message: 'Failed to load expenses',
    onRetry: () => ref.refresh(expensesProvider),
  ),
)
```

### Empty state with action
```dart
expenses.isEmpty
  ? EmptyState(
      title: 'No expenses yet',
      subtitle: 'Start tracking your shared expenses',
      icon: Icons.receipt_long_outlined,
      actionLabel: 'Add First Expense',
      onAction: () => context.push('/expenses/add'),
    )
  : ExpenseList(expenses)
```

## Testing

Run tests for the design system:

```bash
flutter test test/core/utils/amount_formatter_test.dart
```

All design system components are tested for:
- Amount formatting (Indian number system)
- Sign handling (positive/negative)
- Compact format (K, L, Cr suffixes)
- Parsing user input
- Conversion helpers

## Accessibility

- All colors meet WCAG AA contrast requirements
- Amount displays use tabular figures for better readability
- Error states include both icon and text
- Loading states provide context with messages
- Touch targets are minimum 48x48 dp
