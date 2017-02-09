// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'common.dart';
import 'encoding.dart';

/// Error thrown during replay when there is no matching invocation in the
/// recording.
class NoMatchingInvocationError extends Error {
  /// The invocation that was unable to be replayed.
  final Invocation invocation;

  /// Creates a new `NoMatchingInvocationError` caused by the failure to replay
  /// the specified [invocation].
  NoMatchingInvocationError(this.invocation);

  @override
  String toString() {
    StringBuffer buf = new StringBuffer();
    buf.write('No matching invocation found: ');
    buf.write(getSymbolName(invocation.memberName));
    if (invocation.isMethod) {
      buf.write('(');
      int i = 0;
      for (dynamic arg in invocation.positionalArguments) {
        buf.write(Error.safeToString(encode(arg)));
        if (i++ > 0) {
          buf.write(', ');
        }
      }
      invocation.namedArguments.forEach((Symbol name, dynamic value) {
        if (i++ > 0) {
          buf.write(', ');
        }
        buf
          ..write(getSymbolName(name))
          ..write(': ')
          ..write(encode(value));
      });
      buf.write(')');
    } else if (invocation.isSetter) {
      buf.write(Error.safeToString(encode(invocation.positionalArguments[0])));
    }
    return buf.toString();
  }
}