import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../theme/app_theme.dart';

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
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? '编辑分组' : '新增分组',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textStrong,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_errorMessage != null) ...[
                _ErrorNotice(message: _errorMessage!),
                const SizedBox(height: 12),
              ],
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                enabled: !_submitting,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '描述',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _handleSubmit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _submitting ? '提交中...' : (_editing ? '保存修改' : '新增分组'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
