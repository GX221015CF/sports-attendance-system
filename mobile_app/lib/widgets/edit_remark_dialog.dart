import 'package:flutter/material.dart';

import 'form_surface.dart';

Future<bool?> showEditRemarkSheet({
  required BuildContext context,
  required String memberName,
  required String statusLabel,
  required String initialRemark,
  required Future<void> Function(String remark) onSave,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 800),
    sheetAnimationStyle: formSheetAnimationStyle(context),
    builder: (_) => EditRemarkDialog(
      memberName: memberName,
      statusLabel: statusLabel,
      initialRemark: initialRemark,
      onSave: onSave,
    ),
  );
}

class EditRemarkDialog extends StatefulWidget {
  const EditRemarkDialog({
    super.key,
    required this.memberName,
    required this.statusLabel,
    required this.initialRemark,
    required this.onSave,
  });

  final String memberName;
  final String statusLabel;
  final String initialRemark;
  final Future<void> Function(String remark) onSave;

  @override
  State<EditRemarkDialog> createState() => _EditRemarkDialogState();
}

class _EditRemarkDialogState extends State<EditRemarkDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialRemark);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(_controller.text);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '备注保存失败，请稍后重试。';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => FormSurface(
    title: '编辑备注',
    caption: '${widget.memberName} · ${widget.statusLabel}',
    submitLabel: '保存',
    busy: _saving,
    errorMessage: _errorMessage,
    maxWidth: 800,
    onSubmit: _handleSave,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('可填写请假、伤病、迟到原因等说明。清空内容后保存即可删除备注。'),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          enabled: !_saving,
          minLines: 3,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: '请输入备注，可留空',
            alignLabelWithHint: true,
          ),
        ),
      ],
    ),
  );
}
