import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../booking/domain/entities/business.dart';
import '../../../booking/presentation/widgets/business_image.dart';
import '../providers/business_admin_providers.dart';

/// The tab strip scrolls horizontally on narrow screens; this gives tests a
/// stable handle for bringing off-screen tabs into view.
const businessSettingsTabsKey = ValueKey<String>('business-settings-tabs');

/// Business settings, mirroring the web dashboard: general info, operating
/// hours, holidays and booking-page appearance.
class BusinessSettingsView extends ConsumerStatefulWidget {
  const BusinessSettingsView({super.key});

  @override
  ConsumerState<BusinessSettingsView> createState() =>
      _BusinessSettingsViewState();
}

final _settingsTabProvider = StateProvider.autoDispose<int>((_) => 0);

class _BusinessSettingsViewState extends ConsumerState<BusinessSettingsView> {
  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeBusinessProvider);
    final tab = ref.watch(_settingsTabProvider);
    if (business == null) {
      return const AppEmptyState(message: AppStrings.noOwnedBusiness);
    }

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
      children: [
        _SettingsHeader(business: business),
        const SizedBox(height: AppDimensions.spacingXl),
        _SettingsTabBar(
          selectedIndex: tab,
          onSelected: (index) => ref.read(_settingsTabProvider.notifier).state = index,
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        switch (tab) {
          1 => _OperatingHoursTab(key: ValueKey(business.id), business: business),
          2 => const _HolidaysTab(),
          3 => _BookingPageTab(
              key: ValueKey('theme-${business.id}'),
              business: business,
            ),
          _ => _GeneralInfoTab(
              key: ValueKey('general-${business.id}'),
              business: business,
            ),
        },
      ],
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BusinessLogo(
          logoUrl: business.logoUrl,
          fallbackText: business.name,
          size: 46,
        ),
        const SizedBox(width: AppDimensions.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.businessSettings,
                style: textTheme.headlineSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                AppStrings.manageBusinessSettings,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTabBar extends StatelessWidget {
  const _SettingsTabBar({
    required this.selectedIndex,
    required this.onSelected,
  });


  static const _labels = [
    AppStrings.generalInfo,
    AppStrings.operatingHours,
    AppStrings.holidaysClosures,
    AppStrings.bookingPage,
  ];

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      height: AppDimensions.categoryFilterHeight,
      child: ListView.separated(
        key: businessSettingsTabsKey,
        scrollDirection: Axis.horizontal,
        itemCount: _labels.length,
        separatorBuilder: (_, _) => const SizedBox(
          width: AppDimensions.spacingSm,
        ),
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;

          return Material(
            color: isSelected ? colors.primary : colors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingLg,
                ),
                child: Center(
                  child: Text(
                    _labels[index],
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isSelected
                              ? colors.textOnPrimary
                              : colors.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// General info
// ---------------------------------------------------------------------------

const _generalInfoCurrencies = ['PKR', 'USD', 'EUR', 'GBP', 'AED', 'SAR'];
const _cancellationUnits = ['HOURS', 'DAYS'];

final _isSavingDetailsProvider = StateProvider.autoDispose<bool>((_) => false);
final _isSavingPolicyProvider = StateProvider.autoDispose<bool>((_) => false);
final _logoProvider = StateProvider.autoDispose<XFile?>((_) => null);
final _coverProvider = StateProvider.autoDispose<XFile?>((_) => null);

// Keyed by the `Business` itself (it's `Equatable`, so this is a stable,
// cheap family key) so each provider computes its own business-specific
// starting value directly, rather than a widget mutating it in `initState` —
// Riverpod forbids writing to a provider during any widget lifecycle method.
final _currencyProvider = StateProvider.autoDispose.family<String, Business>(
  (ref, business) {
    final currency = business.settings.currency;
    // Normalised up front: DropdownButtonFormField asserts when its value is
    // absent from the item list, so a stray 'pkr' would crash the tab.
    return currency.isEmpty ? _generalInfoCurrencies.first : currency.toUpperCase();
  },
);
final _allowCancellationsProvider =
    StateProvider.autoDispose.family<bool, Business>(
  (ref, business) => business.settings.cancellationPolicy.isAllowed,
);
final _cancellationUnitProvider =
    StateProvider.autoDispose.family<String, Business>(
  (ref, business) {
    final unit = business.settings.cancellationPolicy.windowUnit.toUpperCase();
    return _cancellationUnits.contains(unit) ? unit : 'HOURS';
  },
);

class _GeneralInfoTab extends ConsumerStatefulWidget {
  const _GeneralInfoTab({required this.business, super.key});

  final Business business;

  @override
  ConsumerState<_GeneralInfoTab> createState() => _GeneralInfoTabState();
}

class _GeneralInfoTabState extends ConsumerState<_GeneralInfoTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _cancellationWindow;

  @override
  void initState() {
    super.initState();
    final business = widget.business;
    final policy = business.settings.cancellationPolicy;

    _name = TextEditingController(text: business.name);
    _slug = TextEditingController(text: business.slug);
    _city = TextEditingController(text: business.city);
    _address = TextEditingController(text: business.address);
    _cancellationWindow = TextEditingController(
      text: policy.windowValue == 0 ? '24' : policy.windowValue.toString(),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _city.dispose();
    _address.dispose();
    _cancellationWindow.dispose();
    super.dispose();
  }

  List<String> _currencyOptions(String current) {
    if (_generalInfoCurrencies.contains(current)) {
      return _generalInfoCurrencies;
    }
    return [current, ..._generalInfoCurrencies];
  }

  Future<void> _pickImage({required bool isLogo}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) {
      return;
    }

    ref.read((isLogo ? _logoProvider : _coverProvider).notifier).state = picked;
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final currency = ref.read(_currencyProvider(widget.business));
    final logo = ref.read(_logoProvider);
    final cover = ref.read(_coverProvider);

    ref.read(_isSavingDetailsProvider.notifier).state = true;
    // Currency lives inside `settings`, which the API replaces wholesale — so
    // send the existing settings with only the currency swapped.
    final error = await ref.read(businessAdminActionControllerProvider).saveBusinessDetails(
          name: _name.text.trim(),
          slug: _slug.text.trim(),
          city: _city.text.trim(),
          address: _address.text.trim(),
          settings: widget.business.settings.copyWith(currency: currency),
          logoPath: logo?.path,
          coverPath: cover?.path,
        );

    if (!mounted) {
      return;
    }
    ref.read(_isSavingDetailsProvider.notifier).state = false;
    if (error == null) {
      ref.read(_logoProvider.notifier).state = null;
      ref.read(_coverProvider.notifier).state = null;
    }
    _showResult(error, 'Business details saved.');
  }

  Future<void> _savePolicy() async {
    final allowCancellations = ref.read(_allowCancellationsProvider(widget.business));
    final window = int.tryParse(_cancellationWindow.text.trim());
    if (allowCancellations && (window == null || window <= 0)) {
      _showResult('Enter a cancellation window of at least 1.', '');
      return;
    }

    ref.read(_isSavingPolicyProvider.notifier).state = true;
    final settings = widget.business.settings;
    final error = await ref.read(businessAdminActionControllerProvider).saveBusinessDetails(
          name: _name.text.trim(),
          slug: _slug.text.trim(),
          city: _city.text.trim(),
          address: _address.text.trim(),
          settings: settings.copyWith(
            currency: ref.read(_currencyProvider(widget.business)),
            cancellationPolicy: settings.cancellationPolicy.copyWith(
              isAllowed: allowCancellations,
              windowValue: window ?? settings.cancellationPolicy.windowValue,
              windowUnit: ref.read(_cancellationUnitProvider(widget.business)),
            ),
          ),
        );

    if (!mounted) {
      return;
    }
    ref.read(_isSavingPolicyProvider.notifier).state = false;
    _showResult(error, 'Cancellation policy saved.');
  }

  void _showResult(String? error, String successMessage) {
    showSettingsMessage(
      context,
      message: error ?? successMessage,
      isError: error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;
    final currency = ref.watch(_currencyProvider(widget.business));
    final allowCancellations = ref.watch(_allowCancellationsProvider(widget.business));
    final cancellationUnit = ref.watch(_cancellationUnitProvider(widget.business));
    final logo = ref.watch(_logoProvider);
    final cover = ref.watch(_coverProvider);
    final isSavingDetails = ref.watch(_isSavingDetailsProvider);
    final isSavingPolicy = ref.watch(_isSavingPolicyProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsPanel(
            title: 'General Information',
            subtitle: 'Update your core business details.',
            children: [
              _ImagePickerField(
                label: 'Business Avatar / Logo',
                picked: logo,
                onPick: () => _pickImage(isLogo: true),
                preview: BusinessLogo(
                  logoUrl: business.logoUrl,
                  fallbackText: business.name,
                  size: 56,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              _ImagePickerField(
                label: 'Cover Image',
                picked: cover,
                onPick: () => _pickImage(isLogo: false),
                preview: SizedBox(
                  height: 56,
                  width: 96,
                  child: BusinessCoverImage(
                    coverUrl: business.coverUrl,
                    logoUrl: business.logoUrl,
                    fallbackText: business.name,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              SettingsField(
                label: 'Business Name',
                child: TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  validator: _required,
                ),
              ),
              SettingsField(
                label: 'URL Slug',
                helper: 'Used in your public booking link.',
                child: TextFormField(
                  controller: _slug,
                  textInputAction: TextInputAction.next,
                  validator: _validateSlug,
                ),
              ),
              SettingsField(
                label: 'Default Currency',
                child: DropdownButtonFormField<String>(
                  initialValue: currency,
                  isExpanded: true,
                  items: _currencyOptions(currency)
                      .map(
                        (code) => DropdownMenuItem(
                          value: code,
                          child: Text(code, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(_currencyProvider(business).notifier).state = value;
                    }
                  },
                ),
              ),
              SettingsField(
                label: 'City',
                child: TextFormField(
                  controller: _city,
                  textInputAction: TextInputAction.next,
                  validator: _required,
                ),
              ),
              SettingsField(
                label: 'Complete Address',
                child: TextFormField(
                  controller: _address,
                  maxLines: 2,
                  validator: _required,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: isSavingDetails ? 'Saving…' : 'Save Changes',
                  isLoading: isSavingDetails,
                  onPressed: isSavingDetails ? null : _saveDetails,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          SettingsPanel(
            title: 'Cancellation Policy',
            subtitle: 'Control if and when customers can cancel their bookings.',
            children: [
              SettingsField(
                label: 'Allow Cancellations?',
                child: DropdownButtonFormField<bool>(
                  initialValue: allowCancellations,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: true,
                      child: Text(
                        'Yes, customers can cancel',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: false,
                      child: Text(
                        'No, all bookings are final',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(_allowCancellationsProvider(business).notifier).state = value;
                    }
                  },
                ),
              ),
              if (allowCancellations)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SettingsField(
                        label: 'Cancellation Window',
                        child: TextFormField(
                          controller: _cancellationWindow,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingLg),
                    Expanded(
                      child: SettingsField(
                        label: 'Unit',
                        child: DropdownButtonFormField<String>(
                          initialValue: cancellationUnit,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'HOURS',
                              child: Text(
                                'Hours',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'DAYS',
                              child: Text(
                                'Days',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              ref.read(_cancellationUnitProvider(business).notifier).state =
                                  value;
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppDimensions.spacingSm),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: isSavingPolicy ? 'Saving…' : 'Save Policy',
                  isLoading: isSavingPolicy,
                  onPressed: isSavingPolicy ? null : _savePolicy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({
    required this.label,
    required this.picked,
    required this.onPick,
    required this.preview,
  });

  final String label;
  final XFile? picked;
  final VoidCallback onPick;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              child: picked == null
                  ? preview
                  : Image.file(
                      File(picked!.path),
                      width: 96,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppButton(
                    label: picked == null ? 'Choose file' : 'Change file',
                    icon: Icons.upload_rounded,
                    type: AppButtonType.outlined,
                    onPressed: onPick,
                  ),
                  if (picked != null) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      'New image selected',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.accent,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Operating hours
// ---------------------------------------------------------------------------

class _OperatingHoursTab extends ConsumerStatefulWidget {
  const _OperatingHoursTab({required this.business, super.key});

  final Business business;

  @override
  ConsumerState<_OperatingHoursTab> createState() => _OperatingHoursTabState();
}

/// Monday first, matching the dashboard; Sunday is `dayOfWeek` 0.
const _dayOrder = [1, 2, 3, 4, 5, 6, 0];

/// Keyed by `Business` so the initial per-day map is computed by the
/// provider itself from that business's saved hours, rather than a widget
/// writing to it from `initState` (which Riverpod forbids).
final _operatingHoursProvider =
    StateProvider.autoDispose.family<Map<int, BusinessOperatingHour>, Business>(
  (ref, business) {
    final existing = {
      for (final hour in business.settings.operatingHours) hour.dayOfWeek: hour,
    };

    return {
      for (final day in _dayOrder)
        day: existing[day] ??
            BusinessOperatingHour(
              dayOfWeek: day,
              startTime: '09:00',
              endTime: '17:00',
              isOffDay: true,
            ),
    };
  },
);
final _isSavingHoursProvider = StateProvider.autoDispose<bool>((_) => false);

class _OperatingHoursTabState extends ConsumerState<_OperatingHoursTab> {
  static const _dayNames = {
    0: 'Sunday',
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
  };

  Future<void> _pickTime(int day, {required bool isStart}) async {
    final hours = ref.read(_operatingHoursProvider(widget.business));
    final hour = hours[day]!;
    final initial = parseHhMm(isStart ? hour.startTime : hour.endTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null || !mounted) {
      return;
    }

    ref.read(_operatingHoursProvider(widget.business).notifier).state = {
      ...hours,
      day: isStart
          ? hour.copyWith(startTime: formatHhMm(picked))
          : hour.copyWith(endTime: formatHhMm(picked)),
    };
  }

  Future<void> _save() async {
    final hours = ref.read(_operatingHoursProvider(widget.business));
    ref.read(_isSavingHoursProvider.notifier).state = true;
    final error = await ref
        .read(businessAdminActionControllerProvider)
        .saveOperatingHours(
          _dayOrder.map((day) => hours[day]!).toList(growable: false),
        );

    if (!mounted) {
      return;
    }
    ref.read(_isSavingHoursProvider.notifier).state = false;
    showSettingsMessage(
      context,
      message: error ?? 'Operating hours saved.',
      isError: error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hours = ref.watch(_operatingHoursProvider(widget.business));
    final isSaving = ref.watch(_isSavingHoursProvider);

    return SettingsPanel(
      title: 'Business Operating Hours',
      subtitle: 'Set the default weekly schedule. Staff schedules can still '
          'override these times.',
      children: [
        for (final day in _dayOrder) ...[
          _OperatingHourTile(
            name: _dayNames[day]!,
            hour: hours[day]!,
            onToggle: (isOpen) {
              ref.read(_operatingHoursProvider(widget.business).notifier).state = {
                ...hours,
                day: hours[day]!.copyWith(isOffDay: !isOpen),
              };
            },
            onPickStart: () => _pickTime(day, isStart: true),
            onPickEnd: () => _pickTime(day, isStart: false),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
        ],
        const SizedBox(height: AppDimensions.spacingSm),
        AppButton(
          label: isSaving ? 'Saving…' : 'Save Operating Hours',
          isLoading: isSaving,
          isExpanded: true,
          onPressed: isSaving ? null : _save,
        ),
      ],
    );
  }
}

class _OperatingHourTile extends StatelessWidget {
  const _OperatingHourTile({
    required this.name,
    required this.hour,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final String name;
  final BusinessOperatingHour hour;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isOpen = !hour.isOffDay;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          children: [
            Row(
              children: [
                Switch.adaptive(value: isOpen, onChanged: onToggle),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (!isOpen)
                  Text(
                    'Closed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
              ],
            ),
            if (isOpen) ...[
              const SizedBox(height: AppDimensions.spacingSm),
              Row(
                children: [
                  Expanded(
                    child: _TimeChip(
                      value: hour.startTime,
                      onTap: onPickStart,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingSm,
                    ),
                    child: Text(
                      'to',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: _TimeChip(value: hour.endTime, onTap: onPickEnd),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            border: Border.all(color: colors.border),
          ),
          // Two chips plus the "to" separator have very little room on a 320dp
          // screen; scaling down beats ellipsising a time.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingSm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text(
                    formatTime12(value),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Holidays & closures
// ---------------------------------------------------------------------------

class _HolidaysTab extends ConsumerStatefulWidget {
  const _HolidaysTab();

  @override
  ConsumerState<_HolidaysTab> createState() => _HolidaysTabState();
}

final _holidayStartDateProvider = StateProvider.autoDispose<DateTime?>((_) => null);
final _holidayEndDateProvider = StateProvider.autoDispose<DateTime?>((_) => null);
final _holidayStartTimeProvider = StateProvider.autoDispose<TimeOfDay?>((_) => null);
final _holidayEndTimeProvider = StateProvider.autoDispose<TimeOfDay?>((_) => null);
final _isSavingHolidayProvider = StateProvider.autoDispose<bool>((_) => false);

class _HolidaysTabState extends ConsumerState<_HolidaysTab> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final startDate = ref.read(_holidayStartDateProvider);
    final endDate = ref.read(_holidayEndDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? startDate : endDate) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );

    if (picked == null || !mounted) {
      return;
    }

    if (isStart) {
      ref.read(_holidayStartDateProvider.notifier).state = picked;
      if (endDate != null && endDate.isBefore(picked)) {
        ref.read(_holidayEndDateProvider.notifier).state = picked;
      }
    } else {
      ref.read(_holidayEndDateProvider.notifier).state = picked;
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final startTime = ref.read(_holidayStartTimeProvider);
    final endTime = ref.read(_holidayEndTimeProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? startTime : endTime) ?? TimeOfDay.now(),
    );

    if (picked == null || !mounted) {
      return;
    }

    if (isStart) {
      ref.read(_holidayStartTimeProvider.notifier).state = picked;
    } else {
      ref.read(_holidayEndTimeProvider.notifier).state = picked;
    }
  }

  Future<void> _checkAndClose() async {
    final start = ref.read(_holidayStartDateProvider);
    if (start == null) {
      return;
    }
    final end = ref.read(_holidayEndDateProvider) ?? start;

    ref.read(_isSavingHolidayProvider.notifier).state = true;
    final controller = ref.read(businessAdminActionControllerProvider);
    final check = await controller.checkHolidayBookings(
      date: start,
      endDate: end,
    );

    if (!mounted) {
      return;
    }

    switch (check) {
      case Fail(failure: final failure):
        ref.read(_isSavingHolidayProvider.notifier).state = false;
        showSettingsMessage(context, message: failure.message, isError: true);
        return;
      case Success(data: final result):
        if (result.hasConflicts) {
          final proceed = await _confirmConflicts(result.conflictCount);
          if (!mounted) {
            return;
          }
          if (!proceed) {
            ref.read(_isSavingHolidayProvider.notifier).state = false;
            return;
          }
        }
    }

    final startTime = ref.read(_holidayStartTimeProvider);
    final endTime = ref.read(_holidayEndTimeProvider);
    final error = await controller.createHoliday(
      date: start,
      endDate: end,
      startTime: startTime == null ? null : formatHhMm(startTime),
      endTime: endTime == null ? null : formatHhMm(endTime),
      reason: _reason.text.trim(),
    );

    if (!mounted) {
      return;
    }
    ref.read(_isSavingHolidayProvider.notifier).state = false;
    if (error == null) {
      ref.read(_holidayStartDateProvider.notifier).state = null;
      ref.read(_holidayEndDateProvider.notifier).state = null;
      ref.read(_holidayStartTimeProvider.notifier).state = null;
      ref.read(_holidayEndTimeProvider.notifier).state = null;
      _reason.clear();
    }
    showSettingsMessage(
      context,
      message: error ?? 'Date closed successfully.',
      isError: error != null,
    );
  }

  Future<bool> _confirmConflicts(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = dialogContext.appColors;

        return AlertDialog(
          backgroundColor: colors.surface,
          title: const Text('Existing bookings found'),
          content: Text(
            '$count booking${count == 1 ? '' : 's'} fall inside this range. '
            'Closing these dates will cancel them and notify the customers.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Close anyway'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final startDate = ref.watch(_holidayStartDateProvider);
    final endDate = ref.watch(_holidayEndDateProvider);
    final startTime = ref.watch(_holidayStartTimeProvider);
    final endTime = ref.watch(_holidayEndTimeProvider);
    final isSaving = ref.watch(_isSavingHolidayProvider);
    final canSubmit = startDate != null && !isSaving;

    return SettingsPanel(
      title: 'Holidays & Exceptions',
      subtitle: 'Add specific dates when your business will be closed, either '
          'for the full day or specific hours.',
      children: [
        Row(
          children: [
            Expanded(
              child: SettingsField(
                label: 'Start Date',
                child: _PickerTile(
                  icon: Icons.event_rounded,
                  value: startDate == null
                      ? 'Select date'
                      : formatDate(startDate),
                  isPlaceholder: startDate == null,
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingLg),
            Expanded(
              child: SettingsField(
                label: 'End Date',
                child: _PickerTile(
                  icon: Icons.event_repeat_rounded,
                  value: endDate == null ? 'Optional' : formatDate(endDate),
                  isPlaceholder: endDate == null,
                  onTap: () => _pickDate(isStart: false),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: SettingsField(
                label: 'Start Time',
                child: _PickerTile(
                  icon: Icons.schedule_rounded,
                  value: startTime == null
                      ? 'Optional'
                      : startTime.format(context),
                  isPlaceholder: startTime == null,
                  onTap: () => _pickTime(isStart: true),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingLg),
            Expanded(
              child: SettingsField(
                label: 'End Time',
                child: _PickerTile(
                  icon: Icons.schedule_rounded,
                  value: endTime == null ? 'Optional' : endTime.format(context),
                  isPlaceholder: endTime == null,
                  onTap: () => _pickTime(isStart: false),
                ),
              ),
            ),
          ],
        ),
        Text(
          'Leave times blank for a full-day closure.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        SettingsField(
          label: 'Reason for Closure',
          helper: 'Sent to customers if bookings are cancelled.',
          child: TextFormField(
            controller: _reason,
            decoration: const InputDecoration(
              hintText: 'e.g. Public Holiday, Maintenance',
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        AppButton(
          label: isSaving ? 'Checking…' : 'Check & Close Date',
          isLoading: isSaving,
          isExpanded: true,
          onPressed: canSubmit ? _checkAndClose : null,
        ),
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.value,
    required this.isPlaceholder,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final bool isPlaceholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: colors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          height: AppDimensions.buttonHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingMd,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colors.textSecondary),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isPlaceholder
                        ? colors.textSecondary
                        : colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Booking page appearance
// ---------------------------------------------------------------------------

class _BookingPageTab extends ConsumerStatefulWidget {
  const _BookingPageTab({required this.business, super.key});

  final Business business;

  @override
  ConsumerState<_BookingPageTab> createState() => _BookingPageTabState();
}

/// Keyed by `Business` so the starting colours come from that business's
/// saved theme via the provider's own builder, instead of a widget writing to
/// it from `initState` (which Riverpod forbids).
final _bookingThemeProvider = StateProvider.autoDispose.family<BusinessTheme, Business>(
  (ref, business) => business.settings.theme,
);
final _isSavingThemeProvider = StateProvider.autoDispose<bool>((_) => false);

class _BookingPageTabState extends ConsumerState<_BookingPageTab> {
  Future<void> _save() async {
    ref.read(_isSavingThemeProvider.notifier).state = true;
    final business = widget.business;
    final theme = ref.read(_bookingThemeProvider(business));
    // The theme is stored inside `settings`, so the rest of the object has to
    // travel with it or the API would drop it.
    final error = await ref.read(businessAdminActionControllerProvider).saveBusinessDetails(
          name: business.name,
          slug: business.slug,
          city: business.city,
          address: business.address,
          settings: business.settings.copyWith(theme: theme),
        );

    if (!mounted) {
      return;
    }
    ref.read(_isSavingThemeProvider.notifier).state = false;
    showSettingsMessage(
      context,
      message: error ?? 'Booking page theme saved.',
      isError: error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(_bookingThemeProvider(widget.business));
    final isSaving = ref.watch(_isSavingThemeProvider);
    final themeNotifier = ref.read(_bookingThemeProvider(widget.business).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsPanel(
          title: 'Booking Page Appearance',
          subtitle: 'Customise colours for your public booking page.',
          trailing: TextButton.icon(
            onPressed: isSaving
                ? null
                : () => themeNotifier.state = BusinessTheme.defaults,
            icon: const Icon(Icons.palette_outlined, size: 18),
            label: const Text('Reset'),
          ),
          children: [
            _ColorField(
              label: 'Primary Brand Color',
              helper: 'Used for buttons and accents.',
              value: theme.primaryColor,
              onChanged: (value) {
                themeNotifier.state = theme.copyWith(primaryColor: value);
              },
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            _ThemeGroup(
              title: 'Light Mode Colors',
              fields: [
                ('Background Color', theme.lightBackground, (String v) {
                  themeNotifier.state = theme.copyWith(lightBackground: v);
                }),
                ('Surface (Cards) Color', theme.lightSurface, (String v) {
                  themeNotifier.state = theme.copyWith(lightSurface: v);
                }),
                ('Text Color', theme.lightText, (String v) {
                  themeNotifier.state = theme.copyWith(lightText: v);
                }),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            _ThemeGroup(
              title: 'Dark Mode Colors',
              fields: [
                ('Background Color', theme.darkBackground, (String v) {
                  themeNotifier.state = theme.copyWith(darkBackground: v);
                }),
                ('Surface (Cards) Color', theme.darkSurface, (String v) {
                  themeNotifier.state = theme.copyWith(darkSurface: v);
                }),
                ('Text Color', theme.darkText, (String v) {
                  themeNotifier.state = theme.copyWith(darkText: v);
                }),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            _ThemePreview(theme: theme),
            const SizedBox(height: AppDimensions.spacingLg),
            AppButton(
              label: isSaving ? 'Saving…' : 'Save Theme',
              isLoading: isSaving,
              isExpanded: true,
              onPressed: isSaving ? null : _save,
            ),
          ],
        ),
      ],
    );
  }
}

class _ThemeGroup extends StatelessWidget {
  const _ThemeGroup({required this.title, required this.fields});

  final String title;
  final List<(String, String, ValueChanged<String>)> fields;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            for (final (label, value, onChanged) in fields)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimensions.spacingMd,
                ),
                child: _ColorField(
                  label: label,
                  value: value,
                  onChanged: onChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ColorField extends StatefulWidget {
  const _ColorField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final String value;
  final String? helper;
  final ValueChanged<String> onChanged;

  @override
  State<_ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<_ColorField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_ColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in step when the parent resets the palette.
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openSwatches() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.appColors.surface,
      builder: (sheetContext) => _SwatchSheet(selected: widget.value),
    );

    if (picked != null) {
      _controller.text = picked;
      widget.onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
        ),
        if (widget.helper != null)
          Text(
            widget.helper!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
        const SizedBox(height: AppDimensions.spacingSm),
        Row(
          children: [
            GestureDetector(
              onTap: _openSwatches,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hexToColor(widget.value, colors.surfaceMuted),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusSmall,
                  ),
                  border: Border.all(color: colors.border),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                decoration: const InputDecoration(hintText: '#2563eb'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SwatchSheet extends StatelessWidget {
  const _SwatchSheet({required this.selected});

  static const _swatches = [
    '#2563eb', '#1f5eff', '#0ea5e9', '#22c55e', '#16a34a',
    '#f59e0b', '#ef4444', '#ec4899', '#8b5cf6', '#0f172a',
    '#1e293b', '#334155', '#64748b', '#f8fafc', '#ffffff',
  ];

  final String selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingXl,
        0,
        AppDimensions.spacingXl,
        AppDimensions.spacing2xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pick a colour',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Wrap(
            spacing: AppDimensions.spacingMd,
            runSpacing: AppDimensions.spacingMd,
            children: [
              for (final swatch in _swatches)
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(swatch),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hexToColor(swatch, colors.surfaceMuted),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusSmall,
                      ),
                      border: Border.all(
                        color: swatch.toLowerCase() == selected.toLowerCase()
                            ? colors.primary
                            : colors.border,
                        width: swatch.toLowerCase() == selected.toLowerCase()
                            ? 3
                            : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme});

  final BusinessTheme theme;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Row(
          children: [
            Expanded(
              child: _PreviewCard(
                label: 'Light',
                background: theme.lightBackground,
                surface: theme.lightSurface,
                text: theme.lightText,
                primary: theme.primaryColor,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: _PreviewCard(
                label: 'Dark',
                background: theme.darkBackground,
                surface: theme.darkSurface,
                text: theme.darkText,
                primary: theme.primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.label,
    required this.background,
    required this.surface,
    required this.text,
    required this.primary,
  });

  final String label;
  final String background;
  final String surface;
  final String text;
  final String primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textColor = hexToColor(text, colors.textPrimary);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: hexToColor(background, colors.background),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingSm),
            decoration: BoxDecoration(
              color: hexToColor(surface, colors.surface),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 6,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Container(
                  width: double.infinity,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hexToColor(primary, colors.primary),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusPill,
                    ),
                  ),
                  child: const Text(
                    'Book now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppDimensions.spacingXs),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            ...children,
          ],
        ),
      ),
    );
  }
}

class SettingsField extends StatelessWidget {
  const SettingsField({
    required this.label,
    required this.child,
    this.helper,
    super.key,
  });

  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (helper != null)
            Text(
              helper!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
          const SizedBox(height: AppDimensions.spacingSm),
          child,
        ],
      ),
    );
  }
}

String? _required(String? value) {
  if ((value ?? '').trim().isEmpty) {
    return AppStrings.requiredFieldValidation;
  }
  return null;
}

String? _validateSlug(String? value) {
  final slug = (value ?? '').trim();
  if (slug.isEmpty) {
    return AppStrings.requiredFieldValidation;
  }
  if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
    return 'Use lowercase letters, numbers and hyphens only.';
  }
  return null;
}

void showSettingsMessage(
  BuildContext context, {
  required String message,
  required bool isError,
}) {
  if (message.isEmpty) {
    return;
  }

  final colors = context.appColors;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? colors.error : colors.primary,
    ),
  );
}

/// Parses `#rrggbb` / `#aarrggbb`, falling back when the value is incomplete
/// (the hex field is edited live, so partial input is expected).
Color hexToColor(String hex, Color fallback) {
  var value = hex.trim().replaceFirst('#', '');
  if (value.length == 6) {
    value = 'ff$value';
  }
  if (value.length != 8) {
    return fallback;
  }

  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

TimeOfDay parseHhMm(String value) {
  final parts = value.split(':');
  if (parts.length < 2) {
    return const TimeOfDay(hour: 9, minute: 0);
  }

  return TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 9,
    minute: int.tryParse(parts[1]) ?? 0,
  );
}

String formatHhMm(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatTime12(String hhmm) {
  final time = parseHhMm(hhmm);
  final period = time.hour < 12 ? 'AM' : 'PM';
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}

String formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
