import {
  Alert,
  Button,
  DatePicker,
  Form,
  Input,
  Modal,
  Popconfirm,
  Space,
  Table,
  Tag,
  Tooltip,
  Typography,
  message,
} from 'antd'
import type { ColumnsType } from 'antd/es/table'
import type { Dayjs } from 'dayjs'
import dayjs from 'dayjs'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../api/supabase'
import {
  exportSessionsExcel,
  type ExportSession,
} from '../utils/exportSessionsExcel'

const { RangePicker } = DatePicker

type SessionStatus = 'active' | 'closed'
type CheckinStatus = 'pending' | 'normal' | 'late' | 'absent'

type AttendanceSessionRow = {
  id: string
  title: string
  required_time: string
  end_time: string
  status: SessionStatus
  created_at: string | null
}

type SessionMemberRow = {
  session_id: string
  status: CheckinStatus
}

type SessionStats = {
  total: number
  normal: number
  late: number
  absent: number
  pending: number
}

type SessionTableRow = AttendanceSessionRow & SessionStats

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

type RawExportSessionMember = {
  session_id: string
  member_id: string | null
  status: CheckinStatus
  checkin_time: string | null
  late_minutes: number | null
  remark: string | null
  members: RelatedMember
}

type EditSessionFormValues = {
  title: string
  timeRange: [Dayjs, Dayjs]
}

function emptyStats(): SessionStats {
  return { total: 0, normal: 0, late: 0, absent: 0, pending: 0 }
}

function formatTime(value: string | null) {
  return value ? dayjs(value).format('YYYY-MM-DD HH:mm') : '-'
}

function getSingleMember(raw: RelatedMember) {
  return Array.isArray(raw) ? raw[0] ?? null : raw
}

function getGroupName(groups: RelatedGroup | undefined) {
  if (Array.isArray(groups)) {
    return groups[0]?.name ?? '未分组'
  }
  return groups?.name ?? '未分组'
}

