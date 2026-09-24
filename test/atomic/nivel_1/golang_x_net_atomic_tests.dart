// Testes atômicos 1:1 do porte de golang.org/x/net (Marco G.5, dart IPFS).
//
// Escopo desta primeira fatia: dns/dnsmessage. Vetores tirados de
// go-ipfs-reference/golang-x-net/dns/dnsmessage/{message_test.go,
// svcb_test.go}. `pack`/`unpack`/`realType` no `ResourceBody` upstream não
// são exportados (só o pacote Go pode implementar um ResourceBody), o que
// este porte espelha com métodos privados na mesma biblioteca `part`/`part
// of`; por isso estes testes, de fora da biblioteca, exercitam só a
// superfície pública real (Message, Builder, Parser, ResourceHeader),
// exatamente como um consumidor Dart do pacote precisaria fazer.
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_golang_x_net/dns/dnsmessage.dart' as dnsmessage;

void main() {
  group('Type [Atomic Audit]', () {
    test('toString() - nomes conhecidos batem com o Go (message_test.go)', () {
      expect(dnsmessage.Type.a.toString(), 'TypeA');
      expect(dnsmessage.Type.aaaa.toString(), 'TypeAAAA');
      expect(dnsmessage.Type.https.toString(), 'TypeHTTPS');
    });

    test('toString() - tipo desconhecido imprime o valor numérico', () {
      // privateUseType Type = 65362 (message_test.go:20).
      expect(const dnsmessage.Type(65362).toString(), '65362');
    });

    test('== e hashCode - igualdade por valor', () {
      expect(const dnsmessage.Type(1), dnsmessage.Type.a);
      expect(const dnsmessage.Type(1).hashCode, dnsmessage.Type.a.hashCode);
      expect(dnsmessage.Type.a, isNot(dnsmessage.Type.ns));
    });

    test('compareTo() - ordena pelo valor numérico', () {
      expect(dnsmessage.Type.a.compareTo(dnsmessage.Type.ns), lessThan(0));
    });
  });

  group('Class [Atomic Audit]', () {
    test('toString() - ClassINET e ClassANY', () {
      expect(dnsmessage.Class.inet.toString(), 'ClassINET');
      expect(dnsmessage.Class.any.toString(), 'ClassANY');
    });
  });

  group('RCode [Atomic Audit]', () {
    test('toString() - RCodeFormatError', () {
      expect(dnsmessage.RCode.formatError.toString(), 'RCodeFormatError');
    });

    test('toString() - valor sem nome cai no printUint16', () {
      expect(const dnsmessage.RCode(9).toString(), '9');
    });
  });

  group('Name [Atomic Audit]', () {
    // TestName (message_test.go:188-212): String() é a identidade de
    // NewName() para nomes canônicos e não canônicos.
    for (final s in [
      '',
      '.',
      'google..com',
      'google.com',
      'google..com.',
      'google.com.',
      '.google.com.',
      'www..google.com.',
      'www.google.com.',
    ]) {
      test('Name.parse("$s").toString() reconstrói a string original', () {
        expect(dnsmessage.Name.parse(s).toString(), s);
      });
    }

    test('Name.parse() - lança FormatException para nome maior que 255', () {
      expect(
        () => dnsmessage.Name.parse('a' * 256),
        throwsA(isA<FormatException>()),
      );
    });

    test('Name.mustParse() - lança StateError quando o nome é inválido', () {
      expect(() => dnsmessage.Name.mustParse('a' * 256), throwsStateError);
    });

    // TestNamePackUnpack (message_test.go:223-272): nomes não canônicos
    // lançam a exceção certa ao serem empacotados via Builder.question().
    test('pack (via Builder.question()) - nome vazio não é canônico', () {
      expect(
        () => _packSingleQuestionName(''),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('not in canonical format'),
          ),
        ),
      );
    });

    test('pack (via Builder.question()) - segmento de tamanho zero', () {
      expect(
        () => _packSingleQuestionName('www..google.com.'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('zero length'),
          ),
        ),
      );
    });

    test('pack()/unpack() round-trip (via Message) de "www.google.com."', () {
      final packed = _packSingleQuestionName('www.google.com.');
      final roundTripped = dnsmessage.Message()..unpack(packed);
      expect(roundTripped.questions.single.name.toString(), 'www.google.com.');
    });

    // TestNameWithDotsUnpack (message_test.go:214-221): um nome de fio
    // malformado (ponto dentro de um rótulo) é rejeitado no unpack. Byte a
    // byte igual ao vetor do teste Go, embutido numa mensagem DNS completa
    // (cabeçalho + 1 pergunta) para exercitar só a API pública
    // `Message.unpack`.
    test('Message.unpack() - rejeita nome com "." dentro de um rótulo', () {
      final header = [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0];
      const malformedName = [3, 119, 46, 119, 2, 103, 111, 3, 100, 101, 118, 0];
      final question = [0, 1, 0, 1]; // Type A, Class INET
      final bytes = Uint8List.fromList([
        ...header,
        ...malformedName,
        ...question,
      ]);
      expect(
        () => dnsmessage.Message().unpack(bytes),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('invalid dns name'),
          ),
        ),
      );
    });
  });

  group('Question [Atomic Audit]', () {
    // TestQuestionPackUnpack (message_test.go:161-186).
    test(
      'pack()/Parser.question() - round-trip preservando Name/Type/Class',
      () {
        final want = dnsmessage.Question(
          dnsmessage.Name.mustParse('.'),
          dnsmessage.Type.a,
          dnsmessage.Class.inet,
        );
        final msg = dnsmessage.Message(
          header: dnsmessage.Header(),
          questions: [want],
        );
        final packed = msg.pack();

        final parser = dnsmessage.Parser();
        parser.start(packed);
        final got = parser.question();
        expect(got.type, dnsmessage.Type.a);
        expect(got.klass, dnsmessage.Class.inet);
        expect(got.name.toString(), '.');
      },
    );
  });

  group('Parser [Atomic Audit]', () {
    test('start() + question() - lança SectionDoneException sem perguntas', () {
      final msg = dnsmessage.Message();
      final packed = msg.pack();
      final p = dnsmessage.Parser();
      p.start(packed);
      expect(
        () => p.question(),
        throwsA(isA<dnsmessage.SectionDoneException>()),
      );
    });

    test('answerHeader() antes de start() lança NotStartedException '
        '(equivalente a TestResourceNotStarted)', () {
      final p = dnsmessage.Parser();
      expect(
        () => p.answerHeader(),
        throwsA(isA<dnsmessage.NotStartedException>()),
      );
    });

    test('aResource() sem AnswerHeader() antes lança NotStartedException', () {
      final msg = dnsmessage.Message(
        answers: [
          dnsmessage.Resource(
            dnsmessage.ResourceHeader(
              name: dnsmessage.Name.mustParse('.'),
              type: dnsmessage.Type.a,
              klass: dnsmessage.Class.inet,
            ),
            dnsmessage.AResource(Uint8List.fromList([127, 0, 0, 1])),
          ),
        ],
      );
      final packed = msg.pack();
      final p = dnsmessage.Parser();
      p.start(packed);
      p.skipAllQuestions();
      expect(
        () => p.aResource(),
        throwsA(isA<dnsmessage.NotStartedException>()),
      );
    });

    test('copy() - preserva o estado de forma independente', () {
      final msg = dnsmessage.Message(
        questions: [
          dnsmessage.Question(
            dnsmessage.Name.mustParse('.'),
            dnsmessage.Type.a,
            dnsmessage.Class.inet,
          ),
        ],
      );
      final packed = msg.pack();
      final p1 = dnsmessage.Parser();
      p1.start(packed);
      final p2 = p1.copy();
      p1.skipAllQuestions();
      // p2 é uma cópia independente: ainda não avançou.
      final q = p2.question();
      expect(q.type, dnsmessage.Type.a);
    });
  });

  group('Message [Atomic Audit]', () {
    // Baseado em largeTestMsg()/TestDNSPackUnpack (message_test.go:411-449,
    // 1517+): mensagem com Answers de vários tipos de Resource, pack() +
    // unpack() devolvem os mesmos dados.
    test('pack()/unpack() - round-trip com A, AAAA, CNAME e SOA', () {
      final name = dnsmessage.Name.mustParse('foo.bar.example.com.');
      final original = dnsmessage.Message(
        header: dnsmessage.Header(response: true, authoritative: true),
        questions: [
          dnsmessage.Question(name, dnsmessage.Type.a, dnsmessage.Class.inet),
        ],
        answers: [
          dnsmessage.Resource(
            dnsmessage.ResourceHeader(
              name: name,
              type: dnsmessage.Type.a,
              klass: dnsmessage.Class.inet,
            ),
            dnsmessage.AResource(Uint8List.fromList([127, 0, 0, 1])),
          ),
          dnsmessage.Resource(
            dnsmessage.ResourceHeader(
              name: name,
              type: dnsmessage.Type.aaaa,
              klass: dnsmessage.Class.inet,
            ),
            dnsmessage.AAAAResource(
              Uint8List.fromList([
                1,
                2,
                3,
                4,
                5,
                6,
                7,
                8,
                9,
                10,
                11,
                12,
                13,
                14,
                15,
                16,
              ]),
            ),
          ),
          dnsmessage.Resource(
            dnsmessage.ResourceHeader(
              name: name,
              type: dnsmessage.Type.cname,
              klass: dnsmessage.Class.inet,
            ),
            dnsmessage.CNAMEResource(
              dnsmessage.Name.mustParse('alias.example.com.'),
            ),
          ),
          dnsmessage.Resource(
            dnsmessage.ResourceHeader(
              name: name,
              type: dnsmessage.Type.soa,
              klass: dnsmessage.Class.inet,
            ),
            dnsmessage.SOAResource(
              dnsmessage.Name.mustParse('ns1.example.com.'),
              dnsmessage.Name.mustParse('mb.example.com.'),
              1,
              2,
              3,
              4,
              5,
            ),
          ),
        ],
      );

      final packed = original.pack();
      final roundTripped = dnsmessage.Message()..unpack(packed);

      expect(roundTripped.header.response, isTrue);
      expect(roundTripped.header.authoritative, isTrue);
      expect(roundTripped.questions, hasLength(1));
      expect(
        roundTripped.questions.single.name.toString(),
        'foo.bar.example.com.',
      );
      expect(roundTripped.answers, hasLength(4));

      final a = roundTripped.answers[0].body! as dnsmessage.AResource;
      expect(a.a, Uint8List.fromList([127, 0, 0, 1]));

      final aaaa = roundTripped.answers[1].body! as dnsmessage.AAAAResource;
      expect(
        aaaa.aaaa,
        Uint8List.fromList([
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
          16,
        ]),
      );

      final cname = roundTripped.answers[2].body! as dnsmessage.CNAMEResource;
      expect(cname.cname.toString(), 'alias.example.com.');

      final soa = roundTripped.answers[3].body! as dnsmessage.SOAResource;
      expect(soa.ns.toString(), 'ns1.example.com.');
      expect(soa.mbox.toString(), 'mb.example.com.');
      expect(soa.serial, 1);
      expect(soa.refresh, 2);
      expect(soa.retry, 3);
      expect(soa.expire, 4);
      expect(soa.minTTL, 5);
    });

    test(
      'pack()/unpack() - round-trip de TXTResource com múltiplas strings',
      () {
        final name = dnsmessage.Name.mustParse('txt.example.com.');
        final msg = dnsmessage.Message(
          additionals: [
            dnsmessage.Resource(
              dnsmessage.ResourceHeader(
                name: name,
                type: dnsmessage.Type.txt,
                klass: dnsmessage.Class.inet,
              ),
              dnsmessage.TXTResource(['hello', 'world']),
            ),
          ],
        );
        final packed = msg.pack();
        final roundTripped = dnsmessage.Message()..unpack(packed);
        final txt =
            roundTripped.additionals.single.body! as dnsmessage.TXTResource;
        expect(txt.txt, ['hello', 'world']);
      },
    );

    test('pack() - lança FormatException para string de TXT maior que 255', () {
      final name = dnsmessage.Name.mustParse('txt.example.com.');
      final msg = dnsmessage.Message(
        additionals: [
          dnsmessage.Resource(
            dnsmessage.ResourceHeader(
              name: name,
              type: dnsmessage.Type.txt,
              klass: dnsmessage.Class.inet,
            ),
            dnsmessage.TXTResource(['a' * 256]),
          ),
        ],
      );
      expect(() => msg.pack(), throwsA(isA<FormatException>()));
    });

    test('pack()/unpack() - round-trip de OPTResource (EDNS(0))', () {
      final h = dnsmessage.ResourceHeader(klass: dnsmessage.Class.inet);
      h.setEDNS0(4096, dnsmessage.RCode.success, true);
      final msg = dnsmessage.Message(
        additionals: [
          dnsmessage.Resource(
            h,
            dnsmessage.OPTResource([
              dnsmessage.Option(3, Uint8List.fromList([9, 9, 9])),
            ]),
          ),
        ],
      );
      final packed = msg.pack();
      final roundTripped = dnsmessage.Message()..unpack(packed);
      final opt =
          roundTripped.additionals.single.body! as dnsmessage.OPTResource;
      expect(opt.options, hasLength(1));
      expect(opt.options.single.code, 3);
      expect(opt.options.single.data, Uint8List.fromList([9, 9, 9]));
      expect(roundTripped.additionals.single.header.dnssecAllowed(), isTrue);
    });

    test('appendPack()/pack() - usa compressão de nomes repetidos', () {
      final name = dnsmessage.Name.mustParse('example.com.');
      final msg = dnsmessage.Message(
        questions: [
          dnsmessage.Question(name, dnsmessage.Type.a, dnsmessage.Class.inet),
        ],
        answers: [
          dnsmessage.Resource(
            dnsmessage.ResourceHeader(
              name: name,
              type: dnsmessage.Type.a,
              klass: dnsmessage.Class.inet,
            ),
            dnsmessage.AResource(Uint8List.fromList([1, 2, 3, 4])),
          ),
        ],
      );
      final packed = msg.pack();
      // O segundo "example.com." deve virar um ponteiro de 2 bytes, então
      // o pacote deve ser bem menor que 2x o nome sem compressão.
      expect(packed.length, lessThan(2 * name.length + 40));

      final roundTripped = dnsmessage.Message()..unpack(packed);
      expect(
        roundTripped.answers.single.header.name.toString(),
        'example.com.',
      );
    });

    test(
      'appendPack() - lança FormatException com mais de 65535 perguntas',
      () {
        final many = List.generate(
          65536,
          (_) => dnsmessage.Question(
            dnsmessage.Name.mustParse('.'),
            dnsmessage.Type.a,
            dnsmessage.Class.inet,
          ),
        );
        final msg = dnsmessage.Message(questions: many);
        expect(
          () => msg.pack(),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('too many Questions'),
            ),
          ),
        );
      },
    );
  });

  group('Builder [Atomic Audit]', () {
    test('question()/aResource()/finish() - constrói uma mensagem válida '
        '(equivalente a TestBuilder)', () {
      final name = dnsmessage.Name.mustParse('foo.com.');
      final b = dnsmessage.Builder(null, dnsmessage.Header(response: true));
      b.enableCompression();
      b.startQuestions();
      b.question(
        dnsmessage.Question(name, dnsmessage.Type.a, dnsmessage.Class.inet),
      );
      b.startAnswers();
      b.aResource(
        dnsmessage.ResourceHeader(
          name: name,
          klass: dnsmessage.Class.inet,
          ttl: 60,
        ),
        dnsmessage.AResource(Uint8List.fromList([1, 2, 3, 4])),
      );
      final packed = b.finish();

      final roundTripped = dnsmessage.Message()..unpack(packed);
      expect(roundTripped.header.response, isTrue);
      expect(roundTripped.questions.single.name.toString(), 'foo.com.');
      final a = roundTripped.answers.single.body! as dnsmessage.AResource;
      expect(a.a, Uint8List.fromList([1, 2, 3, 4]));
    });

    test('question() antes de startQuestions() lança NotStartedException '
        '(equivalente a TestStartError)', () {
      final b = dnsmessage.Builder(null, dnsmessage.Header());
      expect(
        () => b.question(
          dnsmessage.Question(
            dnsmessage.Name.mustParse('.'),
            dnsmessage.Type.a,
            dnsmessage.Class.inet,
          ),
        ),
        throwsA(isA<dnsmessage.NotStartedException>()),
      );
    });

    test('startQuestions() depois de já ter avançado de seção lança '
        'SectionDoneException', () {
      final b = dnsmessage.Builder(null, dnsmessage.Header());
      b.startQuestions();
      b.startAnswers();
      expect(
        () => b.startQuestions(),
        throwsA(isA<dnsmessage.SectionDoneException>()),
      );
    });
  });

  group('ResourceHeader [Atomic Audit]', () {
    // mustEDNS0ResourceHeader (message_test.go:116-122) / SetEDNS0.
    test('setEDNS0()/dnssecAllowed()/extendedRCode() - round trip EDNS(0)', () {
      final h = dnsmessage.ResourceHeader(klass: dnsmessage.Class.inet);
      h.setEDNS0(4096, const dnsmessage.RCode(0xfe0 | 1), true);
      expect(h.type, dnsmessage.Type.opt);
      expect(h.klass.value, 4096);
      expect(h.dnssecAllowed(), isTrue);
      final extended = h.extendedRCode(dnsmessage.RCode.formatError);
      expect(extended.value, 0xfe0 | 1);
    });
  });

  group('SVCBResource [Atomic Audit]', () {
    // TestSVCBParamsRoundTrip (svcb_test.go:15-46), exercitado via
    // Builder.svcbResource()/Parser.svcbResource() (a única superfície
    // pública que empacota/desempacota um SVCBResource).
    test('pack()/unpack() - round-trip de SVCParamMandatory', () {
      _roundTripSVCBParam(
        dnsmessage.SVCParamKey.mandatory,
        Uint8List.fromList([0x00, 0x01, 0x00, 0x03, 0x00, 0x05]),
      );
    });

    test('pack()/unpack() - round-trip de SVCParamALPN ("h2", "h3")', () {
      _roundTripSVCBParam(
        dnsmessage.SVCParamKey.alpn,
        Uint8List.fromList([0x02, 104, 50, 0x02, 104, 51]),
      );
    });

    test('pack()/unpack() - round-trip de SVCParamIPv4Hint', () {
      _roundTripSVCBParam(
        dnsmessage.SVCParamKey.ipv4Hint,
        Uint8List.fromList([192, 0, 2, 1, 198, 51, 100, 2]),
      );
    });

    test('pack() - lança FormatException quando os params não estão em '
        'ordem estritamente crescente (RFC 9460 2.2)', () {
      final b = dnsmessage.Builder(null, dnsmessage.Header());
      b.startAnswers();
      final r = dnsmessage.SVCBResource(
        1,
        dnsmessage.Name.mustParse('svc.example.com.'),
        [
          dnsmessage.SVCParam(dnsmessage.SVCParamKey.port, Uint8List(2)),
          dnsmessage.SVCParam(dnsmessage.SVCParamKey.mandatory, Uint8List(2)),
        ],
      );
      expect(
        () => b.svcbResource(
          dnsmessage.ResourceHeader(
            name: dnsmessage.Name.mustParse('.'),
            klass: dnsmessage.Class.inet,
          ),
          r,
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('out of order'),
          ),
        ),
      );
    });

    test('getParam()/setParam()/deleteParam() - mantém a lista ordenada por '
        'chave', () {
      final r = dnsmessage.SVCBResource(
        1,
        dnsmessage.Name.mustParse('svc.example.com.'),
      );
      r.setParam(dnsmessage.SVCParamKey.port, Uint8List.fromList([0x1f, 0x90]));
      r.setParam(dnsmessage.SVCParamKey.mandatory, Uint8List.fromList([0, 3]));
      expect(r.params.map((p) => p.key.value), [
        0,
        3,
      ]); // mandatory(0) < port(3)
      expect(
        r.getParam(dnsmessage.SVCParamKey.port),
        Uint8List.fromList([0x1f, 0x90]),
      );
      expect(r.deleteParam(dnsmessage.SVCParamKey.port), isTrue);
      expect(r.getParam(dnsmessage.SVCParamKey.port), isNull);
      expect(r.deleteParam(dnsmessage.SVCParamKey.port), isFalse);
    });
  });

  group('HTTPSResource [Atomic Audit]', () {
    test('Builder.httpsResource()/Parser.httpsResource() - round-trip', () {
      final name = dnsmessage.Name.mustParse('svc.example.com.');
      final b = dnsmessage.Builder(null, dnsmessage.Header());
      b.startAnswers();
      final https = dnsmessage.HTTPSResource(
        dnsmessage.SVCBResource(
          1,
          dnsmessage.Name.mustParse('target.example.com.'),
          [
            dnsmessage.SVCParam(
              dnsmessage.SVCParamKey.alpn,
              Uint8List.fromList([0x02, 104, 50]),
            ),
          ],
        ),
      );
      b.httpsResource(
        dnsmessage.ResourceHeader(name: name, klass: dnsmessage.Class.inet),
        https,
      );
      final packed = b.finish();

      final p = dnsmessage.Parser();
      p.start(packed);
      p.skipAllQuestions();
      p.answerHeader();
      final got = p.httpsResource();
      expect(got.svcbResource.priority, 1);
      expect(got.svcbResource.target.toString(), 'target.example.com.');
      expect(
        got.svcbResource.getParam(dnsmessage.SVCParamKey.alpn),
        Uint8List.fromList([0x02, 104, 50]),
      );
    });
  });

  group('SVCParamKey [Atomic Audit]', () {
    test('toString() - nomes conhecidos', () {
      expect(dnsmessage.SVCParamKey.alpn.toString(), 'ALPN');
      expect(dnsmessage.SVCParamKey.ipv4Hint.toString(), 'IPv4Hint');
    });

    test('toString() - chave desconhecida imprime o valor numérico', () {
      expect(const dnsmessage.SVCParamKey(999).toString(), '999');
    });
  });
}

