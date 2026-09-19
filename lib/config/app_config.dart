class AppConfig {
  // The football-data.org API key is no longer stored in the client.
  // Fixture syncing is handled server-side via Cloud Functions
  // (see functions/src/index.ts), which retrieve the key from
  // Firebase Functions environment variables.
  //
  // Set your API key with:
  //   firebase functions:configure -o '{"footballDataApiKey":"YOUR_API_KEY"}'
  //
  // The football-data.org API key is never committed or exposed to clients.

  static Map<String, String> get apiHeaders => {
        'X-Auth-Token': '',
      };

  // Change this to your preferred admin PIN
  // NOTE: For production, replace with server-side admin verification
  // via Firebase Custom Claims. This PIN is a client-side gate only.
  static const String adminPin = '1234';
}
