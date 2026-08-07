import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/admin_session.dart';
import '../../models/group.dart';
import '../../models/member.dart';
import '../../services/admin_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/wheel_time_picker.dart';

class AdminCreateSessionPage extends StatefulWidget {
  const AdminCreateSessionPage({super.key});

  @override
  State<AdminCreateSessionPage> createState() => _AdminCreateSessionPageState();
}

class _AdminCreateSessionPageState extends State<AdminCreateSessionPage> {
  final _sessionService = AdminSessionService();
  final _titleController = TextEditingController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = false;
  bool _submitting = false;
  String? _errorMessage;
  DateTime? _requiredTime;
  DateTime? _endTime;
  String _keyword = '';
  final Set<String> _selectedGroupIds = {};
  final Set<String> _selectedMemberIds = {};
  List<TeamGroup> _groups = const [];
  List<TeamMember> _members = const [];

  List<TeamMember> get _filteredMembers {
    return _members.where((member) {
      final matchesKeyword = _keyword.isEmpty || member.name.contains(_keyword);
      final matchesGroups =
          _selectedGroupIds.isEmpty ||
          (member.groupId != null &&
              _selectedGroupIds.contains(member.groupId));

      return matchesKeyword && matchesGroups;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _titleController.text = formatTrainingSessionTitle(DateTime.now());
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearchKeyword(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _keyword == value.trim()) {
        return;
      }
      setState(() {
        _keyword = value.trim();
      });
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _sessionService.fetchGroups(),
        _sessionService.fetchActiveMembers(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _groups = results[0] as List<TeamGroup>;
        _members = results[1] as List<TeamMember>;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDateTime({required bool requiredTime}) async {
    final now = DateTime.now();

    if (!requiredTime && _requiredTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择规定签到时间')));
      return;
    }

    final current = requiredTime
        ? _requiredTime
        : (_endTime ?? _requiredTime?.add(const Duration(minutes: 30)));
    final firstDate = requiredTime ? DateTime(now.year - 1) : _requiredTime!;
    final initialDate = current ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 2),
      helpText: requiredTime ? '选择规定签到日期' : '选择签到结束日期',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showWheelTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
      title: requiredTime ? '选择规定签到时间' : '选择签到结束时间',
    );

    if (time == null || !mounted) {
      return;
    }

    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      0,
      0,
    );

    if (!requiredTime && !value.isAfter(_requiredTime!)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束时间必须晚于规定签到时间')));
      return;
    }

    var endTimeAdjusted = false;
    setState(() {
      if (requiredTime) {
        _requiredTime = value;
        if (_endTime == null || !_endTime!.isAfter(value)) {
          _endTime = value.add(const Duration(minutes: 30));
          endTimeAdjusted = true;
        }
      } else {
        _endTime = value;
      }
    });

    if (endTimeAdjusted && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束时间已自动调整为规定时间后 30 分钟')));
    }
  }

  void _selectFilteredMembers() {
    setState(() {
      _selectedMemberIds.addAll(_filteredMembers.map((member) => member.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMemberIds.clear();
    });
  }

  void _toggleMember(String memberId, bool selected) {
    setState(() {
      if (selected) {
        _selectedMemberIds.add(memberId);
      } else {
        _selectedMemberIds.remove(memberId);
      }
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final requiredTime = _requiredTime;
    final endTime = _endTime;

    String? validationError;
    if (title.isEmpty) {
      validationError = '请输入签到标题。';
    } else if (requiredTime == null) {
      validationError = '请选择规定签到时间。';
    } else if (endTime == null) {
      validationError = '请选择签到结束时间。';
    } else if (!endTime.isAfter(requiredTime)) {
      validationError = '签到结束时间必须晚于规定签到时间。';
    } else if (_selectedMemberIds.isEmpty) {
      validationError = '请至少选择 1 名成员。';
    }

    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await _sessionService.createSession(
        CreateSessionInput(
          title: title,
          requiredTime: requiredTime!,
          endTime: endTime!,
          memberIds: _selectedMemberIds.toList(),
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('签到任务已发布')));

      Navigator.of(context).pop(true);
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('签到任务发布失败，请稍后重试。')));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: _buildBody(context)));
  }

  Widget _buildBody(BuildContext context) {
    if (_errorMessage != null) {
      return ErrorState(
        title: '创建数据读取失败',
        message: '无法读取成员和分组，请检查网络连接后重试。',
        retrying: _loading,
        onRetry: _loadData,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth > constraints.maxHeight ||
            constraints.maxWidth >= 720;
        final filteredMembers = _filteredMembers;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 28 : 20,
            compact ? 8 : 14,
            compact ? 28 : 20,
            24,
          ),
          children: [
            _TopBar(submitting: _submitting, onSubmit: _submit),
            SizedBox(height: compact ? 12 : 18),
            if (_loading) const LinearProgressIndicator(),
            if (_loading) SizedBox(height: compact ? 12 : 16),
            _SessionFormCard(
              titleController: _titleController,
              requiredTime: _requiredTime,
              endTime: _endTime,
              onPickRequiredTime: () => _pickDateTime(requiredTime: true),
              onPickEndTime: () => _pickDateTime(requiredTime: false),
            ),
            SizedBox(height: compact ? 12 : 16),
            _GroupSelector(
              groups: _groups,
              selectedGroupIds: _selectedGroupIds,
              onChanged: (groupId, selected) {
                setState(() {
                  if (selected) {
                    _selectedGroupIds.add(groupId);
                  } else {
                    _selectedGroupIds.remove(groupId);
                  }
                });
              },
            ),
            SizedBox(height: compact ? 12 : 16),
            _MemberPickerHeader(
              selectedCount: _selectedMemberIds.length,
              totalCount: _members.length,
              controller: _searchController,
              onSearchChanged: _updateSearchKeyword,
              onSelectFiltered: _selectFilteredMembers,
              onClear: _clearSelection,
            ),
            const SizedBox(height: 12),
            if (_members.isEmpty)
              const EmptyState(
                icon: Icons.group_off_outlined,
                title: '暂无在队成员',
                message: '请先在成员管理中新增或启用成员。',
              )
            else if (filteredMembers.isEmpty)
              const EmptyState(
                icon: Icons.search_off,
                title: '没有匹配成员',
                message: '请调整搜索关键字或分组筛选条件。',
              )
            else if (compact)
              _MemberGrid(
                members: filteredMembers,
                selectedMemberIds: _selectedMemberIds,
                onChanged: _toggleMember,
              )
            else
              _MemberList(
                members: filteredMembers,
                selectedMemberIds: _selectedMemberIds,
                onChanged: _toggleMember,
              ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_outlined),
              label: Text(_submitting ? '发布中...' : '发布签到'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.submitting, required this.onSubmit});

  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
            onPressed: submitting ? null : () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '创建签到',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: submitting ? null : onSubmit,
            icon: const Icon(Icons.publish_outlined),
            label: const Text('发布'),
          ),
        ],
      ),
    );
  }
}

