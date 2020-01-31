// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/edit/nnbd_migration/info_builder.dart';
import 'package:analysis_server/src/edit/nnbd_migration/migration_info.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../../analysis_abstract.dart';
import 'nnbd_migration_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(BuildEnclosingMemberDescriptionTest);
    defineReflectiveTests(InfoBuilderTest);
  });
}

@reflectiveTest
class BuildEnclosingMemberDescriptionTest extends AbstractAnalysisTest {
  Future<ResolvedUnitResult> resolveTestFile() async {
    String includedRoot = resourceProvider.pathContext.dirname(testFile);
    server.setAnalysisRoots('0', [includedRoot], [], {});
    return await server
        .getAnalysisDriver(testFile)
        .currentSession
        .getResolvedUnit(testFile);
  }

  Future<void> test_classConstructor_named() async {
    addTestFile(r'''
class C {
  C.aaa();
}
''');
    var result = await resolveTestFile();
    ClassDeclaration class_ = result.unit.declarations.single;
    ClassMember constructor = class_.members.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(constructor),
        equals("the constructor 'C.aaa'"));
  }

  Future<void> test_classConstructor_unnamed() async {
    addTestFile(r'''
class C {
  C();
}
''');
    var result = await resolveTestFile();
    ClassDeclaration class_ = result.unit.declarations.single;
    ClassMember constructor = class_.members.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(constructor),
        equals("the default constructor of 'C'"));
  }

  Future<void> test_classGetter() async {
    addTestFile(r'''
class C {
  int get aaa => 7;
}
''');
    var result = await resolveTestFile();
    ClassDeclaration class_ = result.unit.declarations.single;
    ClassMember getter = class_.members.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(getter),
        equals("the getter 'C.aaa'"));
  }

  Future<void> test_classMethod() async {
    addTestFile(r'''
class C {
  int aaa() => 7;
}
''');
    var result = await resolveTestFile();
    ClassDeclaration class_ = result.unit.declarations.single;
    ClassMember method = class_.members.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(method),
        equals("the method 'C.aaa'"));
  }

  Future<void> test_classOperator() async {
    addTestFile(r'''
class C {
  bool operator ==(Object other) => false;
}
''');
    var result = await resolveTestFile();
    ClassDeclaration class_ = result.unit.declarations.single;
    ClassMember operator = class_.members.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(operator),
        equals("the operator 'C.=='"));
  }

  Future<void> test_classSetter() async {
    addTestFile(r'''
class C {
  void set aaa(value) {}
}
''');
    var result = await resolveTestFile();
    ClassDeclaration class_ = result.unit.declarations.single;
    ClassMember setter = class_.members.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(setter),
        equals("the setter 'C.aaa='"));
  }

  Future<void> test_extensionMethod() async {
    addTestFile(r'''
extension E on List {
  int aaa() => 7;
}
''');
    var result = await resolveTestFile();
    ExtensionDeclaration extension_ = result.unit.declarations.single;
    ClassMember method = extension_.members.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(method),
        equals("the method 'E.aaa'"));
  }

  Future<void> test_extensionMethod_unnamed() async {
    addTestFile(r'''
extension on List {
  int aaa() => 7;
}
''');
    var result = await resolveTestFile();
    ExtensionDeclaration extension_ = result.unit.declarations.single;
    ClassMember method = extension_.members.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(method),
        equals("the method 'aaa' in unnamed extension on List<dynamic>"));
  }

  Future<void> test_mixinMethod() async {
    addTestFile(r'''
mixin C {
  int aaa() => 7;
}
''');
    var result = await resolveTestFile();
    MixinDeclaration mixin_ = result.unit.declarations.single;
    ClassMember method = mixin_.members.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(method),
        equals("the method 'C.aaa'"));
  }

  Future<void> test_topLevelFunction() async {
    addTestFile(r'''
void aaa(value) {}
''');
    var result = await resolveTestFile();
    var function = result.unit.declarations.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(function),
        equals("the function 'aaa'"));
  }

  Future<void> test_topLevelGetter() async {
    addTestFile(r'''
int get aaa => 7;
''');
    var result = await resolveTestFile();
    var getter = result.unit.declarations.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(getter),
        equals("the getter 'aaa'"));
  }

  Future<void> test_topLevelSetter() async {
    addTestFile(r'''
void set aaa(value) {}
''');
    var result = await resolveTestFile();
    var setter = result.unit.declarations.single;
    expect(InfoBuilder.buildEnclosingMemberDescription(setter),
        equals("the setter 'aaa='"));
  }
}

@reflectiveTest
class InfoBuilderTest extends NnbdMigrationTestBase {
  /// Assert various properties of the given [detail].
  void assertDetail({@required RegionDetail detail, int offset, int length}) {
    if (offset != null) {
      expect(detail.target.offset, offset);
    }
    if (length != null) {
      expect(detail.target.length, length);
    }
  }

