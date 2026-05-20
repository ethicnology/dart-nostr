// Contract test: every public deserialization / decode entrypoint must
// throw a [NostrException] subclass — never a raw FormatException, a
// _TypeError from a failed cast, or the `package:bech32` exception
// hierarchy. The library promises (in `error.dart`) that callers can
// catch all errors with `on NostrException`.
//
// If you add a new public entrypoint that takes untrusted input, add a
// case here.

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Bech32Entity.decode wraps package:bech32 errors', () {
    for (final input in <String>[
      '',
      'aaaa1',
      'totallygarbage',
      'not_bech32_at_all!!!',
      'npub1qqq',
      'npub1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'NPUBqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
    ]) {
      test('"$input" throws DeserializationException', () {
        expect(
          () => Bech32Entity.decode(payload: input),
          throwsA(isA<DeserializationException>()),
        );
      });
    }

    test('payload exceeding NIP-19 soft cap throws', () {
      expect(
        () => Bech32Entity.decode(payload: 'npub1${'q' * 6000}'),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('Bech32Entity.encode wraps non-hex input', () {
    test('non-hex data throws DeserializationException', () {
      expect(
        () => Bech32Entity.encode(prefix: Nip19Prefix.npub, data: 'not hex!'),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('Schnorr wraps non-hex / wrong-length input', () {
    test('derivePublicKey with non-hex throws InvalidKeyException', () {
      expect(
        () => Schnorr.derivePublicKey('zz' * 32),
        throwsA(isA<InvalidKeyException>()),
      );
    });

    test('sign with non-hex message throws InvalidKeyException', () {
      expect(
        () => Schnorr.sign(secretKey: 'a' * 64, message: 'plain text'),
        throwsA(isA<InvalidKeyException>()),
      );
    });

    test('verify with non-hex pubkey throws InvalidKeyException', () {
      expect(
        () => Schnorr.verify(
          publicKey: 'zz',
          message: 'a' * 64,
          signature: 'b' * 128,
        ),
        throwsA(isA<InvalidKeyException>()),
      );
    });
  });

  group('Event.fromJson wraps JSON errors', () {
    test('non-JSON input throws DeserializationException', () {
      expect(
        () => Event.fromJson('not json at all'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('decodes to non-object throws DeserializationException', () {
      expect(
        () => Event.fromJson('[]'),
        throwsA(isA<DeserializationException>()),
      );
      expect(
        () => Event.fromJson('"hello"'),
        throwsA(isA<DeserializationException>()),
      );
      expect(
        () => Event.fromJson('null'),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('Event.deserialize wraps wire-frame errors', () {
    test('non-JSON throws DeserializationException', () {
      expect(
        () => Event.deserialize('bad input'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('frame missing "EVENT" tag throws', () {
      expect(
        () => Event.deserialize('["NOTEVENT", {}]'),
        throwsA(isA<DeserializationException>()),
      );
      expect(
        () => Event.deserialize('["CLOSED", "sub"]'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('frame with wrong shape throws', () {
      expect(
        () => Event.deserialize('["EVENT"]'),
        throwsA(isA<DeserializationException>()),
      );
      expect(
        () => Event.deserialize('["EVENT", "sub", null]'),
        throwsA(isA<DeserializationException>()),
      );
      expect(
        () => Event.deserialize('["EVENT", 42]'),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('Filter.fromMap rejects wrong-typed fields', () {
    test('kinds is a string', () {
      expect(
        () => Filter.fromMap({'kinds': 'not a list'}),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('ids contains non-strings', () {
      expect(
        () => Filter.fromMap({
          'ids': [1, 2, 3]
        }),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('since is a string', () {
      expect(
        () => Filter.fromMap({'since': 'now'}),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('search is an int', () {
      expect(
        () => Filter.fromMap({'search': 42}),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('Request / Close / Eose / Message wrap JSON + shape errors', () {
    test('Request.deserialize on non-JSON throws', () {
      expect(
        () => Request.deserialize('not json'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('Request.deserialize on non-array throws', () {
      expect(
        () => Request.deserialize('{"foo":1}'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('Close.deserialize on non-JSON throws', () {
      expect(
        () => Close.deserialize('not json'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('Close.deserialize with wrong tag throws', () {
      expect(
        () => Close.deserialize('["EVENT", "sub"]'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('Eose.deserialize on non-JSON throws', () {
      expect(
        () => Eose.deserialize('not json'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('Eose.deserialize with wrong tag throws', () {
      expect(
        () => Eose.deserialize('["CLOSE", "sub"]'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('Message.deserialize on non-JSON throws', () {
      expect(
        () => Message.deserialize('not json'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('Message.deserialize on empty array throws', () {
      expect(
        () => Message.deserialize('[]'),
        throwsA(isA<DeserializationException>()),
      );
    });
  });

  group('NIP-specific parse paths wrap upstream errors', () {
    Event makeEvent(int kind, String content,
        [List<List<String>> tags = const []]) {
      final keys = Keys('a' * 64);
      return Event.from(
        kind: kind,
        tags: tags,
        content: content,
        secretKey: keys.secret,
      );
    }

    test('CommandResult.deserialize bad JSON throws', () {
      expect(
        () => CommandResult.deserialize('not json'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('CommandResult.deserialize wrong shape throws', () {
      expect(
        () => CommandResult.deserialize('["EVENT", "x"]'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('PublicChat.parseChannel with non-JSON content throws', () {
      expect(
        () => PublicChat.parseChannel(makeEvent(40, 'not json')),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('PublicChat.parseMetadata with non-JSON content throws', () {
      expect(
        () => PublicChat.parseMetadata(
          makeEvent(41, 'not json', [
            ['e', 'a' * 64]
          ]),
        ),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('PublicChat.parseChannel with JSON array content throws', () {
      expect(
        () => PublicChat.parseChannel(makeEvent(40, '[1,2,3]')),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('ProofOfWork.countLeadingZeroes with non-hex throws', () {
      expect(
        () => ProofOfWork.countLeadingZeroes('zz'),
        throwsA(isA<DeserializationException>()),
      );
    });

    test('ModeratedCommunity.parseApproval with array content does not leak',
        () {
      final ev = makeEvent(4550, '[1,2,3]', [
        ['a', '34550:${'a' * 64}:test'],
        ['e', 'a' * 64],
        ['k', '1'],
        ['p', 'a' * 64],
      ]);
      // Should leave approvedEvent null silently — must not throw _TypeError.
      expect(() => ModeratedCommunity.parseApproval(ev), returnsNormally);
    });

    test('AppHandler.parseHandlerInfo with array content does not leak', () {
      final ev = makeEvent(31990, '[1,2,3]', [
        ['d', 'app'],
        ['k', '1']
      ]);
      expect(() => AppHandler.parseHandlerInfo(ev), returnsNormally);
    });

    test('Zap.parseReceipt with array description does not leak', () {
      final ev = makeEvent(9735, '', [
        ['bolt11', 'lnbc1x'],
        ['description', '[1,2,3]'],
        ['p', 'a' * 64],
      ]);
      expect(() => Zap.parseReceipt(ev), returnsNormally);
    });
  });

  group('Error messages do not echo candidate secrets', () {
    test('Keys() rejection does not include the input', () {
      // Mixed-case bech32 triggers `MixedCase` in `package:bech32`, whose
      // raw message would normally echo the input back. The Keys ctor
      // must suppress that so candidate secrets never reach logs.
      final candidate =
          'NSEC1${'q' * 50}xyzAAAAAA'; // mixed case, fake but plausible
      try {
        Keys(candidate);
        fail('expected InvalidKeyException');
      } on InvalidKeyException catch (e) {
        expect(e.message.contains(candidate), isFalse,
            reason: 'error message must not echo the candidate input');
        expect(e.message.contains('qqqqq'), isFalse,
            reason: 'error message must not echo body of the candidate');
      }
    });

    test('InvalidNostrUriException does not echo input in message', () {
      final fakeNsec = 'nsec1${'q' * 50}leakplease';
      try {
        NostrUri.decode(fakeNsec);
        fail('expected InvalidNostrUriException');
      } on InvalidNostrUriException catch (e) {
        expect(e.toString().contains('leakplease'), isFalse);
        // Field is still available for callers that need it.
        expect(e.input, fakeNsec);
      }
    });

    test('Bech32Entity.decode error message does not echo input', () {
      const candidate = 'MIXEDcase1xyzaaaaaaleakplease';
      try {
        Bech32Entity.decode(payload: candidate);
        fail('expected DeserializationException');
      } on DeserializationException catch (e) {
        expect(e.message.contains('leakplease'), isFalse);
      }
    });
  });

  group('NIP-19 encodeShareableIdentifiers validates kind range', () {
    // setUint32 silently masks to 32 bits — a too-large kind would
    // round-trip to a different value without this guard.
    test('rejects kind > 2^32-1', () {
      expect(
        () => Bech32Entity.encodeShareableIdentifiers(
          prefix: Nip19Prefix.nevent,
          data: 'a' * 64,
          kind: 0x100000000, // 2^32
        ),
        throwsA(isA<InvalidArgumentException>()),
      );
    });

    test('rejects negative kind', () {
      expect(
        () => Bech32Entity.encodeShareableIdentifiers(
          prefix: Nip19Prefix.nevent,
          data: 'a' * 64,
          kind: -1,
        ),
        throwsA(isA<InvalidArgumentException>()),
      );
    });

    test('accepts kind = 2^32-1 (uint32 max)', () {
      expect(
        () => Bech32Entity.encodeShareableIdentifiers(
          prefix: Nip19Prefix.nevent,
          data: 'a' * 64,
          kind: 0xFFFFFFFF,
        ),
        returnsNormally,
      );
    });
  });

  group('NIP-29 group metadata flag presence', () {
    Event metadataEvent(List<List<String>> tags) {
      return Event.from(
        kind: Group.kindGroupMetadata,
        tags: [
          ['d', 'g'],
          ...tags
        ],
        content: '',
        secretKey: 'a' * 64,
      );
    }

    test('parses all five flags independently', () {
      final m = Group.parseMetadata(metadataEvent([
        ['open'],
        ['closed'],
        ['public'],
        ['private'],
        ['broadcast'],
      ]));
      expect(m.isOpen, isTrue);
      expect(m.isClosed, isTrue);
      expect(m.isPublic, isTrue);
      expect(m.isPrivate, isTrue);
      expect(m.isBroadcast, isTrue);
    });

    test('no flags present → all false', () {
      final m = Group.parseMetadata(metadataEvent(const []));
      expect(m.isOpen, isFalse);
      expect(m.isClosed, isFalse);
      expect(m.isPublic, isFalse);
      expect(m.isPrivate, isFalse);
      expect(m.isBroadcast, isFalse);
    });
  });

  group('NIP-005 / NIP-019 error messages do not echo input', () {
    test('NIP-05 parse of malformed JSON does not leak content', () async {
      final event = Event.from(
        kind: Note.kindMetadata,
        content: 'leakme-not-json-{{}',
        secretKey: 'a' * 64,
      );
      try {
        await DnsIdentifier.parse(event);
        fail('expected DeserializationException');
      } on DeserializationException catch (e) {
        expect(e.message.contains('leakme'), isFalse);
      }
    });

    test('Bech32Entity.decodeShareableIdentifiers rejects garbage cleanly', () {
      try {
        Bech32Entity.decodeShareableIdentifiers(
          payload: 'nprofile1leakplease',
        );
        fail('expected DeserializationException');
      } on DeserializationException catch (e) {
        expect(e.message.contains('leakplease'), isFalse);
      }
    });
  });

  group('NIP-57 Zap.request validates amount', () {
    final sk = 'a' * 64;
    final pk = 'b' * 64;

    test('rejects negative amount on request', () {
      expect(
        () => Zap.request(
          recipientPubkey: pk,
          relays: const ['wss://relay.example'],
          secretKey: sk,
          amount: BigInt.from(-1),
        ),
        throwsA(isA<InvalidArgumentException>()),
      );
    });

    test('rejects negative amount on anonymousRequest', () {
      expect(
        () => Zap.anonymousRequest(
          recipientPubkey: pk,
          relays: const ['wss://relay.example'],
          amount: BigInt.from(-1000),
        ),
        throwsA(isA<InvalidArgumentException>()),
      );
    });

    test('preserves amount > 2^53 (web-safe via BigInt)', () {
      // 10^16 millisats = 100 000 BTC — outside JS safe-int range.
      final big = BigInt.parse('10000000000000000');
      final event = Zap.request(
        recipientPubkey: pk,
        relays: const ['wss://relay.example'],
        secretKey: sk,
        amount: big,
      );
      final parsed = Zap.parseRequest(event);
      expect(parsed.amount, equals(big));
    });
  });
}
