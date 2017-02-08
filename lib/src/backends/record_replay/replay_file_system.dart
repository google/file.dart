// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:file/file.dart';
import 'package:meta/meta.dart';

import 'common.dart';
import 'errors.dart';
import 'recording_file_system.dart';
import 'replay_directory.dart';
import 'replay_file.dart';
import 'replay_link.dart';
import 'replay_proxy_mixin.dart';
import 'resurrectors.dart';

/// A file system that replays invocations from a prior recording for use
/// in tests.
///
/// This will replay all invocations (methods, property getters, and property
/// setters) that occur on it, based on an opaque recording that was generated
/// in [RecordingFileSystem]. All activity in the [File], [Directory], [Link],
/// [IOSink], and [RandomAccessFile] instances returned from this API will also
/// be played form the same recording.
///
/// Once an invocation has been replayed once, it is marked as such and will
/// not be eligible for further replay. If an eligible invocation cannot be
/// found that matches an incoming invocation, a [NoMatchingInvocationError]
/// will be thrown.
///
/// This class is intended for use in tests, where you would otherwise have to
/// set up complex mocks or fake file systems. With this class, the process is
/// as follows:
///
///   - You record the file system activity during a real run of your program
///     by injecting a `RecordingFileSystem` that delegates to your real file
///     system.
///   - You serialize that recording to disk as your program finishes.
///   - You use that recording in tests to create a mock file system that knows
///     how to respond to the exact invocations your program makes. Any
///     invocations that aren't in the recording will throw, and you can make
///     assertions in your tests about which methods were invoked and in what
///     order.
///
/// See also:
///   - [RecordingFileSystem]
abstract class ReplayFileSystem extends FileSystem {
  /// Creates a new `ReplayFileSystem`.
  ///
  /// Recording data will be loaded from the specified [recording] location.
  /// This location must have been created by [RecordingFileSystem], or an
  /// [ArgumentError] will be thrown.
  factory ReplayFileSystem({
    @required Directory recording,
  }) {
    String dirname = recording.path;
    String path = recording.fileSystem.path.join(dirname, kManifestName);
    File manifestFile = recording.fileSystem.file(path);
    if (!manifestFile.existsSync()) {
      throw new ArgumentError('Not a valid recording directory: $dirname');
    }
    List<Map<String, dynamic>> manifest =
        new JsonDecoder().convert(manifestFile.readAsStringSync());
    return new ReplayFileSystemImpl(manifest);
  }
}

/// Non-exported implementation class for `ReplayFileSystem`.
class ReplayFileSystemImpl extends FileSystem
    with ReplayProxyMixin
    implements ReplayFileSystem {
  final Map<String, Object> _objects = <String, Object>{};

  /// Creates a new `ReplayFileSystemImpl`.
  ReplayFileSystemImpl(this.manifest) {
    methods.addAll(<Symbol, Resurrector>{
      #directory: _resurrectDirectory,
      #file: _resurrectFile,
      #link: _resurrectLink,
      #stat: resurrectFuture(resurrectFileStat),
      #statSync: resurrectFileStat,
      #identical: resurrectFuture(resurrectPassthrough),
      #identicalSync: resurrectPassthrough,
      #type: resurrectFuture(resurrectFileSystemEntityType),
      #typeSync: resurrectFileSystemEntityType,
    });

    properties.addAll(<Symbol, Resurrector>{
      #path: resurrectPathContext,
      #systemTempDirectory: _resurrectDirectory,
      #currentDirectory: _resurrectDirectory,
      const Symbol('currentDirectory='): resurrectPassthrough,
      #isWatchSupported: resurrectPassthrough,
    });
  }

  @override
  String get identifier => kFileSystemEncodedValue;

  @override
  final List<Map<String, dynamic>> manifest;

  Object _resurrectDirectory(String identifier) {
    return _objects.putIfAbsent(identifier, () {
      return new ReplayDirectory(this, identifier);
    });
  }

  Object _resurrectFile(String identifier) {
    return _objects.putIfAbsent(identifier, () {
      return new ReplayFile(this, identifier);
    });
  }

  Object _resurrectLink(String identifier) {
    return _objects.putIfAbsent(identifier, () {
      return new ReplayLink(this, identifier);
    });
  }
}
