import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/screen_time.dart';
import 'package:orbit/services/screen_time_provider.dart';

class AddCustomAppSheet extends ConsumerStatefulWidget {
  const AddCustomAppSheet({super.key});

  @override
  ConsumerState<AddCustomAppSheet> createState() => _AddCustomAppSheetState();
}

class _AddCustomAppSheetState extends ConsumerState<AddCustomAppSheet> {
  final _nameController = TextEditingController();
  AppCategory _selectedCategory = AppCategory.social;
  int? _limitMinutes = 60; // 1 hour default
  int _hours = 1;
  int _minutes = 0;
  bool _notifyAt10Min = true;
  bool _notifyAt5Min = true;
  bool _isStrictLock = true;
  bool _showCustomStepper = false;

  final List<int> _presetOptions = [15, 30, 45, 60, 90, 120];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an app name'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final newApp = AppUsageItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      packageName: 'custom.${name.toLowerCase().replaceAll(' ', '_')}',
      category: _selectedCategory,
      timeSpentMinutes: 0,
      limitMinutes: _limitMinutes,
      notifyAt10Min: _notifyAt10Min,
      notifyAt5Min: _notifyAt5Min,
      isStrictLock: _isStrictLock,
    );

    ref.read(screenTimeProvider.notifier).addApp(newApp);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name added to Screen Time tracking'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatMinutes(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  void _updateCustomTime(int hours, int minutes) {
    setState(() {
      _hours = hours.clamp(0, 12);
      _minutes = minutes.clamp(0, 55);
      final total = _hours * 60 + _minutes;
      _limitMinutes = total > 0 ? total : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPresetSelected = _presetOptions.contains(_limitMinutes);

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16171B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Sheet Title
            Text(
              'Add Custom App',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Track usage, set custom timers, and automate closing.',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            // App Name Input
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. Reddit, Duolingo, Spotify',
                labelText: 'App Name',
                prefixIcon: const Icon(IconlyLight.document, size: 20),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category Chips
            Text(
              'CATEGORY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AppCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat.label),
                      selected: isSelected,
                      onSelected: (val) {
                        HapticFeedback.selectionClick();
                        if (val) setState(() => _selectedCategory = cat);
                      },
                      selectedColor: isDark ? Colors.white : const Color(0xFF18181B),
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? (isDark ? const Color(0xFF141517) : Colors.white)
                            : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Daily Limit Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DAILY APP LIMIT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                if (_limitMinutes != null)
                  Text(
                    _formatMinutes(_limitMinutes!),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF18181B),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._presetOptions.map((mins) {
                  final isSelected = _limitMinutes == mins && !_showCustomStepper;
                  return ChoiceChip(
                    label: Text(_formatMinutes(mins)),
                    selected: isSelected,
                    onSelected: (val) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _showCustomStepper = false;
                        _limitMinutes = val ? mins : null;
                        if (val) {
                          _hours = mins ~/ 60;
                          _minutes = mins % 60;
                        }
                      });
                    },
                    selectedColor: isDark ? Colors.white : const Color(0xFF18181B),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? (isDark ? const Color(0xFF141517) : Colors.white)
                          : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
                      ),
                    ),
                    showCheckmark: false,
                  );
                }),
                ChoiceChip(
                  label: const Text('Custom...'),
                  selected: _showCustomStepper || (_limitMinutes != null && !isPresetSelected),
                  onSelected: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _showCustomStepper = true;
                      if (_limitMinutes == null) {
                        _limitMinutes = 60;
                        _hours = 1;
                        _minutes = 0;
                      }
                    });
                  },
                  selectedColor: isDark ? Colors.white : const Color(0xFF18181B),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: (_showCustomStepper || (_limitMinutes != null && !isPresetSelected))
                        ? (isDark ? const Color(0xFF141517) : Colors.white)
                        : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: (_showCustomStepper || (_limitMinutes != null && !isPresetSelected))
                          ? Colors.transparent
                          : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
                    ),
                  ),
                  showCheckmark: false,
                ),
                ChoiceChip(
                  label: const Text('No Limit'),
                  selected: _limitMinutes == null,
                  onSelected: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _showCustomStepper = false;
                      _limitMinutes = null;
                    });
                  },
                  selectedColor: isDark ? Colors.white : const Color(0xFF18181B),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _limitMinutes == null
                        ? (isDark ? const Color(0xFF141517) : Colors.white)
                        : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _limitMinutes == null
                          ? Colors.transparent
                          : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
                    ),
                  ),
                  showCheckmark: false,
                ),
              ],
            ),

            // Custom Hours & Minutes Stepper Box
            if (_showCustomStepper || (_limitMinutes != null && !isPresetSelected)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1D24) : const Color(0xFFF6F6F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E303A) : const Color(0xFFDFDFD8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Hours Control
                    Column(
                      children: [
                        const Text(
                          'Hours',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _hours > 0 ? () => _updateCustomTime(_hours - 1, _minutes) : null,
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                            ),
                            Text(
                              '$_hours',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            IconButton(
                              onPressed: _hours < 12 ? () => _updateCustomTime(_hours + 1, _minutes) : null,
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(width: 1, height: 36, color: isDark ? Colors.white12 : Colors.black12),
                    // Minutes Control
                    Column(
                      children: [
                        const Text(
                          'Minutes',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _minutes >= 5 ? () => _updateCustomTime(_hours, _minutes - 5) : null,
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                            ),
                            Text(
                              '$_minutes',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                            IconButton(
                              onPressed: _minutes <= 50 ? () => _updateCustomTime(_hours, _minutes + 5) : null,
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Warning Alerts
            Text(
              'CLOSING NOTIFICATIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1B20) : const Color(0xFFF7F7F4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notify 10 mins before closing'),
                    subtitle: const Text('Early reminder before time runs out'),
                    value: _notifyAt10Min,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _notifyAt10Min = val);
                    },
                    activeTrackColor: const Color(0xFFFFB800),
                    secondary: const Icon(IconlyLight.notification, size: 20),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                  ),
                  SwitchListTile(
                    title: const Text('Notify 5 mins before closing'),
                    subtitle: const Text('Urgent warning before app locks'),
                    value: _notifyAt5Min,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _notifyAt5Min = val);
                    },
                    activeTrackColor: const Color(0xFFFF5500),
                    secondary: const Icon(IconlyBold.notification, size: 20),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF),
                  ),
                  SwitchListTile(
                    title: const Text('Strict App Lock'),
                    subtitle: const Text('Close and lock app when limit is reached'),
                    value: _isStrictLock,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _isStrictLock = val);
                    },
                    activeTrackColor: const Color(0xFFEF4444),
                    secondary: const Icon(Icons.lock_outline_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : const Color(0xFF18181B),
                  foregroundColor: isDark ? const Color(0xFF141517) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add App Limit',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
