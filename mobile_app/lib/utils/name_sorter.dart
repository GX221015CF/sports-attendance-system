import 'package:lpinyin/lpinyin.dart';

import '../models/session_member.dart';

String getNameSortKey(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '\uffff';
  }

  return PinyinHelper.getPinyinE(
    trimmed,
    separator: ' ',
    format: PinyinFormat.WITHOUT_TONE,
  ).toLowerCase();
}

int compareNamesByPinyin(String a, String b) {
  final aName = a.trim();
  final bName = b.trim();

  if (aName.isEmpty && bName.isEmpty) {
    return 0;
  }
  if (aName.isEmpty) {
    return 1;
  }
  if (bName.isEmpty) {
    return -1;
  }

  final keyCompare = getNameSortKey(aName).compareTo(getNameSortKey(bName));
  if (keyCompare != 0) {
    return keyCompare;
  }

  return aName.compareTo(bName);
}

List<SessionMember> sortMembersByPinyin(List<SessionMember> members) {
  final sorted = List<SessionMember>.of(members);

  sorted.sort((a, b) {
    return compareNamesByPinyin(a.memberName, b.memberName);
  });

  return sorted;
}