  /// Assert various properties of the given [edit].
  void assertEdit(
      {@required EditDetail edit, int offset, int length, String replacement}) {
    expect(edit, isNotNull);
    if (offset != null) {
      expect(edit.offset, offset);
    }
    if (length != null) {
      expect(edit.length, length);
    }
    if (replacement != null) {
      expect(edit.replacement, replacement);
    }
  }

  /// Assert that some target in [targets] has various properties.
  void assertInTargets(
      {@required Iterable<NavigationTarget> targets, int offset, int length}) {
    String failureReasons = [
      if (offset != null) 'offset: $offset',
      if (length != null) 'length: $length',
    ].join(' and ');
    expect(targets.any((t) {
      return (offset == null || offset == t.offset) &&
          (length == null || length == t.length);
    }), isTrue, reason: 'Expected one of $targets to contain $failureReasons');
  }

  /// Assert various properties of the given [region]. If an [offset] is
  /// provided but no [length] is provided, a default length of `1` will be
  /// used.
  void assertRegion(
      {@required RegionInfo region,
      int offset,
      int length,
      List<String> details}) {
    if (offset != null) {
      expect(region.offset, offset);
      expect(region.length, length ?? 1);
    }
    if (details != null) {
      expect(region.details.map((detail) => detail.description),
          unorderedEquals(details));
    }
  }

  Future<void> test_asExpression() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f([num a]) {
  int b = a as int;
}
''', migratedContent: '''
void f([num? a]) {
  int? b = a as int?;
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(3));
    // regions[0] is `num? a`.
    assertRegion(
        region: regions[1],
        offset: 24,
        details: ['This variable is initialized to a nullable value']);
    assertRegion(
        region: regions[2],
        offset: 38,
        details: ['The value of the expression is nullable']);
  }

  Future<void> test_asExpression_insideReturn() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
int f([num a]) {
  return a as int;
}
''', migratedContent: '''
int? f([num? a]) {
  return a as int?;
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(3));
    // regions[0] is `inf? f`.
    // regions[1] is `num? a`.
    assertRegion(
        region: regions[2],
        offset: 36,
        details: ['The value of the expression is nullable']);
  }

  Future<void> test_discardCondition() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void g(int i) {
  print(i.isEven);
  if (i != null) print('NULL');
}
''', migratedContent: '''
void g(int i) {
  print(i.isEven);
  /* if (i != null) */ print('NULL');
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    assertRegion(region: regions[0], offset: 37, length: 3);
    assertRegion(region: regions[1], offset: 55, length: 3);
  }

  Future<void> test_discardElse() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void g(int i) {
  print(i.isEven);
  if (i != null) print('NULL');
  else print('NOT NULL');
}
''', migratedContent: '''
void g(int i) {
  print(i.isEven);
  /* if (i != null) */ print('NULL'); /*
  else print('NOT NULL'); */
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(4));
    assertRegion(region: regions[0], offset: 37, length: 3);
    assertRegion(region: regions[1], offset: 55, length: 3);
    assertRegion(region: regions[2], offset: 72, length: 3);
    assertRegion(region: regions[3], offset: 101, length: 3);
  }

  Future<void> test_dynamicValueIsUsed() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
bool f(int i) {
  if (i == null) return true;
  else return false;
}
void g() {
  dynamic i = null;
  f(i);
}
''', migratedContent: '''
bool f(int? i) {
  if (i == null) return true;
  else return false;
}
void g() {
  dynamic i = null;
  f(i);
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(1));
    var region = regions[0];
    var edits = region.edits;
    assertRegion(region: region, offset: 10, details: [
      'A dynamic value, which is nullable is passed as an argument'
    ]);
    assertDetail(detail: region.details[0], offset: 104, length: 1);
    assertEdit(edit: edits[0], offset: 10, replacement: '/*!*/');
    assertEdit(edit: edits[1], offset: 10, replacement: '/*?*/');
  }

  Future<void> test_exactNullable() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f(List<int> list) {
  list[0] = null;
}

void g() {
  f(<int>[]);
}
''', migratedContent: '''
void f(List<int?> list) {
  list[0] = null;
}

