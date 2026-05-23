import 'package:dose_vault/core/constants/app_colors.dart';
import 'package:dose_vault/core/widgets/custom_elevated_button.dart';
import 'package:dose_vault/core/widgets/top_toast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dose_vault/features/widgets/battery_exemption_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dose_vault/core/models/medication.dart';
import 'package:dose_vault/core/providers/medication_provider.dart';
import 'package:dose_vault/core/services/hive_service.dart';
import 'package:dose_vault/core/widgets/custom_text.dart';
import 'package:dose_vault/core/widgets/custom_text_field.dart';
import 'package:dose_vault/core/services/notification_service.dart';

class AddMedicationScreen extends ConsumerStatefulWidget {
  final Medication? medication;
  const AddMedicationScreen({this.medication, super.key});

  @override
  ConsumerState<AddMedicationScreen> createState() =>
      _AddMedicationScreenState();
}

class _AddMedicationScreenState extends ConsumerState<AddMedicationScreen> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController(text: '0');
  final _instructionsController = TextEditingController();

  String _selectedUnit = 'mg';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.medication != null) {
      final med = widget.medication!;
      _nameController.text = med.name;
      // Format double to string without trailing decimal if it's a whole number
      _dosageController.text = med.dosage % 1 == 0
          ? med.dosage.toInt().toString()
          : med.dosage.toString();
      _instructionsController.text = med.instructions ?? '';
      _selectedUnit = med.unit;

      final parts = med.scheduledTime.split(':');
      if (parts.length == 2) {
        _selectedTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    TimeOfDay tempTime = _selectedTime;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 280,
        padding: const EdgeInsets.only(top: 6),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // ── Done / Cancel bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const CustomText('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const CustomText(
                      'Done',
                      fontWeight: FontWeight.w600,
                    ),
                    onPressed: () {
                      setState(() => _selectedTime = tempTime);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            // ── Cupertino Timer Picker ──
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(
                  2026,
                  1,
                  1,
                  _selectedTime.hour,
                  _selectedTime.minute,
                ),
                onDateTimeChanged: (DateTime dt) {
                  tempTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      TopToast.show(context, 'Please enter a medication name');
      return;
    }

    // Intercept for Android battery optimization permission
    if (Theme.of(context).platform == TargetPlatform.android) {
      final isGranted = await Permission.ignoreBatteryOptimizations.isGranted;
      if (!isGranted) {
        if (!mounted) return;
        
        FocusScope.of(context).unfocus(); // Dismiss keyboard
        
        BatteryExemptionBottomSheet.show(
          context,
          onEnable: () {
            if (mounted) _executeSave();
          },
          onCancel: () {
            if (mounted) _executeSave();
          },
        );
        return;
      }
    }

    _executeSave();
  }

  Future<void> _executeSave() async {
    final name = _nameController.text.trim();
    final dosage = double.tryParse(_dosageController.text.trim()) ?? 0;

    setState(() => _saving = true);

    try {
      final timeStr =
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

      final isEditing = widget.medication != null;

      final med = Medication(
        id: isEditing ? widget.medication!.id : HiveService.generateId(),
        name: name,
        dosage: dosage,
        unit: _selectedUnit,
        scheduledTime: timeStr,
        instructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        createdAt: isEditing ? widget.medication!.createdAt : DateTime.now(),
      );

      if (isEditing) {
        await ref.read(medicationListProvider.notifier).updateMedication(med);
        await ref.read(notificationServiceProvider).cancelReminder(med.id);
        await ref.read(notificationServiceProvider).scheduleDoseReminder(med);
      } else {
        await ref.read(medicationListProvider.notifier).addMedication(med);
        await ref.read(notificationServiceProvider).scheduleDoseReminder(med);
      }

      if (mounted) {
        TopToast.show(
          context,
          isEditing
              ? 'Medication updated successfully'
              : 'Medication added successfully',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        TopToast.showError(context, 'Error saving: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _selectedTime.format(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              size: 20,
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: CustomText(
            widget.medication != null ? 'Edit Medication' : 'New Medication',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),

          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.divider),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Medication Name ──
                    _label('MEDICATION NAME'),
                    const SizedBox(height: 8),
                    CustomTextField(
                      autofocus: true,
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      hintText: 'e.g., Amoxicillin',
                    ),

                    const SizedBox(height: 24),

                    // ── Dosage ──
                    _label('DOSAGE'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: CustomTextField(
                            controller: _dosageController,
                            keyboardType: TextInputType.number,
                            hintText: '0',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.scaffoldBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [_unitTab('mg'), _unitTab('ml')],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Scheduled Time ──
                    _label('SCHEDULED TIME'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickTime,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CustomText(
                              timeStr,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            const Icon(
                              Icons.access_time,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Instructions ──
                    _label('INSTRUCTIONS (OPTIONAL)'),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _instructionsController,
                      maxLines: 4,
                      hintText: 'e.g., Take with food',
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: CustomElevatedButton(
                label: 'Save Medication',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return CustomText(
      text,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 1.2,
    );
  }

  Widget _unitTab(String unit) {
    final selected = _selectedUnit == unit;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedUnit = unit),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: CustomText(
              unit,
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
