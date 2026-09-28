import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_league/models/fixture_model.dart';
import 'package:prediction_league/services/prediction_service.dart';

FixtureModel openFixture({String id = 'fx1'}) => FixtureModel(
      fixtureId: id,
      homeTeam: 'Arsenal',
      awayTeam: 'Chelsea',
      kickoff: DateTime.now().add(const Duration(hours: 6)),
      status: 'upcoming',
      competition: 'Premier League',
    );

FixtureModel lockedFixture() => FixtureModel(
      fixtureId: 'fx1',
      homeTeam: 'Arsenal',
      awayTeam: 'Chelsea',
      kickoff: DateTime.now().add(const Duration(minutes: 30)),
      status: 'upcoming',
      competition: 'Premier League',
    );

void main() {
  late FakeFirebaseFirestore db;
  late PredictionService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = PredictionService(db: db);
  });

  Future<Map<String, dynamic>?> stored(String id) async =>
      (await db.collection('predictions').doc(id).get()).data();

  group('submitPrediction', () {
    test('writes a new prediction with zeroed server fields', () async {
      await service.submitPrediction(
        userId: 'alice',
        fixture: openFixture(),
        homeGuess: 2,
        awayGuess: 1,
      );

      final doc = await stored('alice_fx1');
      expect(doc, isNotNull);
      expect(doc!['userId'], 'alice');
      expect(doc['fixtureId'], 'fx1');
      expect(doc['homeGuess'], 2);
      expect(doc['awayGuess'], 1);
      // The rules reject a create that pre-awards points or arrives locked.
      expect(doc['pointsEarned'], 0);
      expect(doc['locked'], false);
    });

    test('refuses to write once the lock window has opened', () async {
      await expectLater(
        service.submitPrediction(
          userId: 'alice',
          fixture: lockedFixture(),
          homeGuess: 2,
          awayGuess: 1,
        ),
        throwsA(isA<Exception>()),
      );

      expect(await stored('alice_fx1'), isNull);
    });

    test('editing updates the scoreline in place', () async {
      final fixture = openFixture();
      await service.submitPrediction(
        userId: 'alice',
        fixture: fixture,
        homeGuess: 2,
        awayGuess: 1,
      );
      await service.submitPrediction(
        userId: 'alice',
        fixture: fixture,
        homeGuess: 3,
        awayGuess: 0,
      );

      final doc = await stored('alice_fx1');
      expect(doc!['homeGuess'], 3);
      expect(doc['awayGuess'], 0);

      // One document per user per fixture, not two.
      final all = await db.collection('predictions').get();
      expect(all.docs, hasLength(1));
    });

    test('editing preserves the server-managed fields', () async {
      final fixture = openFixture();
      await service.submitPrediction(
        userId: 'alice',
        fixture: fixture,
        homeGuess: 2,
        awayGuess: 1,
      );

      // Simulate the server having scored this prediction already.
      await db
          .collection('predictions')
          .doc('alice_fx1')
          .update({'pointsEarned': 5, 'locked': true});

      await service.submitPrediction(
        userId: 'alice',
        fixture: fixture,
        homeGuess: 4,
        awayGuess: 4,
      );

      final doc = await stored('alice_fx1');
      // An edit must not reset these — overwriting them with `set` is exactly
      // what the rules reject, and is why editing never worked.
      expect(doc!['pointsEarned'], 5);
      expect(doc['locked'], true);
    });

    test('keeps different users predictions separate', () async {
      final fixture = openFixture();
      await service.submitPrediction(
        userId: 'alice',
        fixture: fixture,
        homeGuess: 2,
        awayGuess: 1,
      );
      await service.submitPrediction(
        userId: 'bob',
        fixture: fixture,
        homeGuess: 0,
        awayGuess: 0,
      );

      expect((await stored('alice_fx1'))!['homeGuess'], 2);
      expect((await stored('bob_fx1'))!['homeGuess'], 0);
    });

    test('keeps one users predictions on different fixtures separate',
        () async {
      await service.submitPrediction(
        userId: 'alice',
        fixture: openFixture(),
        homeGuess: 2,
        awayGuess: 1,
      );
      await service.submitPrediction(
        userId: 'alice',
        fixture: openFixture(id: 'fx2'),
        homeGuess: 1,
        awayGuess: 1,
      );

      final all = await db.collection('predictions').get();
      expect(all.docs, hasLength(2));
    });
  });

  group('userPredictions', () {
    test('emits only the requested user predictions', () async {
      final fixture = openFixture();
      await service.submitPrediction(
        userId: 'alice',
        fixture: fixture,
        homeGuess: 2,
        awayGuess: 1,
      );
      await service.submitPrediction(
        userId: 'bob',
        fixture: fixture,
        homeGuess: 0,
        awayGuess: 0,
      );

      final predictions = await service.userPredictions('alice').first;

      expect(predictions, hasLength(1));
      expect(predictions.single.userId, 'alice');
    });

    test('emits an empty list for a user with no predictions', () async {
      expect(await service.userPredictions('nobody').first, isEmpty);
    });
  });

  group('document ids', () {
    test('are derived from user and fixture so a resubmit overwrites',
        () async {
      final fixture = openFixture();
      for (var i = 0; i < 3; i++) {
        await service.submitPrediction(
          userId: 'alice',
          fixture: fixture,
          homeGuess: i,
          awayGuess: 0,
        );
      }

      final all = await db.collection('predictions').get();
      expect(all.docs, hasLength(1));
      expect(all.docs.single.id, 'alice_fx1');
      expect(all.docs.single.data()['homeGuess'], 2);
    });
  });
}
