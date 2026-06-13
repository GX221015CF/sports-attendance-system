import dayjs from 'dayjs'
import * as XLSX from 'xlsx'

export type ExportSessionStatus = 'active' | 'closed'
export type ExportCheckinStatus = 'pending' | 'normal' | 'late' | 'absent'

export type ExportSession = {
  id: string
  title: string
  status: ExportSessionStatus
  required_time: string
  end_time: string
  created_at: string | null
}

export type ExportSessionMember = {
  session_id: string
  member_id: string | null
  status: ExportCheckinStatus
  checkin_time: string | null
  late_minutes: number | null
  member_name: string
  student_id: string | null
  gender: string | null
  phone: string | null
  group_name: string
  remark: string | null
}

type SessionStats = {
  total: number
  normal: number
  late: number
  absent: number
  pending: number
}

type MemberSummary = {
  key: string
  name: string
  studentId: string
  gender: string
  phone: string
  groupName: string
  records: Map<string, ExportSessionMember>
  normal: number
  late: number
  absent: number
  pending: number
}

const detailHeaders = [
  '签到标题',
  '签到状态',
  '姓名',
  '学号',
  '性别',
  '手机号',
  '分组',
  '规定签到时间',
  '结束时间',
  '实际签到时间',
  '签到结果',
  '迟到分钟数',
  '备注',
]

function emptyStats(): SessionStats {
  return {
    total: 0,
    normal: 0,
    late: 0,
    absent: 0,
    pending: 0,
  }
}

function formatTime(value: string | null) {
  return value ? dayjs(value).format('YYYY-MM-DD HH:mm') : ''
}

function getSessionStatusText(status: ExportSessionStatus) {
  return status === 'active' ? '进行中' : '已结束'
}

function getCheckinStatusText(status: ExportCheckinStatus) {
  const statusMap: Record<ExportCheckinStatus, string> = {
    pending: '未签到',
    normal: '正常',
    late: '迟到',
    absent: '缺勤',
  }

  return statusMap[status]
}

function safeValue(value: string | number | null | undefined) {
  return value ?? ''
}

function getAttendanceRate(checked: number, total: number) {
  if (total === 0) {
    return '0%'
  }

  return `${((checked / total) * 100).toFixed(2)}%`
}

function getStats(members: ExportSessionMember[]) {
  return members.reduce((stats, member) => {
    stats.total += 1
    stats[member.status] += 1
    return stats
  }, emptyStats())
}

function sanitizeSheetName(value: string) {
  const sanitized = value.replace(/[:\\/?*[\]]/g, '_').trim() || '签到任务'
  return sanitized.slice(0, 31)
}

function getUniqueSheetName(title: string, usedNames: Set<string>) {
  const base = sanitizeSheetName(title)
  let candidate = base
  let index = 2

  while (usedNames.has(candidate)) {
    const suffix = `_${index}`
    candidate = `${base.slice(0, 31 - suffix.length)}${suffix}`
    index += 1
  }

  usedNames.add(candidate)
  return candidate
}

function getMemberMergeKey(member: ExportSessionMember) {
  if (member.member_id) {
    return `id:${member.member_id}`
  }

  return `fallback:${member.student_id ?? ''}:${member.member_name}`
}

function getUniqueSessionTitles(sessions: ExportSession[]) {
  const counts = new Map<string, number>()

  return sessions.map((session) => {
    const baseTitle = session.title.trim() || '未命名签到'
    const count = (counts.get(baseTitle) ?? 0) + 1
    counts.set(baseTitle, count)

    return {
      session,
      title: count === 1 ? baseTitle : `${baseTitle}(${count})`,
    }
  })
}

function createDetailRows(
  session: ExportSession,
  members: ExportSessionMember[],
) {
  return members.map((member) => ({
    签到标题: session.title || '未命名签到',
    签到状态: getSessionStatusText(session.status),
    姓名: safeValue(member.member_name),
    学号: safeValue(member.student_id),
    性别: safeValue(member.gender),
    手机号: safeValue(member.phone),
    分组: safeValue(member.group_name),
    规定签到时间: formatTime(session.required_time),
    结束时间: formatTime(session.end_time),
    实际签到时间: formatTime(member.checkin_time),
    签到结果: getCheckinStatusText(member.status),
    迟到分钟数: member.late_minutes ?? 0,
    备注: member.remark ?? '',
  }))
}

export function buildSessionOverviewRows(
  sessions: ExportSession[],
  membersBySessionId: Map<string, ExportSessionMember[]>,
) {
  return sessions.map((session) => {
    const sessionMembers = membersBySessionId.get(session.id) ?? []
    const stats = getStats(sessionMembers)
    const checked = stats.normal + stats.late

    return {
      签到标题: session.title || '未命名签到',
      签到状态: getSessionStatusText(session.status),
      规定签到时间: formatTime(session.required_time),
      结束时间: formatTime(session.end_time),
      创建时间: formatTime(session.created_at),
      参与人数: stats.total,
      正常人数: stats.normal,
      迟到人数: stats.late,
      缺勤人数: stats.absent,
      未签到人数: stats.pending,
      已签到人数: checked,
      出勤率: getAttendanceRate(checked, stats.total),
    }
  })
}

