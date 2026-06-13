import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../models/member.dart';
import '../../theme/app_theme.dart';

class MemberFormSheet extends StatefulWidget {
  const MemberFormSheet({
    super.key,
    required this.groups,
    required this.onSubmit,
    this.member,
  });

  final List<TeamGroup> groups;
  final TeamMember? member;
  final Future<void> Function(MemberInput input) onSubmit;

  @override
  State<MemberFormSheet> createState() => _MemberFormSheetState();
}

class _MemberFormSheetState extends State<MemberFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _studentIdController;
  late final TextEditingController _phoneController;
  String? _gender;
  String? _groupId;
  bool _isActive = true;
  bool _submitting = false;
  String? _errorMessage;

  bool get _editing => widget.member != null;

  @override
  void initState() {
    super.initState();

    final member = widget.member;
    _nameController = TextEditingController(text: member?.name ?? '');
    _studentIdController = TextEditingController(text: member?.studentId ?? '');
    _phoneController = TextEditingController(text: member?.phone ?? '');
    _gender = member?.gender;
    _groupId = member?.groupId;
    _isActive = member?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _phoneController.dispose();
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
        MemberInput(
          name: _nameController.text.trim(),
          studentId: _nullableText(_studentIdController.text),
          gender: _gender,
          phone: _nullableText(_phoneController.text),
          groupId: _groupId,
          isActive: _isActive,
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
        _errorMessage = _editing ? '成员更新失败，请稍后重试。' : '成员新增失败，请稍后重试。';
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
                      _editing ? '编辑成员' : '新增成员',
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
                  labelText: '姓名',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return '请输入姓名';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _studentIdController,
                enabled: !_submitting,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '学号',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: '性别',
                  prefixIcon: Icon(Icons.wc_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: '男', child: Text('男')),
                  DropdownMenuItem(value: '女', child: Text('女')),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        setState(() {
                          _gender = value;
                        });
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                enabled: !_submitting,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '手机号',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _groupId ?? '',
                decoration: const InputDecoration(
                  labelText: '分组',
                  prefixIcon: Icon(Icons.groups_2_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('未分组')),
                  ...widget.groups.map(
                    (group) => DropdownMenuItem(
                      value: group.id,
                      child: Text(group.name),
                    ),
                  ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        setState(() {
                          _groupId = value?.isEmpty == true ? null : value;
                        });
                      },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _isActive,
                onChanged: _submitting
                    ? null
                    : (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                title: const Text('是否在队'),
                subtitle: Text(_isActive ? '在队成员会参与后续签到' : '离队成员默认不参与签到'),
                contentPadding: EdgeInsets.zero,
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
                  _submitting ? '提交中...' : (_editing ? '保存修改' : '新增成员'),
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
