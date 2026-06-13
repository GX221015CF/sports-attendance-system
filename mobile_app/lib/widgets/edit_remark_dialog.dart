import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '编辑备注',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.memberName} · ${widget.statusLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE0E7FF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '备注为自由文本，可填写请假、伤病、迟到原因等说明。清空内容后保存即可删除备注。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        enabled: !_saving,
                        autofocus: false,
                        minLines: 3,
                        maxLines: 6,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: '请输入备注，可留空',
                          alignLabelWithHint: true,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _handleSave,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.secondary,
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('保存'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
