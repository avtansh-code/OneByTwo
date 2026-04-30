# Motion and Interaction Specification -- OneByTwo v1.0

---

## 1. Standard Transitions

All transition timings fall within the 200--300 ms range mandated by SRS section 6.2 ("200--300 ms ease-in-out transitions; spring physics on FAB"). Durations at the lower end of the range are used for dismissals and secondary animations to keep the interface feeling responsive; the upper end is reserved for entrances that benefit from a moment of visual establishment.

| Transition | Duration | Curve | Description |
|---|---|---|---|
| Page push (forward navigation) | 300 ms | `Curves.easeInOut` | New screen slides in from the right edge; outgoing screen slides left and fades to 95% opacity. |
| Page pop (back navigation) | 250 ms | `Curves.easeInOut` | Current screen slides out to the right; previous screen slides in from the left and restores full opacity. |
| Modal bottom sheet appear | 300 ms | `Curves.easeOutCubic` | Sheet slides up from the bottom edge. A scrim fades in simultaneously over the underlying content (opacity 0 to 0.32). |
| Modal bottom sheet dismiss | 250 ms | `Curves.easeInCubic` | Sheet slides down; scrim fades out. Users may also fling-dismiss; if fling velocity exceeds 700 dp/s the sheet dismisses immediately with the remaining distance animated at the fling velocity. |
| Dialog appear | 200 ms | `Curves.easeOut` | Fade in combined with scale from 0.9 to 1.0, anchored at centre. Scrim fades in (opacity 0 to 0.32). |
| Dialog dismiss | 150 ms | `Curves.easeIn` | Fade out; no scale. Scrim fades out in parallel. |
| Tab switch (bottom navigation) | 200 ms | `Curves.easeInOut` | Cross-fade between tab bodies. No horizontal slide -- tabs are peer destinations, not sequential pages (Material 3 guidance). |
| FAB appear (on screen load) | 200 ms | Spring (damping ratio 0.6, stiffness 300) | Scale from 0.0 to 1.0 with spring overshoot, per SRS section 6.2. |
| FAB press | 100 ms down, spring back | `Curves.easeIn` (down), spring (damping 0.6) (up) | Scale to 0.95 on press-down, then spring back to 1.0 on release. |
| List item appear (staggered) | 150 ms per item, 50 ms stagger delay | `Curves.easeOut` | Each item fades in (opacity 0 to 1) and translates up by 16 dp. Maximum of 8 items animated; items beyond the eighth appear instantly to prevent excessive total animation time. |
| Swipe to delete / archive | 300 ms | `Curves.easeOut` | Item slides left to reveal the danger-coloured (`#E76F51`) delete action area. On confirmation, the item collapses vertically over 200 ms with `Curves.easeInOut`. |
| Skeleton shimmer | 1500 ms (loop) | Linear | Gradient sweep from left to right across skeleton placeholder shapes. Loops until real content loads. See section 3 for full specification. |

### 1.1 Shared Hero / Element Transitions

Where an element exists on both the source and destination screens (e.g., a friend avatar on the Friends list transitioning to the Friend detail header), use Flutter's `Hero` widget with a 300 ms `Curves.easeInOut` animation. Limit hero transitions to a single element per navigation event to avoid visual clutter.

---

## 2. Haptic Feedback Rules

Haptic feedback provides non-visual confirmation of meaningful events. Haptics are never used for passive events such as scrolling or content loading.

| Event | Haptic Type | Platform Notes |
|---|---|---|
| Successful settlement recorded | `HapticFeedback.mediumImpact` | Confirms a financially meaningful action. |
| Validation error displayed | `HapticFeedback.lightImpact` | Subtle alert without alarm. Pairs with the inline error message. |
| FAB tap | `HapticFeedback.lightImpact` | Confirms activation of the primary action. |
| Destructive action confirmed (delete expense, leave group) | `HapticFeedback.heavyImpact` | Reinforces the gravity of an irreversible action. |
| OTP digit entered | `HapticFeedback.selectionClick` | Lightweight tick confirming each digit registration. |
| Pull-to-refresh trigger | `HapticFeedback.selectionClick` | Fires once when the pull crosses the activation threshold, not continuously during drag. |
| Swipe-to-delete threshold crossed | `HapticFeedback.selectionClick` | Fires once when the swipe passes the commit threshold. |

