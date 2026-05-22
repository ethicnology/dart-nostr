// NIP-11 Relay Information Document
// Fetches a relay's metadata document over HTTPS and inspects what it
// advertises.

import 'package:nostr/nostr.dart';

Future<void> main() async {
  const relay = 'wss://relay.damus.io';

  final info = await RelayInfo.fetch(relay);
  if (info == null) {
    print('$relay did not return a NIP-11 document');
    return;
  }

  print('Relay: ${info.name ?? '(unnamed)'}');
  print('Description: ${info.description ?? ''}');
  print('Software: ${info.software ?? ''} ${info.version ?? ''}');
  print('Contact: ${info.contact ?? ''}');
  print('Supported NIPs: ${info.supportedNips}');
  print('Supports NIP-44? ${info.supports(44)}');
  print('Supports NIP-50 search? ${info.supports(50)}');

  final lim = info.limitation;
  if (lim != null) {
    print('\nLimits:');
    if (lim.maxMessageLength != null) {
      print('  max_message_length: ${lim.maxMessageLength}');
    }
    if (lim.maxSubscriptions != null) {
      print('  max_subscriptions: ${lim.maxSubscriptions}');
    }
    if (lim.authRequired != null) {
      print('  auth_required: ${lim.authRequired}');
    }
    if (lim.paymentRequired != null) {
      print('  payment_required: ${lim.paymentRequired}');
    }
  }
}
