import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/group.dart';
import 'package:mobile_app/models/member.dart';
import 'package:mobile_app/pages/admin/admin_login_page.dart';
import 'package:mobile_app/services/admin_auth_service.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/widgets/admin/group_form_sheet.dart';
import 'package:mobile_app/widgets/admin/member_form_sheet.dart';
import 'package:mobile_app/widgets/edit_remark_dialog.dart';
import 'package:mobile_app/widgets/form_surface.dart';

class FormProbe {
  int calls = 0;
  bool fail = false;
  bool? result;
  Completer<void>? pending;
  MemberInput? member;
  GroupInput? group;
  String? remark;
  Future<void> submit() async {
    calls++;
    await pending?.future;
    if (fail) throw StateError('synthetic failure');
  }
}

class LoginFixture implements AdminAuthService {
  LoginFixture(this.probe);
  final FormProbe probe;
  @override
  Future<void> signIn({required String email, required String password}) =>
      probe.submit();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget formHarness(
  String kind,
  FormProbe probe, {
  bool reduced = false,
  double scale = 1,
}) => MaterialApp(
  theme: AppTheme.lightTheme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: reduced,
      textScaler: TextScaler.linear(scale),
    ),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          child: const Text('打开表单'),
          onPressed: () async {
            if (kind == 'login') {
              probe.result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AdminLoginPage(
                    returnAfterLogin: true,
                    authService: LoginFixture(probe),
                  ),
                ),
              );
            } else if (kind == 'remark') {
              probe.result = await showEditRemarkSheet(
                context: context,
                memberName: '合成测试成员',
                statusLabel: '正常',
                initialRemark: '旧合成备注',
                onSave: (value) async {
                  probe.remark = value;
                  await probe.submit();
                },
              );
            } else {
              probe.result = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                constraints: const BoxConstraints(maxWidth: 960),
                backgroundColor: Colors.transparent,
                sheetAnimationStyle: formSheetAnimationStyle(context),
                builder: (_) => kind == 'member'
                    ? MemberFormSheet(
                        groups: const [
                          TeamGroup(id: 'fixture-group', name: '合成测试组'),
                        ],
                        onSubmit: (value) async {
                          probe.member = value;
                          await probe.submit();
                        },
                      )
                    : GroupFormSheet(
                        onSubmit: (value) async {
                          probe.group = value;
                          await probe.submit();
                        },
                      ),
              );
            }
          },
        ),
      ),
    ),
  ),
);

Future<void> openForm(
  WidgetTester tester,
  String kind,
  FormProbe probe, {
  bool reduced = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    formHarness(kind, probe, reduced: reduced, scale: scale),
  );
  await tester.tap(find.text('打开表单'));
  await tester.pumpAndSettle();
}

Future<void> fillForm(WidgetTester tester, String kind) async {
  if (kind == 'login') {
    await tester.enterText(
      find.widgetWithText(TextFormField, '邮箱'),
      'fixture@example.invalid',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '密码'),
      'fixture-password',
    );
  } else if (kind == 'member') {
    await tester.enterText(find.widgetWithText(TextFormField, '姓名'), '合成成员');
    await tester.enterText(
      find.widgetWithText(TextFormField, '学号'),
      'TEST-001',
    );
  } else if (kind == 'group') {
    await tester.enterText(find.widgetWithText(TextFormField, '分组名称'), '合成分组');
    await tester.enterText(find.widgetWithText(TextFormField, '描述'), '合成描述');
  } else {
    await tester.enterText(find.widgetWithText(TextField, '请输入备注，可留空'), '合成备注');
  }
}

Finder submitButton() => find.descendant(
  of: find.byType(SubmissionButton),
  matching: find.byType(ElevatedButton),
);

