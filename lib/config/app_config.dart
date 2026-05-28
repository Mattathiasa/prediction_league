class AppConfig {
  // Get your free key at https://www.football-data.org/client/register
  // Free tier: 10 calls/min, Premier League included
  static const String footballDataApiKey = '67ea0c0cacb24129947683063d4130db';

  static const String _base = 'https://api.football-data.org/v4';

  // Upcoming Premier League matches (SCHEDULED + TIMED)
  static const String scheduledMatches =
      '$_base/competitions/PL/matches?status=SCHEDULED,TIMED&limit=20';

  static Map<String, String> get apiHeaders => {
        'X-Auth-Token': footballDataApiKey,
      };

  // Change this to your preferred admin PIN
  static const String adminPin = '1234';
}