### 2.1 Platform Considerations

- On Android, haptic types map to `VibrationEffect` constants. Not all devices support all types; the app shall degrade gracefully (no crash, no fallback vibration pattern).
- On iOS, haptic types map to `UIImpactFeedbackGenerator` styles. All modern iPhones (iPhone 7 and later) support the full range.
- Haptics are not affected by the Reduced Motion accessibility setting (see section 5). Haptics are tactile, not visual.

---

## 3. Loading Patterns

Per SRS section 6.4: "skeleton screens preferred over spinners" with "actionable copy" on error states.

### 3.1 Primary Pattern -- Skeleton Shimmer

Skeleton screens are the default loading indicator for all list and detail screens.

| Property | Value |
|---|---|
| Appearance | Displayed immediately upon navigation, before any data arrives. |
| Shape fidelity | Skeleton placeholder shapes must match the dimensions and layout of the real content (e.g., a balance card skeleton has the same height and corner radius as the populated balance card). |
| Colour (light mode) | Placeholder base: `#E0E0E0`; shimmer highlight: `#F5F5F5`. |
| Colour (dark mode) | Placeholder base: `#2C2C2C`; shimmer highlight: `#3D3D3D`. |
| Shimmer duration | 1500 ms per sweep, linear timing, continuous loop. |
| Shimmer direction | Left to right (reversed for RTL locales in future). |
| Transition to content | Cross-fade from skeleton to real content over 200 ms with `Curves.easeOut`. |

### 3.2 Fallback -- Circular Progress Indicator

Used only where a skeleton is not feasible (e.g., a single-value detail load where no meaningful placeholder shape exists).

| Property | Value |
|---|---|
| Delay before display | 300 ms. If data arrives within 300 ms, no indicator is shown at all. This avoids a distracting flash for fast loads. |
| Style | Material 3 `CircularProgressIndicator` in the primary colour (`#1F4E79` light / `#2E86AB` dark). |
| Size | 24 x 24 dp, centred in the available space. |

### 3.3 Button Loading State

When a button triggers an asynchronous operation (e.g., "Record Settlement", "Add Expense"):

1. Replace the button label text with a small circular progress indicator (16 x 16 dp, primary colour on filled buttons, surface colour on outlined buttons).
2. Disable the button to prevent duplicate submissions.
3. Maintain the button's original dimensions -- no layout shift.
4. Restore the label on completion or error.

### 3.4 Pull-to-Refresh

All primary list screens (Friends list, Groups list, Activity feed, Home dashboard) support pull-to-refresh using the standard Material `RefreshIndicator`. The indicator uses the primary colour (`#1F4E79`).

### 3.5 Inline Progress

For operations that occur within a sheet or form (e.g., saving an expense from the multi-step bottom sheet), display a thin linear progress bar (2 dp height) at the top of the sheet. The bar uses the primary accent colour (`#2E86AB`) and is indeterminate.

---

## 4. OTP Auto-Advance

The OTP verification screen (SRS section 6.3, screen 3) uses six individual input cells.

| Behaviour | Specification |
|---|---|
| Auto-advance on digit entry | When a digit is entered in a cell, focus moves automatically to the next cell. No explicit "Next" tap required. |
| Backspace in empty cell | Focus moves to the previous cell and clears that cell's content, allowing correction. |
| Cell fill animation | 100 ms scale pulse (1.0 to 1.1, then back to 1.0) on the cell that receives a digit, using `Curves.easeOut`. |
| Auto-submit | When all six digits are filled, a 200 ms pause allows the user to visually confirm the code, then verification is triggered automatically. |
| Error state | If verification fails, all cells shake horizontally (3 oscillations over 300 ms, 4 dp amplitude) and clear. Focus returns to the first cell. Accompanied by `HapticFeedback.lightImpact` (see section 2). |
| Paste support | If the user pastes a six-digit string, all cells populate simultaneously, each with the 100 ms scale pulse staggered by 30 ms, then auto-submit fires after the standard 200 ms delay. |

