class Country {
  final String name;
  final String iso;
  final String dialCode;

  const Country(this.name, this.iso, this.dialCode);
}

const List<Country> countries = <Country>[
  Country('Ayiti', 'HT', '+509'),
  Country('Repiblik Dominikn', 'DO', '+1'),
  Country('Chili', 'CL', '+56'),
  Country('Brezil', 'BR', '+55'),
  Country('Meksik', 'MX', '+52'),
];
