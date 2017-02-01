// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:file/file.dart';
import 'package:meta/meta.dart';

import 'mutable_recording.dart';
import 'recording.dart';
import 'recording_directory.dart';
import 'recording_file.dart';
import 'recording_link.dart';
import 'recording_proxy_mixin.dart';

/// File system that records invocations for later playback in tests.
///
/// This will record all invocations (methods, property getters, and property
/// setters) that occur on it, in an opaque format that can later be used in
/// [ReplayFileSystem]. All activity in the [File], [Directory], [Link],
/// [IOSink], and [RandomAccessFile] instances returned from this API will also
/// be recorded.
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
///   - [ReplayFileSystem]
abstract class RecordingFileSystem extends FileSystem {
  /// Creates a new `RecordingFileSystem`.
  ///
  /// Invocations will be recorded and forwarded to the specified [delegate]
  /// file system.
  ///
  /// The recording will be serialized to the specified [destination] directory
  /// (only when `flush` is called on this file system's [recording]).
  ///
  /// If [stopwatch] is specified, it will be assumed to have already been
  /// started by the caller, and it will be used to record timestamps on each
  /// recorded invocation. If `stopwatch` is unspecified (or `null`), a new
  /// stopwatch will be created and started immediately to record these
  /// timestamps.
  factory RecordingFileSystem({
    @required FileSystem delegate,
    @required Directory destination,
    Stopwatch stopwatch,
  }) =>
      new RecordingFileSystemImpl(delegate, destination, stopwatch);

  /// The file system to which invocations will be forwarded upon recording.
  FileSystem get delegate;

  /// The recording generated by invocations on this file system.
  ///
  /// The recording provides access to the invocation events that have been
  /// recorded thus far, as well as the ability to flush them to disk.
  LiveRecording get recording;

  /// The stopwatch used to record timestamps on invocation events.
  ///
  /// Timestamps will be recorded before the delegate is invoked (not after
  /// the delegate returns).
  Stopwatch get stopwatch;
}

class RecordingFileSystemImpl extends FileSystem
    with RecordingProxyMixin
    implements RecordingFileSystem {
  RecordingFileSystemImpl(
      this.delegate, Directory destination, Stopwatch recordingStopwatch)
      : recording = new MutableRecording(destination),
        stopwatch = recordingStopwatch ?? new Stopwatch() {
    if (recordingStopwatch == null) {
      // We instantiated our own stopwatch, so start it ourselves.
      stopwatch.start();
    }

    methods.addAll(<Symbol, Function>{
      #directory: _directory,
      #file: _file,
      #link: _link,
      #stat: delegate.stat,
      #statSync: delegate.statSync,
      #identical: delegate.identical,
      #identicalSync: delegate.identicalSync,
      #type: delegate.type,
      #typeSync: delegate.typeSync,
    });

    properties.addAll(<Symbol, Function>{
      #path: () => delegate.path,
      #systemTempDirectory: _getSystemTempDirectory,
      #currentDirectory: _getCurrentDirectory,
      const Symbol('currentDirectory='): _setCurrentDirectory,
      #isWatchSupported: () => delegate.isWatchSupported,
    });
  }

  /// The file system to which invocations will be forwarded upon recording.
  @override
  final FileSystem delegate;

  /// The recording generated by invocations on this file system.
  @override
  final MutableRecording recording;

  /// The stopwatch used to record timestamps on invocation events.
  @override
  final Stopwatch stopwatch;

  Directory _directory(dynamic path) =>
      new RecordingDirectory(this, delegate.directory(path));

  File _file(dynamic path) => new RecordingFile(this, delegate.file(path));

  Link _link(dynamic path) => new RecordingLink(this, delegate.link(path));

  Directory _getSystemTempDirectory() =>
      new RecordingDirectory(this, delegate.systemTempDirectory);

  Directory _getCurrentDirectory() =>
      new RecordingDirectory(this, delegate.currentDirectory);

  void _setCurrentDirectory(dynamic value) {
    delegate.currentDirectory = value;
  }
}