/// Empacota uma mensagem com uma única Question de nome [name] usando
/// Builder.question() (que delega em Question.pack() -> Name.pack()), e
/// devolve os bytes de fio -- a rota pública que exercita o pack de Name
/// sem depender de um método privado.
Uint8List _packSingleQuestionName(String name) {
  final b = dnsmessage.Builder(null, dnsmessage.Header());
  b.startQuestions();
  b.question(
    dnsmessage.Question(
      dnsmessage.Name.mustParse(name),
      dnsmessage.Type.a,
      dnsmessage.Class.inet,
    ),
  );
  return b.finish();
}

void _roundTripSVCBParam(dnsmessage.SVCParamKey key, Uint8List value) {
  final b = dnsmessage.Builder(null, dnsmessage.Header());
  b.startAnswers();
  b.svcbResource(
    dnsmessage.ResourceHeader(
      name: dnsmessage.Name.mustParse('.'),
      klass: dnsmessage.Class.inet,
    ),
    dnsmessage.SVCBResource(1, dnsmessage.Name.mustParse('svc.example.com.'), [
      dnsmessage.SVCParam(key, value),
    ]),
  );
  final packed = b.finish();

  final p = dnsmessage.Parser();
  p.start(packed);
  p.skipAllQuestions();
  p.answerHeader();
  final got = p.svcbResource();
  expect(got.priority, 1);
  expect(got.target.toString(), 'svc.example.com.');
  expect(got.params, hasLength(1));
  expect(got.params.single.key, key);
  expect(got.params.single.value, value);
}
