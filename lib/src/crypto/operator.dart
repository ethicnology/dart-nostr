// credit: https://github.com/tjcampanella/kepler/blob/master/lib/src/operator.dart

import 'package:pointycastle/export.dart';

BigInt theP = BigInt.parse(
    "fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f",
    radix: 16);
BigInt theN = BigInt.parse(
    "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141",
    radix: 16);

bool isOnCurve(ECPoint point) {
  assert(point.x != null &&
      point.y != null &&
      point.curve.a != null &&
      point.curve.b != null);
  final x = point.x!.toBigInteger();
  final y = point.y!.toBigInteger();
  final rs = (y! * y -
          x! * x * x -
          point.curve.a!.toBigInteger()! * x -
          point.curve.b!.toBigInteger()!) %
      theP;
  return rs == BigInt.from(0);
}

BigInt inverseMod(BigInt k, BigInt p) {
  if (k.compareTo(BigInt.zero) == 0) {
    throw Exception("Cannot Divide By 0");
  }
  if (k < BigInt.from(0)) {
    return p - inverseMod(-k, p);
  }
  var s = [BigInt.from(0), BigInt.from(1), BigInt.from(1)];
  var t = [BigInt.from(1), BigInt.from(0), BigInt.from(0)];
  var r = [p, k, k];
  while (r[0] != BigInt.from(0)) {
    var quotient = r[2] ~/ r[0];
    r[1] = r[2] - quotient * r[0];
    r[2] = r[0];
    r[0] = r[1];
    s[1] = s[2] - quotient * s[0];
    s[2] = s[0];
    s[0] = s[1];
    t[1] = t[2] - quotient * t[0];
    t[2] = t[0];
    t[0] = t[1];
  }
  final gcd = r[2];
  final x = s[2];
  // final y = t[2];
  assert(gcd == BigInt.from(1));
  assert((k * x) % p == BigInt.from(1));
  return x % p;
}

ECPoint pointNeg(ECPoint point) {
  assert(isOnCurve(point));
  assert(point.x != null || point.y != null);
  final x = point.x!.toBigInteger();
  final y = point.y!.toBigInteger();
  final result = point.curve.createPoint(x!, -y! % theP);
  assert(isOnCurve(result));
  return result;
}

ECPoint pointAdd(ECPoint? point1, ECPoint? point2) {
  if (point1 == null) {
    return point2!;
  }
  if (point2 == null) {
    return point1;
  }
  assert(isOnCurve(point1));
  assert(isOnCurve(point2));
  final x1 = point1.x!.toBigInteger();
  final y1 = point1.y!.toBigInteger();
  final x2 = point2.x!.toBigInteger();
  final y2 = point2.y!.toBigInteger();

  BigInt m;
  if (x1 == x2) {
    m = (BigInt.from(3) * x1! * x1 + point1.curve.a!.toBigInteger()!) *
        inverseMod(BigInt.from(2) * y1!, theP);
  } else {
    m = (y1! - y2!) * inverseMod(x1! - x2!, theP);
  }
  final x3 = m * m - x1 - x2!;
  final y3 = y1 + m * (x3 - x1);
  ECPoint result = point1.curve.createPoint(x3 % theP, -y3 % theP);
  assert(isOnCurve(result));
  return result;
}

ECPoint scalarMultiple(BigInt k, ECPoint point) {
  assert(isOnCurve(point));
  assert((k % theN).compareTo(BigInt.zero) != 0);
  assert(point.x != null && point.y != null);
  if (k < BigInt.from(0)) {
    return scalarMultiple(-k, pointNeg(point));
  }
  ECPoint? result;
  ECPoint addend = point;
  while (k > BigInt.from(0)) {
    if (k & BigInt.from(1) > BigInt.from(0)) {
      result = pointAdd(result, addend);
    }
    addend = pointAdd(addend, addend);
    k >>= 1;
  }
  assert(isOnCurve(result!));
  return result!;
}
