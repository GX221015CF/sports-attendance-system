import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../form_surface.dart';

class GroupFormSheet extends StatefulWidget {
  const GroupFormSheet({super.key, required this.onSubmit, this.group});

  final TeamGroup? group;
  final Future<void> Function(GroupInput input) onSubmit;

  @override
  State<GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends State<GroupFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _submitting = false;
  String? _errorMessage;

  bool get _editing => widget.group != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.group?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        GroupInput(
          name: _nameController.text.trim(),
          description: _nullableText(_descriptionController.text),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _editing ? '分组更新失败，请稍后重试。' : '分组新增失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) => FormSurface(
    title: _editing ? '编辑分组' : '新增分组',
    submitLabel: _editing ? '保存修改' : '新增分组',
    busy: _submitting,
    errorMessage: _errorMessage,
    onSubmit: _handleSubmit,
    child: Form(
      key: _formKey,
      child: ResponsiveFormFields(
        children: [
          TextFormField(
            controller: _nameController,
            enabled: !_submitting,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '分组名称',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return '请输入分组名称';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _descriptionController,
            enabled: !_submitting,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '描述',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    ),
  );
}