void main() {
  for (final kind in ['login', 'member', 'group', 'remark']) {
    for (final scenario in [
      (const Size(420, 900), 400.0),
      (const Size(1180, 820), 520.0),
      (const Size(800, 360), 180.0),
    ]) {
      testWidgets('$kind pins submit above keyboard at ${scenario.$1}', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.$1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        final probe = FormProbe();
        await openForm(tester, kind, probe);
        await fillForm(tester, kind);
        if (kind == 'member' && scenario.$1.width == 1180) {
          expect(
            tester.getTopLeft(find.widgetWithText(TextFormField, '姓名')).dy,
            tester.getTopLeft(find.widgetWithText(TextFormField, '学号')).dy,
          );
        }
        final inputs = tester
            .widgetList<TextField>(find.byType(TextField))
            .map((field) => field.controller!.text)
            .toList();
        for (final inset in [scenario.$2 / 2, scenario.$2]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            submitButton().hitTestable(),
            findsOneWidget,
            reason: 'inset=$inset rect=${tester.getRect(submitButton())}',
          );
        }
        expect(
          tester
              .widgetList<TextField>(find.byType(TextField))
              .map((field) => field.controller!.text)
              .toList(),
          inputs,
        );
        expect(probe.calls, 0);
        if (kind == 'group' && scenario.$1.width == 800) {
          expect(tester.binding.focusManager.primaryFocus?.hasFocus, isTrue);
          await tester.tap(submitButton());
          await tester.pumpAndSettle();
          expect(probe.calls, 1);
          expect(probe.result, isTrue);
        }
      });
    }

    testWidgets(
      '$kind pending save rejects repeats and only closes after confirmation',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1180, 820));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final probe = FormProbe()..pending = Completer<void>();
        await openForm(tester, kind, probe);
        await fillForm(tester, kind);
        final before = tester.getSize(submitButton());
        await tester.tap(submitButton());
        await tester.pump(const Duration(milliseconds: 160));
        expect(probe.calls, 1);
        expect(tester.widget<ElevatedButton>(submitButton()).onPressed, isNull);
        expect(tester.getSize(submitButton()), before);
        expect(probe.result, isNull);
        probe.pending!.complete();
        await tester.pumpAndSettle();
        expect(probe.result, isTrue);
        expect(probe.calls, 1);
        expect(find.text('打开表单').hitTestable(), findsOneWidget);
      },
    );

    testWidgets('$kind failure keeps draft and permits an explicit retry', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1180, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final probe = FormProbe()..fail = true;
      await openForm(tester, kind, probe);
      await fillForm(tester, kind);
      final draft = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller!.text)
          .toList();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();
      expect(probe.calls, 1);
      expect(probe.result, isNull);
      expect(find.byType(InlineFeedback), findsOneWidget);
      expect(
        tester.widget<InlineFeedback>(find.byType(InlineFeedback)).message,
        isNotNull,
      );
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .map((field) => field.controller!.text)
            .toList(),
        draft,
      );
      probe.fail = false;
      await tester.tap(submitButton());
      await tester.pumpAndSettle();
      expect(probe.calls, 2);
      expect(probe.result, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$kind cancel does not save', (tester) async {
      final probe = FormProbe();
      await openForm(tester, kind, probe);
      await fillForm(tester, kind);
      await tester.tap(
        kind == 'login' ? find.byIcon(Icons.arrow_back) : find.text('取消'),
      );
      await tester.pumpAndSettle();
      expect(probe.calls, 0);
      expect(find.text('打开表单').hitTestable(), findsOneWidget);
    });

    testWidgets('$kind large text still exposes the primary action', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openForm(tester, kind, FormProbe(), scale: 1.6);
      expect(tester.takeException(), isNull);
      expect(submitButton().hitTestable(), findsOneWidget);
    });
  }

  for (final kind in ['login', 'member', 'group']) {
    testWidgets('$kind preserves required-field validation', (tester) async {
      final probe = FormProbe();
      await openForm(tester, kind, probe);
      await tester.tap(submitButton());
      await tester.pumpAndSettle();
      expect(probe.calls, 0);
      expect(
        find.text(
          kind == 'login'
              ? '请输入邮箱'
              : kind == 'member'
              ? '请输入姓名'
              : '请输入分组名称',
        ),
        findsOneWidget,
      );
    });
  }
  testWidgets('remark can still be cleared and saved', (tester) async {
    final probe = FormProbe();
    await openForm(tester, 'remark', probe);
    await tester.enterText(find.widgetWithText(TextField, '请输入备注，可留空'), '');
    await tester.tap(submitButton());
    await tester.pumpAndSettle();
    expect(probe.remark, '');
    expect(probe.result, isTrue);
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'feedback respects reduced motion $reduced and keeps waiting text',
      (tester) async {
        final probe = FormProbe()..pending = Completer<void>();
        await openForm(tester, 'group', probe, reduced: reduced);
        await fillForm(tester, 'group');
        await tester.tap(submitButton());
        await tester.pump(const Duration(milliseconds: 160));
        expect(find.text('保存中…'), findsOneWidget);
        if (reduced) {
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
          final transition = tester.widget<AnimatedSwitcher>(
            find.descendant(
              of: find.byType(SubmissionButton),
              matching: find.byType(AnimatedSwitcher),
            ),
          );
          expect(transition.duration, Duration.zero);
        } else {
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        }
        probe.pending!.completeError(StateError('synthetic failure'));
        await tester.pumpAndSettle();
        expect(find.text('分组新增失败，请稍后重试。'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
