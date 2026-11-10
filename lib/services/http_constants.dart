/// Where the app sends HTTP requests. Services read their base URLs from here
/// instead of writing them inline.
abstract final class HttpEndpoints {
  /// Legacy Kickoff API; override with `--dart-define=API_BASE_URL=...`.
  static const kickoffApi = 'http://10.0.2.2:8080';

  /// Sunrise and sunset times.
  static const sunriseSunset = 'https://api.sunrise-sunset.org/json';

  /// Place search and reverse lookup (OpenStreetMap Nominatim).
  static const nominatimHost = 'nominatim.openstreetmap.org';
  static const nominatimSearch = 'https://$nominatimHost/search';

  /// Travel time (OSRM car router and OpenStreetMap foot router).
  static const osrmDriving = 'https://router.project-osrm.org/route/v1/driving';
  static const osrmFoot =
      'https://routing.openstreetmap.de/routed-foot/route/v1/foot';

  /// Weather forecast.
  static const openMeteo = 'https://api.open-meteo.com/v1/forecast';

  /// Countries list.
  static const restCountries = 'https://restcountries.com/v3.1';
}