export function SessionsPage() {
  const navigate = useNavigate()
  const [form] = Form.useForm<EditSessionFormValues>()
  const [sessions, setSessions] = useState<AttendanceSessionRow[]>([])
  const [sessionMembers, setSessionMembers] = useState<SessionMemberRow[]>([])
  const [loading, setLoading] = useState(true)
  const [exporting, setExporting] = useState(false)
  const [saving, setSaving] = useState(false)
  const [deletingId, setDeletingId] = useState<string | null>(null)
  const [errorMessage, setErrorMessage] = useState('')
  const [selectedRowKeys, setSelectedRowKeys] = useState<React.Key[]>([])
  const [editingSession, setEditingSession] = useState<SessionTableRow | null>(null)
  const [messageApi, contextHolder] = message.useMessage()

  async function loadSessions() {
    try {
      setLoading(true)
      setErrorMessage('')

      const [sessionsResult, membersResult] = await Promise.all([
        supabase
          .from('attendance_sessions')
          .select('id, title, required_time, end_time, status, created_at')
          .order('created_at', { ascending: false }),
        supabase.from('session_members').select('session_id, status'),
      ])

      if (sessionsResult.error) throw sessionsResult.error
      if (membersResult.error) throw membersResult.error

      setSessions((sessionsResult.data ?? []) as AttendanceSessionRow[])
      setSessionMembers((membersResult.data ?? []) as SessionMemberRow[])
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : '签到任务加载失败。')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    // Initial data loading intentionally updates the page loading state.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadSessions()
  }, [])

  const tableRows = useMemo(() => {
    const statsMap = new Map<string, SessionStats>()
    sessionMembers.forEach((item) => {
      const stats = statsMap.get(item.session_id) ?? emptyStats()
      stats.total += 1
      stats[item.status] += 1
      statsMap.set(item.session_id, stats)
    })
    return sessions.map((session) => ({
      ...session,
      ...(statsMap.get(session.id) ?? emptyStats()),
    }))
  }, [sessionMembers, sessions])

  const selectedSessions = useMemo(() => {
    const selectedSet = new Set(selectedRowKeys)
    return tableRows.filter((session) => selectedSet.has(session.id))
  }, [selectedRowKeys, tableRows])

  function openEditModal(record: SessionTableRow) {
    setEditingSession(record)
    form.setFieldsValue({
      title: record.title,
      timeRange: [dayjs(record.required_time), dayjs(record.end_time)],
    })
  }

  function closeEditModal() {
    setEditingSession(null)
    form.resetFields()
  }

  async function handleSaveSession() {
    if (!editingSession) return

    try {
      const values = await form.validateFields()
      const [requiredTime, endTime] = values.timeRange
      if (!endTime.isAfter(requiredTime)) {
        messageApi.error('签到结束时间必须晚于规定签到时间')
        return
      }

      setSaving(true)
      const { error } = await supabase
        .from('attendance_sessions')
        .update({
          title: values.title.trim(),
          required_time: requiredTime.toISOString(),
          end_time: endTime.toISOString(),
        })
        .eq('id', editingSession.id)

      if (error) throw error

      messageApi.success('签到任务已更新')
      closeEditModal()
      await loadSessions()
    } catch (error) {
      if (error instanceof Error) messageApi.error(error.message)
    } finally {
      setSaving(false)
    }
  }

  async function handleDeleteSession(record: SessionTableRow) {
    try {
      setDeletingId(record.id)
      const { error } = await supabase
        .from('attendance_sessions')
        .delete()
        .eq('id', record.id)
      if (error) throw error

      messageApi.success('签到任务已删除')
      setSelectedRowKeys((keys) => keys.filter((key) => key !== record.id))
      await loadSessions()
    } catch (error) {
      messageApi.error(error instanceof Error ? error.message : '删除签到任务失败，请稍后重试。')
    } finally {
      setDeletingId(null)
    }
  }

  async function handleBatchExport() {
    if (selectedSessions.length === 0 || exporting) return

    try {
      setExporting(true)
      const sessionIds = selectedSessions.map((session) => session.id)
      const { data, error } = await supabase
        .from('session_members')
        .select(
          'session_id, member_id, status, checkin_time, late_minutes, remark, members(name, student_id, gender, phone, groups(name))',
        )
        .in('session_id', sessionIds)
      if (error) throw error

      const exportMembers = ((data ?? []) as RawExportSessionMember[]).map((item) => {
        const member = getSingleMember(item.members)
        return {
          session_id: item.session_id,
          member_id: item.member_id,
          status: item.status,
          checkin_time: item.checkin_time,
          late_minutes: item.late_minutes ?? 0,
          remark: item.remark ?? '',
          member_name: member?.name ?? '',
          student_id: member?.student_id ?? '',
          gender: member?.gender ?? '',
          phone: member?.phone ?? '',
          group_name: getGroupName(member?.groups),
        }
      })

      exportSessionsExcel(selectedSessions as ExportSession[], exportMembers)
      messageApi.success(`已导出 ${selectedSessions.length} 份签到记录`)
    } catch (error) {
      messageApi.error(error instanceof Error ? error.message : '批量导出 Excel 失败，请稍后重试。')
    } finally {
      setExporting(false)
    }
  }

  const columns: ColumnsType<SessionTableRow> = [
    { title: '签到标题', dataIndex: 'title', key: 'title' },
    {
      title: '状态',
      dataIndex: 'status',
      key: 'status',
      render: (value: SessionStatus) =>
        value === 'active' ? <Tag color="green">进行中</Tag> : <Tag color="default">已结束</Tag>,
    },
    { title: '规定签到时间', dataIndex: 'required_time', key: 'required_time', render: formatTime },
    { title: '结束时间', dataIndex: 'end_time', key: 'end_time', render: formatTime },
    { title: '参与人数', dataIndex: 'total', key: 'total' },
    { title: '正常', dataIndex: 'normal', key: 'normal' },
    { title: '迟到', dataIndex: 'late', key: 'late' },
    { title: '缺勤', dataIndex: 'absent', key: 'absent' },
    { title: '未签到', dataIndex: 'pending', key: 'pending' },
    { title: '创建时间', dataIndex: 'created_at', key: 'created_at', render: formatTime },
    {
      title: '操作',
      key: 'actions',
      fixed: 'right',
      render: (_, record) => (
        <Space>
          <Button type="link" onClick={() => navigate(`/sessions/${record.id}`)}>查看详情</Button>
          <Button type="link" onClick={() => openEditModal(record)}>编辑</Button>
          <Popconfirm
            title="确认删除该签到任务？"
            description="删除后该签到任务及所有成员签到记录都会删除，无法恢复。"
            okText="删除"
            cancelText="取消"
            okButtonProps={{ danger: true, loading: deletingId === record.id }}
            onConfirm={() => handleDeleteSession(record)}
          >
            <Button type="link" danger loading={deletingId === record.id}>删除</Button>
          </Popconfirm>
        </Space>
      ),
    },
  ]

  return (
    <section className="page-panel">
      {contextHolder}
      <div className="sessions-page-header">
        <div>
          <Typography.Title level={1}>签到任务</Typography.Title>
          <p>查看当前和历史签到任务，以及每次签到的基础统计。</p>
        </div>
        <Space wrap>
          <Button type="primary" onClick={() => navigate('/sessions/create')}>创建签到</Button>
          <Tooltip title="批量导出会按人员合并多次签到结果，适合查看一批人的多次出勤情况。">
            <Button loading={exporting} disabled={selectedSessions.length === 0} onClick={handleBatchExport}>
              {selectedSessions.length > 0
                ? `批量导出汇总 Excel（已选 ${selectedSessions.length} 项）`
                : '批量导出汇总 Excel'}
            </Button>
          </Tooltip>
        </Space>
      </div>

      {errorMessage && (
        <Alert className="sessions-alert" message="签到任务加载失败" description={errorMessage} type="error" showIcon />
      )}

      <Table
        className="sessions-table"
        rowKey="id"
        loading={loading}
        rowSelection={{ selectedRowKeys, onChange: setSelectedRowKeys }}
        columns={columns}
        dataSource={tableRows}
        pagination={false}
        scroll={{ x: 1320 }}
      />

      <Modal
        title="编辑签到任务"
        open={Boolean(editingSession)}
        okText="保存"
        cancelText="取消"
        confirmLoading={saving}
        onCancel={closeEditModal}
        onOk={handleSaveSession}
        destroyOnHidden
      >
        <Form form={form} layout="vertical">
          <Form.Item name="title" label="签到标题" rules={[{ required: true, message: '请输入签到标题' }]}>
            <Input placeholder="例如：6月晚训签到" />
          </Form.Item>
          <Form.Item name="timeRange" label="签到时间" rules={[{ required: true, message: '请选择规定签到时间和结束时间' }]}>
            <RangePicker
              showTime={{ format: 'HH:mm', minuteStep: 1, showNow: false }}
              format="YYYY-MM-DD HH:mm"
              style={{ width: '100%' }}
              placeholder={['规定签到时间', '签到结束时间']}
            />
          </Form.Item>
        </Form>
      </Modal>
    </section>
  )
}
