/// A country with its international dialling code.
class DialCode {
  const DialCode(this.country, this.code);

  final String country;

  /// With the leading plus, such as "+216".
  final String code;

  /// How many digits the national number has when the country is strict about
  /// it. Tunisian numbers always have 8.
  int? get exactDigits => code == '+216' ? 8 : null;

  int get maxDigits => exactDigits ?? 12;
  int get minDigits => exactDigits ?? 6;
}

const defaultDialCode = DialCode('Tunisia', '+216');

const dialCodes = <DialCode>[
  defaultDialCode,
  DialCode('France', '+33'),
  DialCode('Algeria', '+213'),
  DialCode('Morocco', '+212'),
  DialCode('Libya', '+218'),
  DialCode('Egypt', '+20'),
  DialCode('Belgium', '+32'),
  DialCode('Germany', '+49'),
  DialCode('Italy', '+39'),
  DialCode('Spain', '+34'),
  DialCode('Portugal', '+351'),
  DialCode('United Kingdom', '+44'),
  DialCode('Switzerland', '+41'),
  DialCode('Netherlands', '+31'),
  DialCode('Turkey', '+90'),
  DialCode('Saudi Arabia', '+966'),
  DialCode('United Arab Emirates', '+971'),
  DialCode('Qatar', '+974'),
  DialCode('Senegal', '+221'),
  DialCode("Côte d'Ivoire", '+225'),
  DialCode('United States / Canada', '+1'),
  DialCode('Brazil', '+55'),
  DialCode('Japan', '+81'),
];

/// Splits a saved number such as "+33 612345678" into its dialling code and
/// digits. Numbers without a known code keep the default one.
({DialCode dial, String digits}) splitPhone(String phone) {
  final text = phone.trim();
  if (text.startsWith('+')) {
    final compact = text.replaceAll(RegExp(r'\s'), '');
    DialCode? best;
    for (final dial in dialCodes) {
      if (compact.startsWith(dial.code) &&
          (best == null || dial.code.length > best.code.length)) {
        best = dial;
      }
    }
    if (best != null) {
      return (
        dial: best,
        digits: compact.substring(best.code.length).replaceAll(RegExp(r'\D'), ''),
      );
    }
  }
  return (dial: defaultDialCode, digits: text.replaceAll(RegExp(r'\D'), ''));
}