void g() {
  f(<int?>[]);
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(3));
    // regions[0] is the hard edge that f's parameter is non-nullable.
    assertRegion(region: regions[1], offset: 15, details: [
      "An explicit 'null' is assigned in the function 'f'",
    ]);
    assertRegion(
        region: regions[2],
        offset: 66,
        details: ['This is later required to accept null.']);
  }

  Future<void> test_exactNullable_exactNullable() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void g(List<int> list1, List<int> list2) {
  list1[0] = null;
  list2[0] = list1[0];
}
''', migratedContent: '''
void g(List<int?> list1, List<int?> list2) {
  list1[0] = null;
  list2[0] = list1[0];
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(4));
    // regions[0] is the hard edge that list1 is unconditionally indexed
    assertRegion(region: regions[1], offset: 15, details: [
      "An explicit 'null' is assigned in the function 'g'",
      // TODO(mfairhurst): Fix this bug.
      'exact nullable node with no info (Substituted(type(32), migrated))'
    ]);
    // regions[2] is the hard edge that list2 is unconditionally indexed
    assertRegion(
        region: regions[3],
        offset: 33,
        details: ["A nullable value is assigned in the function 'g'"]);
  }

  Future<void> test_expressionFunctionReturnTarget() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
String g() => 1 == 2 ? "Hello" : null;
''', migratedContent: '''
String? g() => 1 == 2 ? "Hello" : null;
''');
    assertInTargets(targets: unit.targets, offset: 7, length: 1); // "g"
    assertInTargets(targets: unit.targets, offset: 11, length: 2); // "=>"
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(1));
    assertRegion(
        region: regions[0],
        offset: 6,
        details: ['This function returns a nullable value on line 1']);
    assertDetail(detail: regions[0].details[0], offset: 11, length: 2);
  }

  Future<void> test_field_fieldFormalInitializer_optional() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class A {
  int _f;
  A([this._f]);
}
''', migratedContent: '''
class A {
  int? _f;
  A([this._f]);
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(1));
    assertRegion(region: regions[0], offset: 15, details: [
      'This field is initialized by an optional field formal parameter that '
          "has an implicit default value of 'null'"
    ]);
  }

  Future<void> test_field_fieldFormalInitializer_optional_defaultNull() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class A {
  int _f;
  A([this._f = null]);
}
''', migratedContent: '''
class A {
  int? _f;
  A([this._f = null]);
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(1));
    assertRegion(region: regions[0], offset: 15, details: [
      'This field is initialized by an optional field formal parameter that '
          "has an explicit default value of 'null'"
    ]);
  }

  Future<void> test_field_fieldFormalInitializer_required() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class A {
  int _f;
  A(this._f);
}
void g() {
  A(null);
}
''', migratedContent: '''
class A {
  int? _f;
  A(this._f);
}
void g() {
  A(null);
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(1));
    // TODO(brianwilkerson) It would be nice if the target for the region could
    //  be the argument rather than the field formal parameter.
    assertRegion(region: regions[0], offset: 15, details: [
      'This field is initialized by a field formal parameter and a nullable '
          'value is passed as an argument'
    ]);
  }

  Future<void> test_field_initializer() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class A {
  int _f = null;
  int _f2 = _f;
}
''', migratedContent: '''
class A {
  int? _f = null;
  int? _f2 = _f;
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[0],
        offset: 15,
        details: ["This field is initialized to an explicit 'null'"]);
    assertRegion(
        region: regions[1],
        offset: 33,
        details: ['This field is initialized to a nullable value']);
  }

  Future<void> test_fieldLaterAssignedNullable() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class Foo {
  int value = 7;
  void bar() {
    value = null;
  }
}
''', migratedContent: '''
class Foo {
  int? value = 7;
  void bar() {
    value = null;
  }
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(1));
    RegionInfo region = regions.single;
    assertRegion(region: region, offset: 17, details: [
      "An explicit 'null' is assigned in the method 'Foo.bar'",
    ]);

    assertDetail(detail: region.details[0], offset: 56, length: 4);
  }

  Future<void> test_functionType_nullable_asArgument() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class C {
  f(void Function(int) cb1) {}
  g(void Function(int) cb2) {
    f(cb2);
  }
  h() => f(null);
}
''', migratedContent: '''
class C {
  f(void Function(int)? cb1) {}
  g(void Function(int) cb2) {
    f(cb2);
  }
  h() => f(null);
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(1));
    assertRegion(
        region: regions[0],
        offset: 32,
        details: ["An explicit 'null' is passed as an argument"]);
    assertDetail(detail: regions[0].details[0], offset: 98, length: 4);
  }

  Future<void> test_functionType_nullableParameter_asArgument() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class C {
  f(void Function(int) cb1) {
    cb1(null);
  }
  g(void Function(int) cb2) {
    f(cb2);
  }
}
''', migratedContent: '''
class C {
  f(void Function(int?) cb1) {
    cb1(null);
  }
  g(void Function(int?) cb2) {
    f(cb2);
  }
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[0],
        offset: 31,
        details: ["An explicit 'null' is passed as an argument"]);
    assertRegion(region: regions[1], offset: 81, details: [
      'The function-typed element in which this parameter is declared is '
          'assigned to a function whose matching parameter is nullable'
    ]);
    assertDetail(detail: regions[1].details[0], offset: 95, length: 3);
  }

  Future<void> test_functionType_nullableParameter_assignment() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class C {
  void Function(int) _cb = (x) {};
  f(void Function(int) cb) {
    _cb = cb;
  }
  g() => _cb(null);
}
''', migratedContent: '''
class C {
  void Function(int?) _cb = (x) {};
  f(void Function(int?) cb) {
    _cb = cb;
  }
  g() => _cb(null);
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    // regions[0] is `void Function(int?) _cb`.
    assertRegion(region: regions[1], offset: 67, details: [
      'The function-typed element in which this parameter is declared is '
          'assigned to a function whose matching parameter is nullable'
    ]);
    assertDetail(detail: regions[1].details[0], offset: 84, length: 2);
  }

  Future<void> test_functionType_nullableParameter_fieldInitializer() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class C {
  void Function(int) _cb;
  C(void Function(int) cb): _cb = cb;
  f() => _cb(null);
}
''', migratedContent: '''
class C {
  void Function(int?) _cb;
  C(void Function(int?) cb): _cb = cb;
  f() => _cb(null);
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[0],
        offset: 29,
        details: ["An explicit 'null' is passed as an argument"]);
    assertRegion(region: regions[1], offset: 58, details: [
      'The function-typed element in which this parameter is declared is '
          'assigned to a function whose matching parameter is nullable'
    ]);
    assertDetail(detail: regions[1].details[0], offset: 70, length: 2);
  }

  @FailingTest(issue: 'https://github.com/dart-lang/sdk/issues/40034')
  Future<void> test_functionType_nullableParameter_typedef() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
typedef Cb = void Function(int);
class C {
  Cb _cb;
  C(void Function(int) cb): _cb = cb;
  f() => _cb(null);
}
''', migratedContent: '''
typedef Cb = void Function(int?);
class C {
  Cb _cb;
  C(void Function(int?) cb): _cb = cb;
  f() => _cb(null);
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    // regions[0] is `typedef Cb = void Function(int?);`.
    assertRegion(region: regions[1], offset: 75, details: [
      'The function-typed element in which this parameter is declared is '
          'assigned to a function whose matching parameter is nullable'
    ]);
    assertDetail(detail: regions[1].details[0], offset: 70, length: 2);
  }

  Future<void> test_functionType_nullableReturn() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class C {
  int Function() _cb = () => 7;
  f(int Function() cb) {
    _cb = cb;
  }
  g() {
    f(() => null);
  }
}
''', migratedContent: '''
class C {
  int? Function() _cb = () => 7;
  f(int? Function() cb) {
    _cb = cb;
  }
  g() {
    f(() => null);
  }
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    assertRegion(region: regions[0], offset: 15, details: [
      'A function-typed value with a nullable return type is assigned'
    ]);
    assertDetail(detail: regions[0].details[0], offset: 77, length: 2);
  }

  Future<void> test_insertedRequired_fieldFormal() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class C {
  int level;
  int level2;
  C({this.level}) : this.level2 = level + 1;
}
''', migratedContent: '''
class C {
  int level;
  int level2;
  C({required this.level}) : this.level2 = level + 1;
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(1));
    var region = regions[0];
    var edits = region.edits;
    assertRegion(region: region, offset: 42, length: 9, details: [
      'This parameter is non-nullable, so cannot have an implicit default '
          "value of 'null'"
    ]);
    assertEdit(
        edit: edits[0], offset: 42, length: 0, replacement: '@required ');
  }

  Future<void> test_insertedRequired_parameter() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class C {
  int level;
  bool f({int lvl}) => lvl >= level;
}
''', migratedContent: '''
class C {
  int? level;
  bool f({required int lvl}) => lvl >= level!;
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(3));
    // regions[0] is the `int? s` fix.
    var region = regions[1];
    var edits = region.edits;
    assertRegion(region: region, offset: 34, length: 9, details: [
      'This parameter is non-nullable, so cannot have an implicit default '
          "value of 'null'"
    ]);
    assertEdit(
        edit: edits[0], offset: 33, length: 0, replacement: '@required ');
    // regions[2] is the `level!` fix.
  }

  Future<void> test_insertParens() async {
    var originalContent = '''
