import {
  Alert,
  Button,
  Card,
  Col,
  Descriptions,
  Popconfirm,
  Row,
  Space,
  Spin,
  Statistic,
  Table,
  Tag,
  Typography,
  message,
} from 'antd'
import type { ColumnsType } from 'antd/es/table'
import dayjs from 'dayjs'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import * as XLSX from 'xlsx'
import { supabase } from '../api/supabase'

type SessionStatus = 'active' | 'closed'
type CheckinStatus = 'pending' | 'normal' | 'late' | 'absent'

type AttendanceSession = {
  id: string
  title: string
  required_time: string
  end_time: string
  status: SessionStatus
  created_at: string | null
}

type RelatedGroup = { name: string | null } | { name: string | null }[] | null

type RelatedMember =
  | {
      name: string | null
      student_id: string | null
      gender: string | null
      phone: string | null
      groups: RelatedGroup
    }
  | {
      name: string | null
      student_id: string | null
      gender: string | null
      phone: string | null
      groups: RelatedGroup
    }[]
  | null

type RawSessionMember = {
  id: string
  status: CheckinStatus
  checkin_time: string | null
  late_minutes: number | null
  members: RelatedMember
}

type DetailMemberRow = {
  id: string
  name: string
  student_id: string | null
  gender: string | null
  phone: string | null
  group_name: string
  status: CheckinStatus
  checkin_time: string | null
  late_minutes: number
}

function formatTime(value: string | null) {
  return value ? dayjs(value).format('YYYY-MM-DD HH:mm') : '-'
}

function getSingleMember(raw: RelatedMember) {
  if (Array.isArray(raw)) {
    return raw[0] ?? null
  }

  return raw
}

function getGroupName(groups: RelatedGroup | undefined) {
  if (Array.isArray(groups)) {
    return groups[0]?.name ?? '未分组'
  }

  return groups?.name ?? '未分组'
}

function renderSessionStatus(status: SessionStatus) {
  return status === 'active' ? (
    <Tag color="green">进行中</Tag>
  ) : (
    <Tag color="default">已结束</Tag>
  )
}

function getSessionStatusText(status: SessionStatus) {
  return status === 'active' ? '进行中' : '已结束'
}

function getCheckinStatusText(status: CheckinStatus) {
  const statusMap: Record<CheckinStatus, string> = {
    pending: '未签到',
    normal: '正常',
    late: '迟到',
    absent: '缺勤',
  }

  return statusMap[status]
}

