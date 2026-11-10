import 'package:flutter/material.dart';

import '../kickoff_style.dart';
import '../../services/user/country_service.dart';

/// Bottom sheet with a searchable list of countries from [CountryService].
/// Returns the picked [Country], or null when closed.
Future<Country?> pickCountry(BuildContext context, CountryService service) =>
    showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KickoffColors.panelDark,
      builder: (_) => _CountrySheet(service: service),
    );

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.service});

  final CountryService service;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  late Future<List<Country>> _countries = widget.service.all();
  String _query = '';

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const ValueKey('country_search'),
              onChanged: (value) => setState(() => _query = value.trim()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search a country',
                hintStyle: const TextStyle(color: KickoffColors.dim),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: KickoffColors.field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Country>>(
              future: _countries,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${snapshot.error}',
                          key: const ValueKey('country_error'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: KickoffColors.orange),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => _countries = widget.service.all(),
                          ),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  );
                }
                final shown = [
                  for (final country in snapshot.data!)
                    if (country.name.toLowerCase().contains(
                      _query.toLowerCase(),
                    ))
                      country,
                ];
                if (shown.isEmpty) {
                  return const Center(
                    child: Text(
                      'No country found.',
                      style: TextStyle(color: KickoffColors.muted),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final country = shown[index];
                    return ListTile(
                      key: ValueKey('country_${country.code}'),
                      leading: Text(
                        country.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        country.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () => Navigator.of(context).pop(country),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