class C {
  C operator+(C c) => null;
}
C/*!*/ _f(C c) => c + c;
''';
    var migratedContent = '''
class C {
  C? operator+(C c) => null;
}
C/*!*/ _f(C c) => (c + c)!;
''';
    UnitInfo unit = await buildInfoForSingleTestFile(originalContent,
        migratedContent: migratedContent);
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[0],
        offset: migratedContent.indexOf('? operator'),
        length: 1,
        details: ["This method returns an explicit 'null' on line 2"]);
    assertRegion(
        region: regions[1],
        offset: migratedContent.indexOf('!;'),
        length: 1,
        details: ['This value must be null-checked before use here.']);
  }

  Future<void> test_listAndSetLiteralTypeArgument() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f() {
  String s = null;
  var x = <String>["hello", s];
  var y = <String>{"hello", s};
}
''', migratedContent: '''
void f() {
  String? s = null;
  var x = <String?>["hello", s];
  var y = <String?>{"hello", s};
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(3));
    // regions[0] is the `String? s` fix.
    assertRegion(
        region: regions[1],
        offset: 48,
        details: ['This list is initialized with a nullable value on line 3']);
    assertDetail(detail: regions[1].details[0], offset: 58, length: 1);
    assertRegion(
        region: regions[2],
        offset: 81,
        details: ['This set is initialized with a nullable value on line 4']);
    assertDetail(detail: regions[2].details[0], offset: 90, length: 1);
  }

  Future<void> test_listConstructor_length() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f() {
  List<int> list = List<int>(10);
}
''', migratedContent: '''
void f() {
  List<int?> list = List<int?>(10);
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(2));
    // regions[0] is `num? a`.
    assertRegion(region: regions[1], offset: 39, details: [
      'List value type must be nullable because a length is specified,'
          ' and the list items are initialized as null.'
    ]);
  }

  @FailingTest(issue: 'https://github.com/dart-lang/sdk/issues/40064')
  Future<void> test_listConstructor_length_implicitType() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f() {
  List<int> list = List(10);
}
''', migratedContent: '''
void f() {
  List<int?> list = List(10);
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(2));
    // regions[0] is `num? a`.
    assertRegion(region: regions[1], offset: 40, details: [
      'List value type must be nullable because a length is specified,'
          ' and the list items are initialized as null.'
    ]);
  }

  Future<void> test_listLiteralTypeArgument_collectionIf() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f() {
  String s = null;
  var x = <String>[
    "hello",
    if (1 == 2) s
  ];
}
''', migratedContent: '''
void f() {
  String? s = null;
  var x = <String?>[
    "hello",
    if (1 == 2) s
  ];
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    // regions[0] is the `String? s` fix.
    assertRegion(
        region: regions[1],
        offset: 48,
        details: ['This list is initialized with a nullable value on line 5']);
    assertDetail(detail: regions[1].details[0], offset: 79, length: 1);
  }

  Future<void> test_localVariable() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f() {
  int v1 = null;
  int v2 = v1;
}
''', migratedContent: '''
void f() {
  int? v1 = null;
  int? v2 = v1;
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[0],
        offset: 16,
        details: ["This variable is initialized to an explicit 'null'"]);
    assertRegion(
        region: regions[1],
        offset: 34,
        details: ['This variable is initialized to a nullable value']);
  }

  Future<void> test_mapLiteralTypeArgument() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f() {
  String s = null;
  var x = <String, bool>{"hello": false, s: true};
  var y = <bool, String>{false: "hello", true: s};
}
''', migratedContent: '''
void f() {
  String? s = null;
  var x = <String?, bool>{"hello": false, s: true};
  var y = <bool, String?>{false: "hello", true: s};
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(3));
    // regions[0] is the `String? s` fix.
    assertRegion(
        region: regions[1],
        offset: 48,
        details: ['This map is initialized with a nullable value on line 3']);
    assertDetail(detail: regions[1].details[0], offset: 71, length: 1);
    assertRegion(
        region: regions[2],
        offset: 106,
        details: ['This map is initialized with a nullable value on line 4']);
    assertDetail(detail: regions[2].details[0], offset: 128, length: 1);
  }

  Future<void> test_namedParameterWithDefault_fromOverridden_explicit() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class A {
  void m({int p = 0}) {}
}
class B extends A {
  void m({num p = 0}) {}
}
void f(A a) {
  a.m(p: null);
}
''', migratedContent: '''
class A {
  void m({int? p = 0}) {}
}
class B extends A {
  void m({num? p = 0}) {}
}
void f(A a) {
  a.m(p: null);
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    // regions[0] is "an explicit null is passed..."
    assertRegion(region: regions[1], offset: 71, details: [
      'The corresponding parameter in the overridden method, A.m, is nullable'
    ]);
    assertDetail(detail: regions[1].details[0], offset: 20, length: 3);
  }

  Future<void> test_nonNullableType_assert() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f(String s) {
  assert(s != null);
}
''', migratedContent: '''
void f(String s) {
  assert(s != null);
}
''');
    List<RegionInfo> regions = unit.nonNullableTypeRegions;
    expect(regions, hasLength(1));
    assertRegion(
        region: regions[0],
        offset: 7,
        length: 6,
        details: ['This value is asserted to be non-null']);
  }

  Future<void> test_nonNullableType_exclamationComment() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f(String /*!*/ s) {}