class _SessionFormCard extends StatelessWidget {
  const _SessionFormCard({
    required this.titleController,
    required this.requiredTime,
    required this.endTime,
    required this.onPickRequiredTime,
    required this.onPickEndTime,
  });

  final TextEditingController titleController;
  final DateTime? requiredTime;
  final DateTime? endTime;
  final VoidCallback onPickRequiredTime;
  final VoidCallback onPickEndTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: '签到标题',
              hintText: '例如：晚训签到',
              prefixIcon: Icon(Icons.edit_note_outlined),
            ),
          ),
          const SizedBox(height: 12),
          _DateTimeTile(
            icon: Icons.schedule,
            label: '规定签到时间',
            value: requiredTime == null ? '请选择' : formatDateTime(requiredTime!),
            onTap: onPickRequiredTime,
          ),
          const SizedBox(height: 10),
          _DateTimeTile(
            icon: Icons.alarm_off_outlined,
            label: '签到结束时间',
            value: endTime == null ? '请选择' : formatDateTime(endTime!),
            onTap: onPickEndTime,
          ),
        ],
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textStrong,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    required this.groups,
    required this.selectedGroupIds,
    required this.onChanged,
  });

  final List<TeamGroup> groups;
  final Set<String> selectedGroupIds;
  final void Function(String groupId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择分组',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textStrong,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          if (groups.isEmpty)
            Text(
              '暂无分组，成员列表将显示全部在队成员。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final group in groups)
                  FilterChip(
                    label: Text(group.name),
                    selected: selectedGroupIds.contains(group.id),
                    onSelected: (selected) => onChanged(group.id, selected),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MemberPickerHeader extends StatelessWidget {
  const _MemberPickerHeader({
    required this.selectedCount,
    required this.totalCount,
    required this.controller,
    required this.onSearchChanged,
    required this.onSelectFiltered,
    required this.onClear,
  });

  final int selectedCount;
  final int totalCount;
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSelectFiltered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '选择成员：$selectedCount / $totalCount',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textStrong,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSelectFiltered,
                child: const Text('全选当前'),
              ),
              TextButton(onPressed: onClear, child: const Text('清空')),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '按姓名搜索',
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.members,
    required this.selectedMemberIds,
    required this.onChanged,
  });

  final List<TeamMember> members;
  final Set<String> selectedMemberIds;
  final void Function(String memberId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final member in members)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SelectableMemberCard(
              member: member,
              selected: selectedMemberIds.contains(member.id),
              onChanged: (selected) => onChanged(member.id, selected),
            ),
          ),
      ],
    );
  }
}

class _MemberGrid extends StatelessWidget {
  const _MemberGrid({
    required this.members,
    required this.selectedMemberIds,
    required this.onChanged,
  });

  final List<TeamMember> members;
  final Set<String> selectedMemberIds;
  final void Function(String memberId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: members.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 92,
      ),
      itemBuilder: (context, index) {
        final member = members[index];
        return _SelectableMemberCard(
          member: member,
          selected: selectedMemberIds.contains(member.id),
          onChanged: (selected) => onChanged(member.id, selected),
        );
      },
    );
  }
}

class _SelectableMemberCard extends StatelessWidget {
  const _SelectableMemberCard({
    required this.member,
    required this.selected,
    required this.onChanged,
  });

  final TeamMember member;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final groupName = member.groupName?.isNotEmpty == true
        ? member.groupName!
        : '未分组';
    final studentId = member.studentId?.isNotEmpty == true
        ? member.studentId!
        : '未填学号';

    return Material(
      color: selected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!selected),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (value) => onChanged(value ?? false),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textStrong,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$groupName · $studentId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
