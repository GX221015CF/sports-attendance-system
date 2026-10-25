import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/attendance_motion.dart';
import '../../services/interaction_audio.dart';

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
  const AdminCreateSessionPage({
    super.key,
    this.loadGroups,
    this.loadMembers,
    this.publish,
    this.isOffline = false,
  });

  final Future<List<TeamGroup>> Function()? loadGroups;
  final Future<List<TeamMember>> Function()? loadMembers;
  final Future<String> Function(CreateSessionInput)? publish;
  final bool isOffline;

  @override
  State<AdminCreateSessionPage> createState() => _AdminCreateSessionPageState();
}

class _AdminCreateSessionPageState extends State<AdminCreateSessionPage> {
  AdminSessionService get _sessionService => AdminSessionService();
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
        widget.loadGroups?.call() ?? _sessionService.fetchGroups(),
        widget.loadMembers?.call() ?? _sessionService.fetchActiveMembers(),
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
    if (_filteredMembers.any((m) => !_selectedMemberIds.contains(m.id))) {
      InteractionAudio.instance.play(SoundCue.select);
    }
    setState(() {
      _selectedMemberIds.addAll(_filteredMembers.map((member) => member.id));
    });
  }

  void _clearSelection() {
    if (_selectedMemberIds.isNotEmpty) {
      InteractionAudio.instance.play(SoundCue.select);
    }
    setState(() {
      _selectedMemberIds.clear();
    });
  }

  void _toggleMember(String memberId, bool selected) {
    if (_selectedMemberIds.contains(memberId) == selected) return;
    InteractionAudio.instance.play(SoundCue.select);
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
      final publish = widget.publish ?? _sessionService.createSession;
      await publish(
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isOffline ? '离线任务已在本机发布，结束后可手动同步' : '签到任务已发布'),
        ),
      );

      InteractionAudio.instance.play(SoundCue.success);
      Navigator.of(context).pop(true);
    } on Object catch (_) {
      if (!mounted) {
        return;
      }
      InteractionAudio.instance.play(SoundCue.failure);

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
      return SingleChildScrollView(
        child: ErrorState(
          title: '创建数据读取失败',
          message: widget.isOffline
              ? '本机名单读取失败，请返回在线模式准备名单。'
              : '无法读取成员和分组，请检查网络连接后重试。',
          retrying: _loading,
          onRetry: _loadData,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // IME animation changes height, not the space available for columns.
        final wide = constraints.maxWidth >= 1000;
        final grid = constraints.maxWidth >= 720;
        final horizontalPadding = wide ? 24.0 : 20.0;
        final members = _filteredMembers;

        final settings = _SessionFormCard(
          titleController: _titleController,
          requiredTime: _requiredTime,
          endTime: _endTime,
          onPickRequiredTime: () => _pickDateTime(requiredTime: true),
          onPickEndTime: () => _pickDateTime(requiredTime: false),
        );
        final groups = _GroupSelector(
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
        );
        final picker = _MemberPickerHeader(
          selectedCount: _selectedMemberIds.length,
          totalCount: _members.length,
          controller: _searchController,
          onSearchChanged: _updateSearchKeyword,
          onSelectFiltered: _selectFilteredMembers,
          onClear: _clearSelection,
        );

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: _TopBar(
                submitting: _submitting,
                title: widget.isOffline ? '创建离线签到' : '创建签到',
              ),
            ),
            if (widget.isOffline)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text('仅在本机发布 · 不自动上传 · 任务结束后手动同步'),
              ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  8,
                ),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 336,
                            child: ListView(
                              key: const PageStorageKey('session-settings'),
                              children: [
                                settings,
                                const SizedBox(height: 16),
                                groups,
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: [
                                picker,
                                const SizedBox(height: 12),
                                Expanded(
                                  child: CustomScrollView(
                                    key: const PageStorageKey('wide-roster'),
                                    keyboardDismissBehavior:
                                        ScrollViewKeyboardDismissBehavior
                                            .onDrag,
                                    slivers: [
                                      _buildMemberSliver(members, true),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : CustomScrollView(
                        key: const PageStorageKey('session-form-and-roster'),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                settings,
                                const SizedBox(height: 16),
                                groups,
                                const SizedBox(height: 16),
                                picker,
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                          _buildMemberSliver(members, grid),
                        ],
                      ),
              ),
            ),
            _PublishBar(
              selectedCount: _selectedMemberIds.length,
              submitting: _submitting,
              enabled: !_loading,
              onSubmit: _submit,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMemberSliver(List<TeamMember> members, bool grid) {
    if (_members.isEmpty || members.isEmpty) {
      return SliverToBoxAdapter(
        child: _loading
            ? const LoadingSkeleton(cardHeight: 92)
            : EmptyState(
                icon: _members.isEmpty
                    ? Icons.group_off_outlined
                    : Icons.search_off,
                title: _members.isEmpty ? '暂无在队成员' : '没有匹配成员',
                message: _members.isEmpty
                    ? '请先在成员管理中新增或启用成员。'
                    : '请调整搜索关键字或分组筛选条件。',
              ),
      );
    }

    Widget memberAt(BuildContext context, int index) {
      final member = members[index];
      return _SelectableMemberCard(
        key: ValueKey(member.id),
        member: member,
        selected: _selectedMemberIds.contains(member.id),
        onChanged: (selected) => _toggleMember(member.id, selected),
      );
    }

    if (grid) {
      return SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 92,
        ),
        delegate: SliverChildBuilderDelegate(
          memberAt,
          childCount: members.length,
        ),
      );
    }
    return SliverList.builder(
      itemCount: members.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: memberAt(context, index),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.submitting, required this.title});

  final String title;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
            onPressed: submitting ? null : () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishBar extends StatelessWidget {
  const _PublishBar({
    required this.selectedCount,
    required this.submitting,
    required this.enabled,
    required this.onSubmit,
  });

  final int selectedCount;
  final bool submitting;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '已选 $selectedCount 人',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: enabled && !submitting ? onSubmit : null,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_outlined),
              label: Text(submitting ? '发布中...' : '发布签到'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
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

class _SelectableMemberCard extends StatelessWidget {
  const _SelectableMemberCard({
    super.key,
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
