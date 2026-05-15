enum Country { haiti, dominicanRepublic, mexico, chile, brazil, usa }

String countryLabel(Country c) {
  switch (c) {
    case Country.haiti:
      return 'Haiti';
    case Country.dominicanRepublic:
      return 'Rep. Dominicaine';
    case Country.mexico:
      return 'Mexico';
    case Country.chile:
      return 'Chile';
    case Country.brazil:
      return 'Brasil';
    case Country.usa:
      return 'USA';
  }
}
