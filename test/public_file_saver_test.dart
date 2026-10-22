import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:public_file_saver/public_file_saver.dart';
import 'package:public_file_saver/src/content_disposition.dart';

void main() {
  group('sanitizeFileName', () {
    test('replaces illegal characters', () {
      expect(
        PublicFileSaver.sanitizeFileName(r'a/b\c:d*e?f"g<h>i|j.txt'),
        'a_b_c_d_e_f_g_h_i_j.txt',
      );
    });

    test('replaces control characters and trims whitespace', () {
      expect(
          PublicFileSaver.sanitizeFileName('  hi\x01\x02.txt  '), 'hi__.txt');
    });

    test('falls back to "file" for empty names', () {
      expect(PublicFileSaver.sanitizeFileName('   '), 'file');
    });

    test('replaces trailing dots', () {
      expect(PublicFileSaver.sanitizeFileName('report.pdf.'), 'report.pdf_');
      expect(PublicFileSaver.sanitizeFileName('..'), '_');
    });

    test('caps overlong names', () {
      final long = 'x' * 300;
      expect(PublicFileSaver.sanitizeFileName(long).length, 240);
    });

    test('caps names by UTF-8 bytes without splitting characters', () {
      final sanitized = PublicFileSaver.sanitizeFileName('测' * 100);
      expect(utf8.encode(sanitized).length, lessThanOrEqualTo(240));
      expect(sanitized, '测' * 80);
    });

    test('prefixes Windows reserved device names', () {
      expect(PublicFileSaver.sanitizeFileName('CON'), '_CON');
      expect(PublicFileSaver.sanitizeFileName('nul.txt'), '_nul.txt');
      expect(PublicFileSaver.sanitizeFileName('report.con'), 'report.con');
    });
  });

  group('sanitizeSubDir', () {
    test('returns null for null/blank input', () {
      expect(PublicFileSaver.sanitizeSubDir(null), isNull);
      expect(PublicFileSaver.sanitizeSubDir(''), isNull);
      expect(PublicFileSaver.sanitizeSubDir('  '), isNull);
    });

    test('rejects absolute paths', () {
      expect(() => PublicFileSaver.sanitizeSubDir('/etc'), throwsArgumentError);
      expect(() => PublicFileSaver.sanitizeSubDir(r'\windows'),
          throwsArgumentError);
      expect(() => PublicFileSaver.sanitizeSubDir(r'C:\evil'),
          throwsArgumentError);
    });

    test('rejects parent directory traversal', () {
      expect(
          () => PublicFileSaver.sanitizeSubDir('../etc'), throwsArgumentError);
      expect(() => PublicFileSaver.sanitizeSubDir('a/../../b'),
          throwsArgumentError);
    });

    test('sanitizes segments and joins with forward slashes', () {
      expect(PublicFileSaver.sanitizeSubDir(r'my\dir'), 'my/dir');
      expect(PublicFileSaver.sanitizeSubDir('a/b:c'), 'a/b_c');
      expect(PublicFileSaver.sanitizeSubDir(' a / b '), 'a/b');
      expect(PublicFileSaver.sanitizeSubDir('./a/./b'), 'a/b');
    });
  });

  group('parseContentDispositionFileName', () {
    test('plain quoted filename', () {
      expect(
        parseContentDispositionFileName('attachment; filename="report.pdf"'),
        'report.pdf',
      );
    });

    test('plain unquoted filename', () {
      expect(
        parseContentDispositionFileName('attachment; filename=report.pdf'),
        'report.pdf',
      );
    });

    test('RFC 5987 filename* with percent-encoded UTF-8', () {
      expect(
        parseContentDispositionFileName(
            "attachment; filename*=UTF-8''%E6%B5%8B%E8%AF%95.pdf"),
        '测试.pdf',
      );
    });

    test('RFC 5987 quoted filename*', () {
      expect(
        parseContentDispositionFileName(
            'attachment; filename*="UTF-8\'\'na%C3%AFve%20file.pdf"'),
        'naïve file.pdf',
      );
    });

    test('RFC 5987 filename* with a language tag', () {
      expect(
        parseContentDispositionFileName(
          "attachment; filename*=UTF-8'en'%E2%82%AC%20rates.pdf",
        ),
        '€ rates.pdf',
      );
    });

    test('RFC 5987 filename* takes precedence over plain filename', () {
      expect(
        parseContentDispositionFileName(
          "attachment; filename=fallback.pdf; filename*=UTF-8''actual.pdf",
        ),
        'actual.pdf',
      );
    });

    test('literal percent falls back to raw value instead of throwing', () {
      expect(
        parseContentDispositionFileName('attachment; filename="50%off.pdf"'),
        '50%off.pdf',
      );
    });

    test('no filename returns null', () {
      expect(parseContentDispositionFileName('attachment'), isNull);
    });
  });
}