''', migratedContent: '''
void f(String /*!*/ s) {}
''');
    List<RegionInfo> regions = unit.nonNullableTypeRegions;
    expect(regions, hasLength(1));
    assertRegion(region: regions[0], offset: 7, length: 6, details: [
      'This type is annotated with a non-nullability comment ("/*!*/")'
    ]);
  }

  Future<void> test_nonNullableType_unconditionalFieldAccess() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f(String s) {
  print(s.length);
}
''', migratedContent: '''
void f(String s) {
  print(s.length);
}
''');
    List<RegionInfo> regions = unit.nonNullableTypeRegions;
    expect(regions, hasLength(1));
    assertRegion(region: regions[0], offset: 7, length: 6, details: [
      'This value is unconditionally used in a non-nullable context'
    ]);
  }

  Future<void> test_nullCheck_onMemberAccess() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class C {
  int value;
  C([this.value]);
  void f() {
    value.sign;
  }
}
''', migratedContent: '''
class C {
  int? value;
  C([this.value]);
  void f() {
    value!.sign;
  }
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(2));
    // regions[0] is `int?`.
    var region = regions[1];
    var edits = region.edits;
    assertRegion(region: regions[1], offset: 65, details: [
      'This value must be null-checked before accessing its properties.'
    ]);
    assertEdit(edit: edits[0], offset: 64, length: 0, replacement: '/*!*/');
  }

  Future<void> test_nullCheck_onMethodCall() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class C {
  int value;
  C([this.value]);
  void f() {
    value.abs();
  }
}
''', migratedContent: '''
class C {
  int? value;
  C([this.value]);
  void f() {
    value!.abs();
  }
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(2));
    // regions[0] is `int?`.
    assertRegion(region: regions[1], offset: 65, details: [
      'This value must be null-checked before calling its methods.'
    ]);
  }

  Future<void> test_parameter_fromInvocation_explicit() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f(String s) {}
