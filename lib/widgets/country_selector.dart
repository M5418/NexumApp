import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/countries.dart';

class CountrySelector extends StatefulWidget {
  final String? initialCountry;
  final Function(String) onCountrySelected;
  final bool isDarkMode;

  const CountrySelector({
    super.key,
    this.initialCountry,
    required this.onCountrySelected,
    required this.isDarkMode,
  });

  @override
  State<CountrySelector> createState() => _CountrySelectorState();
}

class _CountrySelectorState extends State<CountrySelector> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryData> _filteredCountries = allCountries;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCountries);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCountries() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = allCountries;
      } else {
        _filteredCountries = allCountries
            .where((country) =>
                country.name.toLowerCase().contains(query) ||
                country.code.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final screen = MediaQuery.of(context).size;

    return Container(
      height: screen.height * 0.75,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Select Country',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: textColor),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search countries...',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF666666),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF666666),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          // Countries list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredCountries.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 0.5,
                color: const Color(0xFF666666).withValues(alpha: 0.10),
              ),
              itemBuilder: (context, index) {
                final country = _filteredCountries[index];
                final isSelected = widget.initialCountry == country.name;
                return ListTile(
                  onTap: () {
                    widget.onCountrySelected(country.name);
                    Navigator.pop(context, country.name);
                  },
                  title: Text(
                    country.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? const Color(0xFFBFAE01) : textColor,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Color(0xFFBFAE01),
                          size: 22,
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
