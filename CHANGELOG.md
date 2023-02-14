## 1.0.0

- Initial version.

## 1.0.1

- Fix createdAt initialization
- Add asserts
- Code comments

## 1.1.0

- fix Event.fromJson
- add subscriptionId
- deserialization of NOSTR formatted events with or without subscription_id
- add unit tests for Event to improve coverage
- Create Keychain container for private/public keys to encapsulate bip340 and add handy methods.
- Documentation

## 1.2.0

- add Filters (+ unit tests)
- add Request (+ unit tests)
- Documentation

## 1.3.0

- add Close (+ unit tests)
- add Message wrapper deserializer (+ unit tests)
- Documentation

## 1.3.1

- fix: Inconsitency in events is breaking tags

## 1.3.2

- refactor: Event with optional verification
- remove tests with encoding problem
- improve coverage

## 1.3.3

- add comments about verify and fix typo
- nip 002 implementation, unit tests, examples and documentation
- Event.partial to init an empty event that you validate later, documentation

## 1.3.4

- fix: pending bip340 issue
- test: Update test to check public key
- refactor: Event partial and from to factories
