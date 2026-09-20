// test/atomic/nivel_1/pion_logging_atomic_tests.dart
// Testes atomicos 1 para 1 para transpiled_pion_logging (github com/pion/logging,
// revisao fixada em doc/transpilation/UPSTREAM_LOCK md) Vetores de mensagem
// contida no buffer adaptados de go-ipfs-reference/pion-logging/logging_test go
// (testDebugLevel, testWarnLevel, testErrorLevel, testTraceLevel, testInfoLevel,
// testNoDebugLevel) Nivel 1: codec/formatacao puros e uma StringSink em
// memoria, sem I/O real.

import 'package:test/test.dart';
import 'package:transpiled_pion_logging/transpiled_pion_logging.dart';

void main() {
  group('LogLevel [Atomic Audit]', () {
    test('value() - reflete a ordinal iota do Go: Disabled=0 ate Trace=5', () {
      expect(LogLevel.disabled.value, equals(0));
      expect(LogLevel.error.value, equals(1));
      expect(LogLevel.warn.value, equals(2));
      expect(LogLevel.info.value, equals(3));
      expect(LogLevel.debug.value, equals(4));
      expect(LogLevel.trace.value, equals(5));
    });

    test('toString() - Disabled', () {
      expect(LogLevel.disabled.toString(), equals('Disabled'));
    });

    test('toString() - Error', () {
      expect(LogLevel.error.toString(), equals('Error'));
    });

    test('toString() - Warn', () {
      expect(LogLevel.warn.toString(), equals('Warn'));
    });

    test('toString() - Info', () {
      expect(LogLevel.info.toString(), equals('Info'));
    });

    test('toString() - Debug', () {
      expect(LogLevel.debug.toString(), equals('Debug'));
    });

    test('toString() - Trace', () {
      expect(LogLevel.trace.toString(), equals('Trace'));
    });

    test('compareTo() - ordena os niveis do menos para o mais verboso', () {
      expect(LogLevel.disabled.compareTo(LogLevel.trace), lessThan(0));
      expect(LogLevel.trace.compareTo(LogLevel.disabled), greaterThan(0));
      expect(LogLevel.info.compareTo(LogLevel.info), equals(0));
    });

    test('operator <() - error e menor que warn', () {
      expect(LogLevel.error < LogLevel.warn, isTrue);
      expect(LogLevel.warn < LogLevel.error, isFalse);
    });

    test('operator <=() - error e menor ou igual a error', () {
      expect(LogLevel.error <= LogLevel.error, isTrue);
      expect(LogLevel.warn <= LogLevel.error, isFalse);
    });

    test('operator >() - warn e maior que error', () {
      expect(LogLevel.warn > LogLevel.error, isTrue);
      expect(LogLevel.error > LogLevel.warn, isFalse);
    });

    test('operator >=() - warn e maior ou igual a warn', () {
      expect(LogLevel.warn >= LogLevel.warn, isTrue);
      expect(LogLevel.error >= LogLevel.warn, isFalse);
    });

    test('operator ==() - dois niveis com o mesmo value sao iguais', () {
      final levels = [LogLevel.trace, LogLevel.debug, LogLevel.info];
      final found = levels.firstWhere((l) => l.value == 4);
      expect(found == LogLevel.debug, isTrue);
      expect(LogLevel.debug == LogLevel.info, isFalse);
    });

    test('hashCode() - dois niveis iguais produzem o mesmo hash', () {
      final levels = [LogLevel.trace, LogLevel.debug, LogLevel.info];
      final found = levels.firstWhere((l) => l.value == 4);
      expect(found.hashCode, equals(LogLevel.debug.hashCode));
    });
  });

  group('LeveledLogger [Atomic Audit]', () {
    test('trace() - emite quando o nivel permite, porta testTraceLevel', () {
      final buffer = StringBuffer();
      final LeveledLogger logger = DefaultLeveledLogger.forScope('s', LogLevel.trace, buffer);
      logger.trace('trace message');
      expect(buffer.toString(), contains('trace message'));
    });

    test('tracef() - formata os argumentos na mensagem', () {
      final buffer = StringBuffer();
      final LeveledLogger logger = DefaultLeveledLogger.forScope('s', LogLevel.trace, buffer);
      logger.tracef('trace %s', ['message']);
      expect(buffer.toString(), contains('trace message'));
    });

    test('debug() - suprimido quando o nivel e menor, porta testNoDebugLevel', () {
      final buffer = StringBuffer();
      final LeveledLogger logger = DefaultLeveledLogger.forScope('s', LogLevel.error, buffer);
      logger.debug("this shouldn't be logged");
      expect(buffer.toString(), isEmpty);
    });

    test('debugf() - suprimido quando o nivel e menor, porta testNoDebugLevel', () {
      final buffer = StringBuffer();
      final LeveledLogger logger = DefaultLeveledLogger.forScope('s', LogLevel.error, buffer);
      logger.debugf("this shouldn't be logged");
      expect(buffer.toString(), isEmpty);
    });

    test('info() - emite a mensagem, porta testInfoLevel', () {
      final buffer = StringBuffer();
      final LeveledLogger logger = DefaultLeveledLogger.forScope('s', LogLevel.info, buffer);
      logger.info('this is an info message');
      expect(buffer.toString(), contains('this is an info message'));
    });

    test('infof() - substitui verbos %s %d %x %q na ordem dos argumentos', () {
      final buffer = StringBuffer();
      final LeveledLogger logger = DefaultLeveledLogger.forScope('s', LogLevel.info, buffer);
      logger.infof('%s has %d items 0x%x %q', ['cart', 3, 255, 'ok']);
      expect(buffer.toString(), contains('cart has 3 items 0xff "ok"'));
    });

    test('warn() - emite a mensagem, porta testWarnLevel', () {
      final buffer = StringBuffer();
      final LeveledLogger logger = DefaultLeveledLogger.forScope('s', LogLevel.warn, buffer);
      logger.warn('this is a warning message');
      expect(buffer.toString(), contains('this is a warning message'));
      expect(buffer.toString(), contains('WARNING: '));
    });

    test('warnf() - emite a mensagem formatada, porta testWarnLevel', () {
      final buffer = StringBuffer();
      final LeveledLogger logger = DefaultLeveledLogger.forScope('s', LogLevel.warn, buffer);
      logger.warnf('this is a warning message');
      expect(buffer.toString(), contains('this is a warning message'));
    });

    test('error() - emite a mensagem, porta testErrorLevel', () {
      final buffer = StringBuffer();
      final LeveledLogger logger = DefaultLeveledLogger.forScope('s', LogLevel.error, buffer);
      logger.error('this is an error message');
      expect(buffer.toString(), contains('this is an error message'));
    });

    test('errorf() - emite a mensagem formatada, porta testErrorLevel', () {
      final buffer = StringBuffer();
      final LeveledLogger logger = DefaultLeveledLogger.forScope('s', LogLevel.error, buffer);
      logger.errorf('this is an error message');
      expect(buffer.toString(), contains('this is an error message'));
    });
  });

  group('LoggerFactory [Atomic Audit]', () {
    test('newLogger() - retorna um LeveledLogger para o escopo dado', () {
      final buffer = StringBuffer();
      final concrete = DefaultLoggerFactory()
        ..defaultLogLevel = LogLevel.info
        ..writer = buffer;
      final LoggerFactory factory = concrete;
      final logger = factory.newLogger('my-scope');
      logger.info('via factory');
      expect(buffer.toString(), contains('my-scope INFO: '));
      expect(buffer.toString(), contains('via factory'));
    });
  });

  group('DefaultLeveledLogger [Atomic Audit]', () {
    test('forScope() - porta NewDefaultLeveledLoggerForScope, escreve com o prefixo do escopo', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('scope', LogLevel.info, buffer);
      logger.info('hello');
      expect(buffer.toString(), contains('scope INFO: '));
    });

    test('trace() - emite quando o nivel do logger concreto permite', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.trace, buffer);
      logger.trace('trace message');
      expect(buffer.toString(), contains('trace message'));
    });

    test('tracef() - emite a mensagem formatada no logger concreto', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.trace, buffer);
      logger.tracef('trace message');
      expect(buffer.toString(), contains('trace message'));
    });

    test('debug() - emite quando o nivel do logger concreto permite', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.debug, buffer);
      logger.debug('this is a debug message');
      expect(buffer.toString(), contains('this is a debug message'));
    });

    test('debugf() - emite a mensagem formatada no logger concreto', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.debug, buffer);
      logger.debugf('this is a debug message');
      expect(buffer.toString(), contains('this is a debug message'));
    });

    test('info() - emite quando o nivel do logger concreto permite', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.info, buffer);
      logger.info('this is an info message');
      expect(buffer.toString(), contains('this is an info message'));
    });

    test('infof() - emite a mensagem formatada no logger concreto', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.info, buffer);
      logger.infof('this is an info message');
      expect(buffer.toString(), contains('this is an info message'));
    });

    test('warn() - emite quando o nivel do logger concreto permite', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.warn, buffer);
      logger.warn('this is a warning message');
      expect(buffer.toString(), contains('this is a warning message'));
    });

    test('warnf() - emite a mensagem formatada no logger concreto', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.warn, buffer);
      logger.warnf('this is a warning message');
      expect(buffer.toString(), contains('this is a warning message'));
    });

    test('error() - emite quando o nivel do logger concreto permite', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.error, buffer);
      logger.error('this is an error message');
      expect(buffer.toString(), contains('this is an error message'));
    });

    test('errorf() - emite a mensagem formatada no logger concreto', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.error, buffer);
      logger.errorf('this is an error message');
      expect(buffer.toString(), contains('this is an error message'));
    });

    test('setLevel() - eleva o nivel em tempo de execucao', () {
      final buffer = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.error, buffer);
      logger.info('suppressed at Error level');
      expect(buffer.toString(), isEmpty);

      logger.setLevel(LogLevel.info);
      logger.info('now visible');
      expect(buffer.toString(), contains('now visible'));
    });

    test('withOutput() - troca o destino em tempo de execucao e retorna this para encadear', () {
      final first = StringBuffer();
      final second = StringBuffer();
      final logger = DefaultLeveledLogger.forScope('s', LogLevel.info, first);

      final chained = logger.withOutput(second);
      expect(identical(chained, logger), isTrue);

      logger.info('to second');
      expect(first.toString(), isEmpty);
      expect(second.toString(), contains('to second'));
    });
  });

  group('DefaultLoggerFactory [Atomic Audit]', () {
    test('DefaultLoggerFactory() - porta NewDefaultLoggerFactory, defaultLogLevel comeca em Error', () {
      final factory = DefaultLoggerFactory();
      expect(factory.defaultLogLevel, equals(LogLevel.error));
      expect(factory.scopeLevels, isEmpty);
    });

    test('newLogger() - usa defaultLogLevel quando o escopo nao tem override', () {
      final factory = DefaultLoggerFactory()..defaultLogLevel = LogLevel.info;
      final buffer = StringBuffer();
      factory.writer = buffer;

      final logger = factory.newLogger('my-scope');
      logger.info('via factory');
      expect(buffer.toString(), contains('my-scope INFO: '));
      expect(buffer.toString(), contains('via factory'));
    });

    test('newLogger() - scopeLevels sobrepoe defaultLogLevel para o escopo dado', () {
      final factory = DefaultLoggerFactory()
        ..defaultLogLevel = LogLevel.error
        ..scopeLevels['verbose-scope'] = LogLevel.trace;
      final buffer = StringBuffer();
      factory.writer = buffer;

      final logger = factory.newLogger('verbose-scope');
      logger.trace('trace visible for this scope');
      expect(buffer.toString(), contains('trace visible for this scope'));

      final otherBuffer = StringBuffer();
      factory.writer = otherBuffer;
      final other = factory.newLogger('other-scope');
      other.trace('should be suppressed by defaultLogLevel Error');
      expect(otherBuffer.toString(), isEmpty);
    });
  });
}