void g() {
  f(null);
}
''', migratedContent: '''
void f(String? s) {}
void g() {
  f(null);
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(1));
    assertRegion(
        region: regions[0],
        offset: 13,
        details: ["An explicit 'null' is passed as an argument"]);
  }

  Future<void> test_parameter_fromInvocation_implicit() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f(String s) {}
void g(p) {
  f(p);
}
void h() => g(null);
''', migratedContent: '''
void f(String? s) {}
void g(p) {
  f(p);
}
void h() => g(null);
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(1));
    assertRegion(region: regions[0], offset: 13, details: [
      'A dynamic value, which is nullable is passed as an argument'
    ]);
  }

  Future<void> test_parameter_fromMultipleOverridden_explicit() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class A {
  void m(int p) {}
}
class B extends A {
  void m(num p) {}
}
class C extends B {
  void m(Object p) {}
}
void f(A a) {
  a.m(null);
}
''', migratedContent: '''
class A {
  void m(int? p) {}
}
class B extends A {
  void m(num? p) {}
}
class C extends B {
  void m(Object? p) {}
}
void f(A a) {
  a.m(null);
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(3));
    // regions[0] is "an explicit null is passed..."
    assertRegion(region: regions[1], offset: 64, details: [
      'The corresponding parameter in the overridden method, A.m, is nullable'
    ]);
    assertRegion(region: regions[2], offset: 109, details: [
      'The corresponding parameter in the overridden method, B.m, is nullable'
    ]);
    assertDetail(detail: regions[1].details[0], offset: 19, length: 3);
    assertDetail(detail: regions[2].details[0], offset: 60, length: 3);
  }

  Future<void> test_parameter_fromMultipleOverridden_implicit() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class A {
  void m(int p) {}
}
class B extends A {
  void m(p) {}
}
class C extends B {
  void m(Object p) {}
}
void f(A a) {
  a.m(null);
}
''', migratedContent: '''
class A {
  void m(int? p) {}
}
class B extends A {
  void m(p) {}
}
class C extends B {
  void m(Object? p) {}
}
void f(A a) {
  a.m(null);
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    // regions[0] is "an explicit null is passed..."
    assertRegion(region: regions[1], offset: 104, details: [
      'The corresponding parameter in the overridden method is nullable'
    ]);
  }

  @FailingTest(issue: 'https://github.com/dart-lang/sdk/issues/39378')
  Future<void> test_parameter_fromOverridden_implicit() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class A {
  void m(p) {}
}
class B extends A {
  void m(Object p) {}
}
''', migratedContent: '''
class A {
  void m(p) {}
}
class B extends A {
  void m(Object? p) {}
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(1));
    // TODO(brianwilkerson) The detail should read something like
    //  "The overridden method accepts a nullable type"
    assertRegion(
        region: regions[0],
        offset: 62,
        details: ['A nullable value is assigned']);
  }

  Future<void> test_parameter_fromOverriddenField_explicit() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class A {
  int m;
}
class B extends A {
  void set m(Object p) {}
}
void f(A a) => a.m = null;
''', migratedContent: '''
class A {
  int? m;
}
class B extends A {
  void set m(Object? p) {}
}
void f(A a) => a.m = null;
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    assertRegion(region: regions[0], offset: 15, details: [
      // TODO(srawlins): I suspect this should be removed...
      'A nullable value is assigned',
      "An explicit 'null' is assigned in the function 'f'",
    ]);
    assertRegion(region: regions[1], offset: 61, details: [
      // TODO(srawlins): Improve this message to include "B.m".
      'The corresponding parameter in the overridden method is nullable'
    ]);
    assertDetail(detail: regions[0].details[1], offset: 90, length: 4);
    assertDetail(detail: regions[1].details[0], offset: 12, length: 3);
  }

  Future<void> test_parameter_named_omittedInCall() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f() { g(); }

