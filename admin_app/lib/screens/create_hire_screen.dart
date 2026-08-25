import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hire.dart';
import '../models/reference_data.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/location_autocomplete_field.dart';

const _tourTypes = {
  'drop_pickup': 'Drop and Pickup',
  'day_tour': 'Day Tour',
  'multi_day': 'Multi Day Tour',
  'package': 'Package',
};

const _paymentTypes = {
  'cash': 'Cash',
  'credit': 'Credit',
};

class CreateHireScreen extends StatefulWidget {
  const CreateHireScreen({super.key});

  @override
  State<CreateHireScreen> createState() => _CreateHireScreenState();
}

class _CreateHireScreenState extends State<CreateHireScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _loadingReference = true;
  String? _loadError;
  ReferenceData? _reference;

  String _tourType = 'drop_pickup';
  String _paymentType = 'cash';

  bool _isNewCustomer = false;
  int? _customerId;
  final _newCustomerName = TextEditingController();
  final _newCustomerPhone = TextEditingController();

  int? _driverId;
  int? _vehicleId;
  int? _packageId;

  final _hireFullValue = TextEditingController();
  final _ourHireValue = TextEditingController();
  final _description = TextEditingController();

  final _fromLocation = TextEditingController();
  final _toLocation = TextEditingController();
  double? _fromLat;
  double? _fromLng;
  double? _toLat;
  double? _toLng;

  final List<TextEditingController> _stayLocations = [TextEditingController()];
  // Parallel to _stayLocations — kept in sync on every add/remove so index
  // i's coordinates always belong to index i's name.
  final List<double?> _stayLats = [null];
  final List<double?> _stayLngs = [null];

  // One list of controllers per day; starts with a single day, single stop.
  final List<List<TextEditingController>> _dayLocations = [
    [TextEditingController()],
  ];
  final List<List<double?>> _dayLats = [[null]];
  final List<List<double?>> _dayLngs = [[null]];

  DateTime? _startTime;
  DateTime? _endTime;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadReference();
  }

  @override
  void dispose() {
    _newCustomerName.dispose();
    _newCustomerPhone.dispose();
    _hireFullValue.dispose();
    _ourHireValue.dispose();
    _description.dispose();
    _fromLocation.dispose();
    _toLocation.dispose();
    for (final c in _stayLocations) {
      c.dispose();
    }
    for (final day in _dayLocations) {
      for (final c in day) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadReference() async {
    setState(() {
      _loadingReference = true;
      _loadError = null;
    });

    try {
      final reference = await ApiClient.instance.fetchReferenceData();
      if (!mounted) return;
      setState(() => _reference = reference);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load form data. Pull to retry.');
    } finally {
      if (mounted) setState(() => _loadingReference = false);
    }
  }

  bool get _needsFromTo => _tourType == 'drop_pickup' || _tourType == 'day_tour';
  bool get _needsStays => _tourType == 'day_tour';
  bool get _needsDays => _tourType == 'multi_day';
  bool get _isPackage => _tourType == 'package';

  Future<void> _pickStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _startTime != null ? TimeOfDay.fromDateTime(_startTime!) : TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickEndTime() async {
    final base = _endTime ?? _startTime ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: _startTime ?? DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;

    setState(() {
      _endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Map<String, dynamic> _buildPayload() {
    final data = <String, dynamic>{
      'tour_type': _tourType,
      'hire_full_value': _hireFullValue.text.trim(),
      'our_hire_value': _ourHireValue.text.trim(),
      'payment_type': _paymentType,
      'driver_id': _driverId,
      'vehicle_id': _vehicleId,
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
    };

    if (_isNewCustomer) {
      data['customer_id'] = 'new';
      data['new_customer_name'] = _newCustomerName.text.trim();
      data['new_customer_phone'] = _newCustomerPhone.text.trim();
    } else {
      data['customer_id'] = _customerId;
    }

    if (_needsFromTo) {
      data['from_location_name'] = _fromLocation.text.trim();
      data['from_location_lat'] = _fromLat;
      data['from_location_lng'] = _fromLng;
      data['to_location_name'] = _toLocation.text.trim();
      data['to_location_lat'] = _toLat;
      data['to_location_lng'] = _toLng;
    }

    if (_needsStays) {
      final names = <String>[];
      final lats = <double?>[];
      final lngs = <double?>[];
      for (var i = 0; i < _stayLocations.length; i++) {
        final name = _stayLocations[i].text.trim();
        if (name.isEmpty) continue;
        names.add(name);
        lats.add(_stayLats[i]);
        lngs.add(_stayLngs[i]);
      }
      data['stay_location_names'] = names;
      data['stay_location_lats'] = lats;
      data['stay_location_lngs'] = lngs;
    }

    if (_needsDays) {
      final dayNames = <List<String>>[];
      final dayLats = <List<double?>>[];
      final dayLngs = <List<double?>>[];
      for (var d = 0; d < _dayLocations.length; d++) {
        final names = <String>[];
        final lats = <double?>[];
        final lngs = <double?>[];
        for (var i = 0; i < _dayLocations[d].length; i++) {
          final name = _dayLocations[d][i].text.trim();
          if (name.isEmpty) continue;
          names.add(name);
          lats.add(_dayLats[d][i]);
          lngs.add(_dayLngs[d][i]);
        }
        if (names.isEmpty) continue;
        dayNames.add(names);
        dayLats.add(lats);
        dayLngs.add(lngs);
      }
      data['day_location_names'] = dayNames;
      data['day_location_lats'] = dayLats;
      data['day_location_lngs'] = dayLngs;
    }

    if (_isPackage) {
      data['package_id'] = _packageId;
      data['start_time'] = _startTime?.toIso8601String();
      data['end_time'] = _endTime?.toIso8601String();
    } else if (_startTime != null) {
      data['start_time'] = _startTime!.toIso8601String();
    }

    return data;
  }

  String? _validateBeforeSubmit() {
    if (_isNewCustomer) {
      if (_newCustomerName.text.trim().isEmpty) return 'Enter the new customer\'s name.';
      if (_newCustomerPhone.text.trim().isEmpty) return 'Enter the new customer\'s phone number.';
    } else if (_customerId == null) {
      return 'Select a customer, or switch to "New customer".';
    }

    if (_needsFromTo) {
      if (_fromLocation.text.trim().isEmpty) return 'Enter the pickup (from) location.';
      if (_toLocation.text.trim().isEmpty) return 'Enter the drop-off (to) location.';
    }

    if (_needsStays) {
      final any = _stayLocations.any((c) => c.text.trim().isNotEmpty);
      if (!any) return 'Add at least one stay location.';
    }

    if (_needsDays) {
      final anyDay = _dayLocations.any((day) => day.any((c) => c.text.trim().isNotEmpty));
      if (!anyDay) return 'Add at least one location for the tour days.';
    }

    if (_isPackage) {
      if (_packageId == null) return 'Select a package.';
      if (_startTime == null) return 'Pick a start date & time.';
      if (_endTime == null) return 'Pick an end date & time.';
      if (!_endTime!.isAfter(_startTime!)) return 'End time must be after the start time.';
    }

    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final validationError = _validateBeforeSubmit();
    if (validationError != null) {
      setState(() => _submitError = validationError);
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final Hire hire = await ApiClient.instance.createHire(_buildPayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hire #${hire.id} created.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _submitError = e.message);
    } catch (_) {
      setState(() => _submitError = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Hire')),
      body: _loadingReference
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _loadReference, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    final reference = _reference!;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_submitError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_submitError!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const _SectionLabel('Tour Type'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tourTypes.entries.map((entry) {
              final selected = _tourType == entry.key;
              return ChoiceChip(
                label: Text(entry.value),
                selected: selected,
                onSelected: (_) => setState(() => _tourType = entry.key),
                selectedColor: AppColors.surfaceElevated,
                labelStyle: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                backgroundColor: AppColors.surface,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          const _SectionLabel('Customer'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isNewCustomer = false),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: !_isNewCustomer ? AppColors.surfaceElevated : null,
                    side: BorderSide(color: !_isNewCustomer ? AppColors.primary : AppColors.border),
                  ),
                  child: const Text('Existing'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isNewCustomer = true),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _isNewCustomer ? AppColors.surfaceElevated : null,
                    side: BorderSide(color: _isNewCustomer ? AppColors.primary : AppColors.border),
                  ),
                  child: const Text('New customer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isNewCustomer) ...[
            TextFormField(
              controller: _newCustomerName,
              decoration: const InputDecoration(labelText: 'Customer name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newCustomerPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Customer phone'),
            ),
          ] else
            DropdownButtonFormField<int>(
              initialValue: _customerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Select customer'),
              items: reference.customers
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.subtitle != null && c.subtitle!.isNotEmpty ? '${c.name} · ${c.subtitle}' : c.name),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _customerId = value),
            ),
          const SizedBox(height: 20),

          const _SectionLabel('Driver & Vehicle (optional)'),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _driverId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Driver'),
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('No driver assigned')),
              ...reference.drivers.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
            ],
            onChanged: (value) => setState(() => _driverId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _vehicleId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vehicle'),
            items: [
              const DropdownMenuItem<int>(value: null, child: Text('No vehicle assigned')),
              ...reference.vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))),
            ],
            onChanged: (value) => setState(() => _vehicleId = value),
          ),
          const SizedBox(height: 20),

          if (_needsFromTo) ...[
            const _SectionLabel('Route'),
            const SizedBox(height: 8),
            LocationAutocompleteField(
              controller: _fromLocation,
              label: 'From location',
              prefixIcon: Icons.trip_origin_rounded,
              onCoordinatesChanged: (lat, lng) {
                _fromLat = lat;
                _fromLng = lng;
              },
            ),
            const SizedBox(height: 12),
            LocationAutocompleteField(
              controller: _toLocation,
              label: 'To location',
              prefixIcon: Icons.place_rounded,
              onCoordinatesChanged: (lat, lng) {
                _toLat = lat;
                _toLng = lng;
              },
            ),
            const SizedBox(height: 20),
          ],

          if (_needsStays) ...[
            const _SectionLabel('Stay Locations'),
            const SizedBox(height: 8),
            ..._buildDynamicList(
              _stayLocations,
              _stayLats,
              _stayLngs,
              onAdd: () => setState(() {
                _stayLocations.add(TextEditingController());
                _stayLats.add(null);
                _stayLngs.add(null);
              }),
              onRemove: (i) => setState(() {
                _stayLocations[i].dispose();
                _stayLocations.removeAt(i);
                _stayLats.removeAt(i);
                _stayLngs.removeAt(i);
              }),
              hint: 'Stay location',
            ),
            const SizedBox(height: 20),
          ],

          if (_needsDays) ...[
            const _SectionLabel('Day-by-Day Locations'),
            const SizedBox(height: 8),
            ..._buildDayLists(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _dayLocations.add([TextEditingController()]);
                _dayLats.add([null]);
                _dayLngs.add([null]);
              }),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add day'),
            ),
            const SizedBox(height: 20),
          ],

          if (_isPackage) ...[
            const _SectionLabel('Package'),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _packageId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Select package'),
              items: reference.packages.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
              onChanged: (value) => setState(() => _packageId = value),
            ),
            const SizedBox(height: 12),
            _DateTimeField(label: 'Start date & time', value: _startTime, onTap: _pickStartTime),
            const SizedBox(height: 12),
            _DateTimeField(label: 'End date & time', value: _endTime, onTap: _pickEndTime),
            const SizedBox(height: 20),
          ] else ...[
            const _SectionLabel('Schedule (optional)'),
            const SizedBox(height: 8),
            _DateTimeField(
              label: 'Scheduled date & time',
              value: _startTime,
              onTap: _pickStartTime,
              onClear: _startTime != null ? () => setState(() => _startTime = null) : null,
            ),
            const SizedBox(height: 20),
          ],

          const _SectionLabel('Value & Payment'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _hireFullValue,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Hire full value (Rs.)'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Required';
              if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ourHireValue,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Our hire value (Rs.)'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Required';
              if (double.tryParse(value.trim()) == null) return 'Enter a valid number';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _paymentType,
            decoration: const InputDecoration(labelText: 'Payment type'),
            items: _paymentTypes.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (value) => setState(() => _paymentType = value ?? 'cash'),
          ),
          const SizedBox(height: 20),

          const _SectionLabel('Notes (optional)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Create Hire'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicList(
    List<TextEditingController> controllers,
    List<double?> lats,
    List<double?> lngs, {
    required VoidCallback onAdd,
    required void Function(int index) onRemove,
    required String hint,
  }) {
    return [
      for (var i = 0; i < controllers.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: LocationAutocompleteField(
                  controller: controllers[i],
                  label: '$hint ${i + 1}',
                  prefixIcon: Icons.place_outlined,
                  onCoordinatesChanged: (lat, lng) {
                    lats[i] = lat;
                    lngs[i] = lng;
                  },
                ),
              ),
              if (controllers.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 20),
                  onPressed: () => onRemove(i),
                ),
            ],
          ),
        ),
      OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text('Add ${hint.toLowerCase()}'),
      ),
    ];
  }

  List<Widget> _buildDayLists() {
    return [
      for (var dayIndex = 0; dayIndex < _dayLocations.length; dayIndex++)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Day ${dayIndex + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
                  ),
                  const Spacer(),
                  if (_dayLocations.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                      onPressed: () => setState(() {
                        for (final c in _dayLocations[dayIndex]) {
                          c.dispose();
                        }
                        _dayLocations.removeAt(dayIndex);
                        _dayLats.removeAt(dayIndex);
                        _dayLngs.removeAt(dayIndex);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              ..._buildDynamicList(
                _dayLocations[dayIndex],
                _dayLats[dayIndex],
                _dayLngs[dayIndex],
                onAdd: () => setState(() {
                  _dayLocations[dayIndex].add(TextEditingController());
                  _dayLats[dayIndex].add(null);
                  _dayLngs[dayIndex].add(null);
                }),
                onRemove: (i) => setState(() {
                  _dayLocations[dayIndex][i].dispose();
                  _dayLocations[dayIndex].removeAt(i);
                  _dayLats[dayIndex].removeAt(i);
                  _dayLngs[dayIndex].removeAt(i);
                }),
                hint: 'Location',
              ),
            ],
          ),
        ),
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({required this.label, required this.value, required this.onTap, this.onClear});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  static final _format = DateFormat('MMM d, y · h:mm a');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule_rounded, size: 18),
          suffixIcon: value != null && onClear != null
              ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: onClear)
              : null,
        ),
        child: Text(
          value != null ? _format.format(value!) : 'Tap to select',
          style: TextStyle(
            fontSize: 14,
            color: value != null ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
