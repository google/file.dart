// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:file/src/io.dart' as io;

/// Internal implementation of [io.FileStat].
class MemoryFileStat implements io.FileStat {
  /// Shared instance representing a non-existent entity.
  static const MemoryFileStat notFound =
      const MemoryFileStat._internalNotFound();

  @override
  final DateTime changed;

  @override
  final DateTime modified;

  @override
  final DateTime accessed;

  @override
  final io.FileSystemEntityType type;

  @override
  final int mode;

  @override
  final int size;

  /// Creates a new [MemoryFileStat] with the specified properties.
  const MemoryFileStat(
    this.changed,
    this.modified,
    this.accessed,
    this.type,
    this.mode,
    this.size,
  );

  const MemoryFileStat._internalNotFound()
      : changed = null,
        modified = null,
        accessed = null,
        type = io.FileSystemEntityType.NOT_FOUND,
        mode = 0,
        size = -1;

  @override
  String modeString() {
    int permissions = mode & 0xFFF;
    List<String> codes = const <String>[
      '---',
      '--x',
      '-w-',
      '-wx',
      'r--',
      'r-x',
      'rw-',
      'rwx',
    ];
    List<String> result = <String>[];
    result
      ..add(codes[(permissions >> 6) & 0x7])
      ..add(codes[(permissions >> 3) & 0x7])
      ..add(codes[permissions & 0x7]);
    return result.join();
  }
}