void g({int i}) {}
''', migratedContent: '''
void f() { g(); }

void g({int? i}) {}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(1));
    assertRegion(region: regions[0], offset: 30, details: [
      'This named parameter was omitted in a call to this function',
      "This parameter has an implicit default value of 'null'",
    ]);
    assertDetail(detail: regions[0].details[0], offset: 11, length: 3);
  }

  Future<void> test_parameter_optional_explicitDefault_null() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f({String s = null}) {}
''', migratedContent: '''
void f({String? s = null}) {}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(1));
    assertRegion(
        region: regions[0],
        offset: 14,
        details: ["This parameter has an explicit default value of 'null'"]);
  }

  Future<void> test_parameter_optional_explicitDefault_nullable() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
String sd = null;
void f({String s = sd}) {}
''', migratedContent: '''
String? sd = null;
void f({String? s = sd}) {}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[1],
        offset: 33,
        details: ['This parameter has a nullable default value']);
  }

  Future<void> test_parameter_optional_implicitDefault_named() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f({String s}) {}
''', migratedContent: '''
void f({String? s}) {}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(1));
    assertRegion(
        region: regions[0],
        offset: 14,
        details: ["This parameter has an implicit default value of 'null'"]);
  }

  Future<void> test_parameter_optional_implicitDefault_positional() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f([String s]) {}
''', migratedContent: '''
void f([String? s]) {}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(1));
    assertRegion(
        region: regions[0],
        offset: 14,
        details: ["This parameter has an implicit default value of 'null'"]);
  }

  Future<void> test_removal_handles_offsets_correctly() async {
    var originalContent = '''
void f(num n, int/*?*/ i) {
  if (n is! int) return;
  print((n as int).isEven);
  print(i + 1);
}
''';
    // Note: even though `as int` is removed, it still shows up in the
    // preview, since we show deleted text.
    var migratedContent = '''
void f(num n, int?/*?*/ i) {
  if (n is! int) return;
  print((n as int).isEven);
  print(i! + 1);
}
''';
    UnitInfo unit = await buildInfoForSingleTestFile(originalContent,
        migratedContent: migratedContent, removeViaComments: false);
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(3));
    // regions[0] is the addition of `?` to the type of `i`.
    assertRegion(
        region: regions[1],
        offset: migratedContent.indexOf(' as int'),
        length: ' as int'.length,
        details: []);
    assertRegion(
        region: regions[2],
        offset: migratedContent.indexOf('! + 1'),
        details: ['node with no info (never)']);
  }

  Future<void> test_return_fromOverriden() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
abstract class A {
  String m();
}
class B implements A {
  String m() => 1 == 2 ? "Hello" : null;
}
''', migratedContent: '''
abstract class A {
  String? m();
}
class B implements A {
  String? m() => 1 == 2 ? "Hello" : null;
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[0],
        offset: 27,
        details: ['An overridding method has a nullable return value']);
    assertDetail(detail: regions[0].details[0], offset: 60, length: 6);
  }

  Future<void> test_return_multipleReturns() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
String g() {
  int x = 1;
  if (x == 2) return x == 3 ? "Hello" : null;
  return "Hello";
}
''', migratedContent: '''
String? g() {
  int x = 1;
  if (x == 2) return x == 3 ? "Hello" : null;
  return "Hello";
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(1));
    assertRegion(
        region: regions[0],
        offset: 6,
        details: ['This function returns a nullable value on line 3']);
    assertInTargets(targets: unit.targets, offset: 40, length: 6); // "return"
  }

  Future<void> test_returnDetailTarget() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