export function buildMergedMemberRows(
  sessions: ExportSession[],
  members: ExportSessionMember[],
) {
  const sessionTitles = getUniqueSessionTitles(sessions)
  const summaries = new Map<string, MemberSummary>()

  members.forEach((member) => {
    const key = getMemberMergeKey(member)
    const summary =
      summaries.get(key) ??
      ({
        key,
        name: member.member_name || '',
        studentId: member.student_id ?? '',
        gender: member.gender ?? '',
        phone: member.phone ?? '',
        groupName: member.group_name || '未分组',
        records: new Map<string, ExportSessionMember>(),
        normal: 0,
        late: 0,
        absent: 0,
        pending: 0,
      } satisfies MemberSummary)

    summary.name ||= member.member_name || ''
    summary.studentId ||= member.student_id ?? ''
    summary.gender ||= member.gender ?? ''
    summary.phone ||= member.phone ?? ''
    summary.groupName ||= member.group_name || '未分组'
    summary.records.set(member.session_id, member)
    summary[member.status] += 1
    summaries.set(key, summary)
  })

  return Array.from(summaries.values())
    .sort((a, b) => {
      const groupCompare = a.groupName.localeCompare(b.groupName, 'zh-CN')
      if (groupCompare !== 0) {
        return groupCompare
      }

      return a.name.localeCompare(b.name, 'zh-CN')
    })
    .map((summary) => {
      const row: Record<string, string | number> = {
        姓名: summary.name,
        学号: summary.studentId,
        性别: summary.gender,
        手机号: summary.phone,
        分组: summary.groupName,
      }

      sessionTitles.forEach(({ session, title }) => {
        const record = summary.records.get(session.id)
        row[`${title}-状态`] = record ? getCheckinStatusText(record.status) : ''
        row[`${title}-签到时间`] = record ? formatTime(record.checkin_time) : ''
        row[`${title}-迟到分钟`] = record ? record.late_minutes ?? 0 : ''
        row[`${title}-备注`] = record ? record.remark ?? '' : ''
      })

      const shouldAttend = summary.records.size
      const checked = summary.normal + summary.late
      row.正常次数 = summary.normal
      row.迟到次数 = summary.late
      row.缺勤次数 = summary.absent
      row.未签到次数 = summary.pending
      row.已签到次数 = checked
      row.应签到次数 = shouldAttend
      row.出勤率 = getAttendanceRate(checked, shouldAttend)

      return row
    })
}

export function exportBatchSessionsMergedExcel(
  sessions: ExportSession[],
  members: ExportSessionMember[],
) {
  const sortedSessions = [...sessions].sort((a, b) => {
    const aTime = dayjs(a.required_time || a.created_at).valueOf()
    const bTime = dayjs(b.required_time || b.created_at).valueOf()
    return aTime - bTime
  })
  const membersBySessionId = new Map<string, ExportSessionMember[]>()

  members.forEach((member) => {
    const rows = membersBySessionId.get(member.session_id) ?? []
    rows.push(member)
    membersBySessionId.set(member.session_id, rows)
  })

  const workbook = XLSX.utils.book_new()
  const memberRows = buildMergedMemberRows(sortedSessions, members)
  const memberSheet = XLSX.utils.json_to_sheet(memberRows)
  XLSX.utils.book_append_sheet(workbook, memberSheet, '人员汇总')

  const overviewRows = buildSessionOverviewRows(
    sortedSessions,
    membersBySessionId,
  )
  const overviewSheet = XLSX.utils.json_to_sheet(overviewRows)
  XLSX.utils.book_append_sheet(workbook, overviewSheet, '签到总览')

  const usedSheetNames = new Set<string>(['人员汇总', '签到总览'])

  sortedSessions.forEach((session) => {
    const sessionMembers = membersBySessionId.get(session.id) ?? []
    const detailRows = createDetailRows(session, sessionMembers)
    const worksheet =
      detailRows.length > 0
        ? XLSX.utils.json_to_sheet(detailRows, { header: detailHeaders })
        : XLSX.utils.aoa_to_sheet([detailHeaders])
    const sheetName = getUniqueSheetName(session.title, usedSheetNames)

    XLSX.utils.book_append_sheet(workbook, worksheet, sheetName)
  })

  const timestamp = dayjs().format('YYYYMMDD_HHmm')
  XLSX.writeFile(workbook, `批量签到结果_${timestamp}.xlsx`)
}

export const exportSessionsExcel = exportBatchSessionsMergedExcel
