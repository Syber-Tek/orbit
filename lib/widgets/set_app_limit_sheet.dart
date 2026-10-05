import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconly_plus/iconly_plus.dart';
import 'package:orbit/models/screen_time.dart';
import 'package:orbit/services/screen_time_provider.dart';

class SetAppLimitSheet extends ConsumerStatefulWidget {
  final AppUsageItem app;

  const SetAppLimitSheet({
    super.key,
    required this.app,
  });

  @override
  ConsumerState<SetAppLimitSheet> createState() => _SetAppLimitSheetState();
}

class _SetAppLimitSheetState extends ConsumerState<SetAppLimitSheet> {
  late int? _selectedLimitMinutes;
  late bool _notifyAt10Min;
  late bool _notifyAt5Min;
  late bool _isStrictLock;
  bool _showCustomStepper = false;
  int _customHours = 1;
  int _customMinutes = 0;

  @override
  void initState() {
    super.initState();
    _selectedLimitMinutes = widget.app.limitMinutes;
    _notifyAt10Min = widget.app.notifyAt10Min;
    _notifyAt5Min = widget.app.notifyAt5Min;
    _isStrictLock = widget.app.isStrictLock;

    if (_selectedLimitMinutes != null) {
      _customHours = _selectedLimitMinutes! ~/ 60;
      _customMinutes = _selectedLimitMinutes! % 60;
    }
  }

  void _save() {
    HapticFeedback.mediumImpact();
    ref.read(screenTimeProvider.notifier).setAppLimit(
          widget.app.id,
          _selectedLimitMinutes,
          notifyAt10Min: _notifyAt10Min,
          notifyAt5Min: _notifyAt5Min,
          isStrictLock: _isStrictLock,
        );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedLimitMinutes != null
              ? 'Limit set to ${_formatMinutes(_selectedLimitMinutes!)} for ${widget.app.name}'
              : 'Limit removed for ${widget.app.name}',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteApp() {
    HapticFeedback.heavyImpact();
    ref.read(screenTimeProvider.notifier).deleteApp(widget.app.id);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.app.name} removed from tracking'),
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
      _customHours = hours.clamp(0, 12);
      _customMinutes = minutes.clamp(0, 55);
      final total = _customHours * 60 + _customMinutes;
      _selectedLimitMinutes = total > 0 ? total : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final presetMinutes = [15, 30, 45, 60, 90, 120];
    final isPresetSelected = presetMinutes.contains(_selectedLimitMinutes);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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

            // Header: App Icon & Name
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.apps_rounded,
                      color: isDark ? Colors.white : const Color(0xFF18181B),
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.app.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Used ${widget.app.formattedTimeSpent} today',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _deleteApp,
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                  tooltip: 'Remove App',
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Daily App Limit Section
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
                if (_selectedLimitMinutes != null)
                  Text(
                    _formatMinutes(_selectedLimitMinutes!),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF18181B),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Presets and Custom Chip
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...presetMinutes.map((mins) {
                  final isSelected = _selectedLimitMinutes == mins && !_showCustomStepper;
                  return ChoiceChip(
                    label: Text(_formatMinutes(mins)),
                    selected: isSelected,
                    onSelected: (val) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _showCustomStepper = false;
                        _selectedLimitMinutes = val ? mins : null;
                        if (val) {
                          _customHours = mins ~/ 60;
                          _customMinutes = mins % 60;
                        }
                      });
                    },
                    selectedColor: isDark ? Colors.white : const Color(0xFF18181B),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? (isDark ? const Color(0xFF141517) : Colors.white)
                          : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                  selected: _showCustomStepper || (_selectedLimitMinutes != null && !isPresetSelected),
                  onSelected: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _showCustomStepper = true;
                      if (_selectedLimitMinutes == null) {
                        _selectedLimitMinutes = 60;
                        _customHours = 1;
                        _customMinutes = 0;
                      }
                    });
                  },
                  selectedColor: isDark ? Colors.white : const Color(0xFF18181B),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: (_showCustomStepper || (_selectedLimitMinutes != null && !isPresetSelected))
                        ? (isDark ? const Color(0xFF141517) : Colors.white)
                        : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: (_showCustomStepper || (_selectedLimitMinutes != null && !isPresetSelected))
                          ? Colors.transparent
                          : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
                    ),
                  ),
                  showCheckmark: false,
                ),
                ChoiceChip(
                  label: const Text('No Limit'),
                  selected: _selectedLimitMinutes == null,
                  onSelected: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _showCustomStepper = false;
                      _selectedLimitMinutes = null;
                    });
                  },
                  selectedColor: isDark ? Colors.white : const Color(0xFF18181B),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _selectedLimitMinutes == null
                        ? (isDark ? const Color(0xFF141517) : Colors.white)
                        : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: _selectedLimitMinutes == null
                          ? Colors.transparent
                          : (isDark ? const Color(0xFF272830) : const Color(0xFFE5E5DF)),
                    ),
                  ),
                  showCheckmark: false,
                ),
              ],
            ),

            // Custom Hours & Minutes Stepper Box
            if (_showCustomStepper || (_selectedLimitMinutes != null && !isPresetSelected)) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _customHours > 0
                                  ? () => _updateCustomTime(_customHours - 1, _customMinutes)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 24),
                            ),
                            Text(
                              '$_customHours',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            IconButton(
                              onPressed: _customHours < 12
                                  ? () => _updateCustomTime(_customHours + 1, _customMinutes)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(width: 1, height: 40, color: isDark ? Colors.white12 : Colors.black12),
                    // Minutes Control
                    Column(
                      children: [
                        const Text(
                          'Minutes',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _customMinutes >= 5
                                  ? () => _updateCustomTime(_customHours, _customMinutes - 5)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 24),
                            ),
                            Text(
                              '$_customMinutes',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            IconButton(
                              onPressed: _customMinutes <= 50
                                  ? () => _updateCustomTime(_customHours, _customMinutes + 5)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 24),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Notification & Restriction Rules
            Text(
              'CLOSING & WARNING ALERTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),

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
                    subtitle: const Text('Sends a reminder alert before the limit is reached'),
                    value: _notifyAt10Min,
                    onChanged: _selectedLimitMinutes == null
                        ? null
                        : (val) {
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
                    subtitle: const Text('Final warning alert before app locks'),
                    value: _notifyAt5Min,
                    onChanged: _selectedLimitMinutes == null
                        ? null
                        : (val) {
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
                    subtitle: const Text('Closes app and prevents opening when limit is up'),
                    value: _isStrictLock,
                    onChanged: _selectedLimitMinutes == null
                        ? null
                        : (val) {
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

            // Save Button
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
                  'Save Settings',
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