function sanitizeFileName(value: string) {
  return value.replace(/[\\/:*?"<>|]/g, '_').trim() || '签到任务'
}

function renderCheckinStatus(status: CheckinStatus) {
  const statusMap: Record<CheckinStatus, { color: string; label: string }> = {
    pending: { color: 'default', label: '未签到' },
    normal: { color: 'green', label: '正常' },
    late: { color: 'red', label: '迟到' },
    absent: { color: 'volcano', label: '缺勤' },
  }
  const item = statusMap[status]

  return <Tag color={item.color}>{item.label}</Tag>
}

const columns: ColumnsType<DetailMemberRow> = [
  {
    title: '姓名',
    dataIndex: 'name',
    key: 'name',
  },
  {
    title: '学号',
    dataIndex: 'student_id',
    key: 'student_id',
    render: (value: string | null) => value || '-',
  },
  {
    title: '性别',
    dataIndex: 'gender',
    key: 'gender',
    render: (value: string | null) => value || '-',
  },
  {
    title: '手机号',
    dataIndex: 'phone',
    key: 'phone',
    render: (value: string | null) => value || '-',
  },
  {
    title: '分组',
    dataIndex: 'group_name',
    key: 'group_name',
  },
  {
    title: '签到状态',
    dataIndex: 'status',
    key: 'status',
    render: renderCheckinStatus,
  },
  {
    title: '签到时间',
    dataIndex: 'checkin_time',
    key: 'checkin_time',
    render: formatTime,
  },
  {
    title: '迟到分钟数',
    dataIndex: 'late_minutes',
    key: 'late_minutes',
  },
]

export function SessionDetailPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [messageApi, contextHolder] = message.useMessage()
  const [session, setSession] = useState<AttendanceSession | null>(null)
  const [members, setMembers] = useState<DetailMemberRow[]>([])
  const [loading, setLoading] = useState(true)
  const [ending, setEnding] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')

  const loadDetail = useCallback(async () => {
    if (!id) {
      setErrorMessage('缺少签到任务 ID。')
      setLoading(false)
      return
    }

    try {
      setLoading(true)
      setErrorMessage('')

      const [sessionResult, membersResult] = await Promise.all([
        supabase
          .from('attendance_sessions')
          .select('id, title, required_time, end_time, status, created_at')
          .eq('id', id)
          .maybeSingle(),
        supabase
          .from('session_members')
          .select(
            'id, status, checkin_time, late_minutes, members(name, student_id, gender, phone, groups(name))',
          )
          .eq('session_id', id),
      ])

      if (sessionResult.error) {
        throw sessionResult.error
      }

      if (membersResult.error) {
        throw membersResult.error
      }

      if (!sessionResult.data) {
        throw new Error('未找到该签到任务。')
      }

      const rows = ((membersResult.data ?? []) as RawSessionMember[]).map(
        (item) => {
          const member = getSingleMember(item.members)
          return {
            id: item.id,
            name: member?.name ?? '-',
            student_id: member?.student_id ?? null,
            gender: member?.gender ?? null,
            phone: member?.phone ?? null,
            group_name: getGroupName(member?.groups),
            status: item.status,
            checkin_time: item.checkin_time,
            late_minutes: item.late_minutes ?? 0,
          }
        },
      )

      setSession(sessionResult.data as AttendanceSession)
      setMembers(rows)
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : '签到详情加载失败。',
      )
    } finally {
      setLoading(false)
    }
  }, [id])

  useEffect(() => {
    loadDetail()
  }, [loadDetail])

  const stats = useMemo(() => {
    return members.reduce(
      (result, member) => {
        result.total += 1
        result[member.status] += 1
        return result
      },
      {
        total: 0,
        normal: 0,
        late: 0,
        absent: 0,
        pending: 0,
      },
    )
  }, [members])

  async function handleCloseSession() {
    if (!id) {
      messageApi.error('缺少签到任务 ID。')
      return
    }

    try {
      setEnding(true)

      const { error: membersError } = await supabase
        .from('session_members')
        .update({ status: 'absent' })
        .eq('session_id', id)
        .eq('status', 'pending')

      if (membersError) {
        throw membersError
      }

      const { error: sessionError } = await supabase
        .from('attendance_sessions')
        .update({ status: 'closed' })
        .eq('id', id)

      if (sessionError) {
        throw sessionError
      }

      messageApi.success('签到已结束，未签到成员已标记为缺勤')
      await loadDetail()
    } catch (error) {
      messageApi.error(
        error instanceof Error ? error.message : '结束签到失败，请稍后重试。',
      )
    } finally {
      setEnding(false)
    }
  }

  function handleExportExcel() {
    if (!session || members.length === 0) {
      messageApi.warning('暂无可导出的签到数据')
      return
    }

    try {
      const rows = members.map((member) => ({
        签到标题: session.title,
        签到状态: getSessionStatusText(session.status),
        姓名: member.name,
        学号: member.student_id ?? '',
        性别: member.gender ?? '',
        手机号: member.phone ?? '',
        分组: member.group_name,
        规定签到时间: formatTime(session.required_time),
        结束时间: formatTime(session.end_time),
        实际签到时间: member.checkin_time
          ? formatTime(member.checkin_time)
          : '',
        签到结果: getCheckinStatusText(member.status),
        迟到分钟数: member.late_minutes,
      }))

      const worksheet = XLSX.utils.json_to_sheet(rows)
      const workbook = XLSX.utils.book_new()
      XLSX.utils.book_append_sheet(workbook, worksheet, '签到结果')

      const timestamp = dayjs().format('YYYYMMDD_HHmm')
      const fileName = `${sanitizeFileName(session.title)}_签到结果_${timestamp}.xlsx`
      XLSX.writeFile(workbook, fileName)
      messageApi.success('Excel 已导出')
    } catch {
      messageApi.error('导出 Excel 失败，请稍后重试。')
    }
  }

  return (
    <section className="page-panel">
      {contextHolder}
      <div className="session-detail-header">
        <div>
          <Typography.Title level={1}>签到详情</Typography.Title>
          <p>查看本次签到的任务信息、统计结果和成员签到状态。</p>
        </div>
        <Space>
          <Button disabled={!session || members.length === 0} onClick={handleExportExcel}>
            导出 Excel
          </Button>
          {session?.status === 'active' ? (
            <Popconfirm
              title="确认结束本次签到？"
              description="结束后，所有未签到成员将被标记为缺勤，且本次签到将关闭。"
              okText="结束签到"
              cancelText="取消"
              okButtonProps={{ danger: true, loading: ending }}
              onConfirm={handleCloseSession}
            >
              <Button danger disabled={loading || ending}>
                结束签到
              </Button>
            </Popconfirm>
          ) : (
            session && <Tag color="default">已结束</Tag>
          )}
          <Button onClick={() => navigate('/sessions')}>返回列表</Button>
        </Space>
      </div>

      {loading && (
        <div className="session-detail-state">
          <Spin tip="正在加载签到详情" />
        </div>
      )}

      {!loading && errorMessage && (
        <Alert
          className="session-detail-alert"
          message="签到详情加载失败"
          description={errorMessage}
          type="error"
          showIcon
        />
      )}

      {!loading && !errorMessage && session && (
        <>
          <Descriptions
            className="session-detail-info"
            bordered
            column={{ xs: 1, md: 2 }}
          >
            <Descriptions.Item label="签到标题">
              {session.title}
            </Descriptions.Item>
            <Descriptions.Item label="签到状态">
              {renderSessionStatus(session.status)}
            </Descriptions.Item>
            <Descriptions.Item label="规定签到时间">
              {formatTime(session.required_time)}
            </Descriptions.Item>
            <Descriptions.Item label="结束时间">
              {formatTime(session.end_time)}
            </Descriptions.Item>
            <Descriptions.Item label="创建时间">
              {formatTime(session.created_at)}
            </Descriptions.Item>
          </Descriptions>

          <Row gutter={[16, 16]} className="session-detail-stats">
            <Col xs={24} md={8} xl={4}>
              <Card>
                <Statistic title="参与人数" value={stats.total} />
              </Card>
            </Col>
            <Col xs={24} md={8} xl={5}>
              <Card>
                <Statistic title="正常人数" value={stats.normal} />
              </Card>
            </Col>
            <Col xs={24} md={8} xl={5}>
              <Card>
                <Statistic title="迟到人数" value={stats.late} />
              </Card>
            </Col>
            <Col xs={24} md={8} xl={5}>
              <Card>
                <Statistic title="缺勤人数" value={stats.absent} />
              </Card>
            </Col>
            <Col xs={24} md={8} xl={5}>
              <Card>
                <Statistic title="未签到人数" value={stats.pending} />
              </Card>
            </Col>
          </Row>

          <Table
            className="session-detail-table"
            rowKey="id"
            columns={columns}
            dataSource={members}
            pagination={false}
            scroll={{ x: 960 }}
          />
        </>
      )}
    </section>
  )
}
