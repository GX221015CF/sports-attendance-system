import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../models/member.dart';
import '../../services/interaction_audio.dart';
import '../form_surface.dart';

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
        InteractionAudio.instance.play(SoundCue.success);
        Navigator.of(context).pop(true);
      }
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _editing ? '成员更新失败，请稍后重试。' : '成员新增失败，请稍后重试。';
      });
      InteractionAudio.instance.play(SoundCue.failure);
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
    title: _editing ? '编辑成员' : '新增成员',
    submitLabel: _editing ? '保存修改' : '新增成员',
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
          TextFormField(
            controller: _studentIdController,
            enabled: !_submitting,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '学号',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
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
          TextFormField(
            controller: _phoneController,
            enabled: !_submitting,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: const InputDecoration(
              labelText: '手机号',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _groupId ?? '',
            decoration: const InputDecoration(
              labelText: '分组',
              prefixIcon: Icon(Icons.groups_2_outlined),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('未分组')),
              ...widget.groups.map(
                (group) =>
                    DropdownMenuItem(value: group.id, child: Text(group.name)),
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
        ],
      ),
    ),
  );
}