---

## 5. Reduced Motion

Per SRS section 5.6, the app "shall fully support OS-level dynamic font scaling and dark mode." The same principle of respecting system accessibility preferences extends to motion. The app shall query `MediaQuery.disableAnimations` (Flutter's representation of iOS "Reduce Motion" and Android "Remove Animations").

| Aspect | Standard | Reduced Motion Enabled |
|---|---|---|
| Page transitions | Slide, 250--300 ms | Instant cut (duration = 0 ms). |
| Modal / dialog | Slide or fade, 150--300 ms | Instant cut. |
| FAB appear / press | Spring physics, 100--200 ms | Instant state change, no spring. |
| List item stagger | 150 ms fade + slide, 50 ms stagger | All items appear simultaneously and instantly. |
| Skeleton shimmer | 1500 ms sweep loop | Static skeleton (no shimmer animation); placeholder shapes remain visible. |
| Tab cross-fade | 200 ms | Instant swap. |
| OTP cell pulse | 100 ms scale | No pulse. |
| Haptic feedback | Per section 2 | **Unchanged.** Haptics are tactile, not motion-based. |

### 5.1 Implementation Guidance for Flutter Developer

Wrap transition durations in a utility that returns `Duration.zero` when `MediaQuery.of(context).disableAnimations` is true. Spring-based animations should fall back to a simple `Curves.easeOut` with `Duration.zero`. This avoids scattering accessibility checks throughout animation code.

---

## 6. Scroll Behaviour

### 6.1 List Performance

All scrollable lists use `SliverList` (or `SliverList.builder` / `ListView.builder`) for lazy rendering. This is particularly important for the expenses list, which may contain 50 or more items per group (SRS section 4.8, FR-EX series).

### 6.2 Pull-to-Refresh

As specified in section 3.4, all primary list screens support pull-to-refresh.

### 6.3 Scroll Position Preservation

When the user switches between bottom navigation tabs, the scroll position of each tab's list is preserved. Returning to a tab restores the exact scroll offset the user left. Implementation note for the Flutter Developer: use `AutomaticKeepAliveClientMixin` or `PageStorageKey` on each tab's scrollable widget.

### 6.4 FAB Scroll Behaviour

Per FR-HD-04 (SRS section 4.8): "A **persistent** floating action button shall allow adding a new expense from any primary tab." The FAB remains visible at all times regardless of scroll direction. It does not hide on scroll. This is a deliberate product decision -- the "Add Expense" action must always be one tap away (SRS section 5.6: "All primary actions shall be reachable within 2 taps from the Home dashboard").

### 6.5 Over-Scroll

Use the default platform over-scroll behaviour: glow effect on Android, bounce on iOS. Do not override with a custom effect.

---

## 7. Gesture Summary

For reference, the following gestures are used across v1.0 screens. All tap targets meet the minimum sizes specified in SRS section 5.6 (44 x 44 pt iOS, 48 x 48 dp Android).

| Gesture | Where Used | Behaviour |
|---|---|---|
| Tap | Buttons, list items, FAB, tabs, avatars | Standard activation. |
| Long press | Expense list items | Selects item for bulk actions (v1.0: delete only). |
| Swipe left | Expense list items, friend list items | Reveals contextual action (delete, settle). |
| Pull down | All primary list screens | Triggers refresh (section 3.4). |
| Drag down | Bottom sheets | Dismisses the sheet (section 1, modal bottom sheet dismiss). |
| Pinch | Not used in v1.0 | -- |
| Double tap | Not used in v1.0 | -- |

---

## References

- SRS section 5.6 -- Usability and Accessibility.
- SRS section 6.2 -- Visual System (motion tokens).
- SRS section 6.3 -- Core Screens.
- SRS section 6.4 -- Empty, Error, and Loading States.
- SRS section 6.5 -- Microcopy Tone.
- FR-HD-04 -- Persistent FAB requirement.