import 'package:flutter/material.dart';

import '../models/place_suggestion.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// A text field with Google Places suggestions — the mobile equivalent of
/// the web admin panel's google.maps.places.Autocomplete widget (see
/// resources/views/admin/hires/index.blade.php's attachPlaceAutocomplete()).
/// Backed by the server-side proxy in Api\Admin\PlaceController, so the
/// Google Maps key stays server-side rather than baked into the app binary.
///
/// Reports resolved coordinates via [onCoordinatesChanged] only when a
/// suggestion is actually picked (a details lookup happens on selection,
/// same as the web widget deferring geometry until 'place_changed'). If the
/// user edits the text afterward so it no longer matches what was picked,
/// the stale coordinates are cleared automatically — a hire should never
/// be saved with coordinates that belong to a different piece of text.
class LocationAutocompleteField extends StatefulWidget {
  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.onCoordinatesChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final void Function(double? lat, double? lng)? onCoordinatesChanged;

  @override
  State<LocationAutocompleteField> createState() => _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final _focusNode = FocusNode();

  int _requestId = 0;
  String? _pickedText;
  bool _hasCoordinates = false;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_pickedText != null && widget.controller.text != _pickedText) {
      _pickedText = null;
      if (_hasCoordinates) setState(() => _hasCoordinates = false);
      widget.onCoordinatesChanged?.call(null, null);
    }
  }

  Future<Iterable<PlaceSuggestion>> _fetchOptions(TextEditingValue value) async {
    final query = value.text.trim();
    if (query.length < 2) return const Iterable<PlaceSuggestion>.empty();

    final requestId = ++_requestId;
    // A light debounce: wait a beat, then bail if a newer keystroke has
    // already superseded this request — avoids firing (and billing) one
    // Places API call per character typed.
    await Future.delayed(const Duration(milliseconds: 350));
    if (requestId != _requestId) return const Iterable<PlaceSuggestion>.empty();

    final results = await ApiClient.instance.autocompletePlaces(query);
    if (requestId != _requestId) return const Iterable<PlaceSuggestion>.empty();

    return results;
  }

  Future<void> _onSelected(PlaceSuggestion selection) async {
    setState(() {
      _pickedText = selection.description;
      _resolving = true;
    });

    final details = await ApiClient.instance.fetchPlaceDetails(selection.placeId);

    if (!mounted || widget.controller.text != selection.description) {
      // The user kept typing past the pick before details came back —
      // don't attach coordinates to text that's already moved on.
      if (mounted) setState(() => _resolving = false);
      return;
    }

    setState(() {
      _resolving = false;
      _hasCoordinates = details.hasCoordinates;
    });
    widget.onCoordinatesChanged?.call(details.lat, details.lng);
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<PlaceSuggestion>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (option) => option.description,
      optionsBuilder: _fetchOptions,
      onSelected: _onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, size: 18) : null,
            suffixIcon: _resolving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_hasCoordinates
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                    : null),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, minWidth: 260),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              option.description,
                              style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