String g() {
  return 1 == 2 ? "Hello" : null;
}
''', migratedContent: '''
String? g() {
  return 1 == 2 ? "Hello" : null;
}
''');
    assertInTargets(targets: unit.targets, offset: 7, length: 1); // "g"
    assertInTargets(targets: unit.targets, offset: 15, length: 6); // "return"
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(1));
    assertRegion(
        region: regions[0],
        offset: 6,
        details: ['This function returns a nullable value on line 2']);
    assertDetail(detail: regions[0].details[0], offset: 15, length: 6);
  }

  Future<void> test_returnType_function_expression() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
int _f = null;
int f() => _f;
''', migratedContent: '''
int? _f = null;
int? f() => _f;
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[0],
        offset: 3,
        details: ["This variable is initialized to an explicit 'null'"]);
    assertRegion(
        region: regions[1],
        offset: 19,
        details: ['This function returns a nullable value on line 2']);
  }

  Future<void> test_returnType_getter_block() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class A {
  int _f = null;
  int get f {
    return _f;
  }
}
''', migratedContent: '''
class A {
  int? _f = null;
  int? get f {
    return _f;
  }
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[0],
        offset: 15,
        details: ["This field is initialized to an explicit 'null'"]);
    assertRegion(
        region: regions[1],
        offset: 33,
        details: ['This getter returns a nullable value on line 4']);
  }

  Future<void> test_returnType_getter_expression() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class A {
  int _f = null;
  int get f => _f;
}
''', migratedContent: '''
class A {
  int? _f = null;
  int? get f => _f;
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[0],
        offset: 15,
        details: ["This field is initialized to an explicit 'null'"]);
    assertRegion(
        region: regions[1],
        offset: 33,
        details: ['This getter returns a nullable value on line 3']);
  }

  Future<void> test_setLiteralTypeArgument_nestedList() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f() {
  String s = null;
  var x = <List<String>>{
    ["hello"],
    if (1 == 2) [s]
  };
}
''', migratedContent: '''
void f() {
  String? s = null;
  var x = <List<String?>>{
    ["hello"],
    if (1 == 2) [s]
  };
}
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    // regions[0] is the `String? s` fix.
    assertRegion(
        region: regions[1],
        offset: 53,
        details: ['This set is initialized with a nullable value on line 5']);
    // TODO(srawlins): Actually, this is marking the `[s]`, but I think only
    //  `s` should be marked. Minor bug for now.
    assertDetail(detail: regions[1].details[0], offset: 87, length: 3);
  }

  Future<void> test_topLevelVariable() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
int _f = null;
int _f2 = _f;
''', migratedContent: '''
int? _f = null;
int? _f2 = _f;
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[0],
        offset: 3,
        details: ["This variable is initialized to an explicit 'null'"]);
    assertRegion(
        region: regions[1],
        offset: 19,
        details: ['This variable is initialized to a nullable value']);
  }

  Future<void> test_uninitializedField() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
class C {
  int value;
  C();
  C.one() {
    this.value = 7;
  }
  C.two() {}
}
''', migratedContent: '''
class C {
  int? value;
  C();
  C.one() {
    this.value = 7;
  }
  C.two() {}
}
''');
    List<RegionInfo> regions = unit.regions;
    expect(regions, hasLength(1));
    RegionInfo region = regions.single;
    assertRegion(region: region, offset: 15, details: [
      "The constructor 'C' does not initialize this field in its initializer "
          'list',
      "The constructor 'C.one' does not initialize this field in its "
          'initializer list',
      "The constructor 'C.two' does not initialize this field in its "
          'initializer list',
    ]);

    assertDetail(detail: region.details[0], offset: 25, length: 1);
    assertDetail(detail: region.details[1], offset: 34, length: 3);
    assertDetail(detail: region.details[2], offset: 70, length: 3);
  }

  Future<void> test_uninitializedVariable_notLate_uninitializedUse() async {
    UnitInfo unit = await buildInfoForSingleTestFile('''
void f() {
  int v1;
  if (1 == 2) v1 = 7;
  g(v1);
}
void g(int i) => print(i.isEven);
''', migratedContent: '''
void f() {
  int? v1;
  if (1 == 2) v1 = 7;
  g(v1!);
}
void g(int i) => print(i.isEven);
''');
    List<RegionInfo> regions = unit.fixRegions;
    expect(regions, hasLength(2));
    assertRegion(
        region: regions[0],
        offset: 16,
        details: ['Used on line 4, when it is possibly uninitialized']);
    // regions[1] is the `v1!` fix.
  }
}
