import { Alert, Button, Table, Tag, Typography } from 'antd'
import type { ColumnsType } from 'antd/es/table'
import dayjs from 'dayjs'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../api/supabase'

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
  return value ? dayjs(value).format('YYYY-MM-DD HH:mm') : '-'
}

export function SessionsPage() {
  const navigate = useNavigate()
  const [sessions, setSessions] = useState<AttendanceSessionRow[]>([])
  const [sessionMembers, setSessionMembers] = useState<SessionMemberRow[]>([])
  const [loading, setLoading] = useState(true)
  const [errorMessage, setErrorMessage] = useState('')

  useEffect(() => {
    let ignore = false

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

        if (sessionsResult.error) {
          throw sessionsResult.error
        }

        if (membersResult.error) {
          throw membersResult.error
        }

        if (!ignore) {
          setSessions((sessionsResult.data ?? []) as AttendanceSessionRow[])
          setSessionMembers((membersResult.data ?? []) as SessionMemberRow[])
        }
      } catch (error) {
        if (!ignore) {
          setErrorMessage(
            error instanceof Error ? error.message : '签到任务加载失败。',
          )
        }
      } finally {
        if (!ignore) {
          setLoading(false)
        }
      }
    }

    loadSessions()

    return () => {
      ignore = true
    }
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

  const columns: ColumnsType<SessionTableRow> = [
    {
      title: '签到标题',
      dataIndex: 'title',
      key: 'title',
    },
    {
      title: '状态',
      dataIndex: 'status',
      key: 'status',
      render: (value: SessionStatus) =>
        value === 'active' ? (
          <Tag color="green">进行中</Tag>
        ) : (
          <Tag color="default">已结束</Tag>
        ),
    },
    {
      title: '规定签到时间',
      dataIndex: 'required_time',
      key: 'required_time',
      render: formatTime,
    },
    {
      title: '结束时间',
      dataIndex: 'end_time',
      key: 'end_time',
      render: formatTime,
    },
    {
      title: '参与人数',
      dataIndex: 'total',
      key: 'total',
    },
    {
      title: '正常',
      dataIndex: 'normal',
      key: 'normal',
    },
    {
      title: '迟到',
      dataIndex: 'late',
      key: 'late',
    },
    {
      title: '缺勤',
      dataIndex: 'absent',
      key: 'absent',
    },
    {
      title: '未签到',
      dataIndex: 'pending',
      key: 'pending',
    },
    {
      title: '创建时间',
      dataIndex: 'created_at',
      key: 'created_at',
      render: formatTime,
    },
    {
      title: '操作',
      key: 'actions',
      render: (_, record) => (
        <Button type="link" onClick={() => navigate(`/sessions/${record.id}`)}>
          查看详情
        </Button>
      ),
    },
  ]

  return (
    <section className="page-panel">
      <div className="sessions-page-header">
        <div>
          <Typography.Title level={1}>签到任务</Typography.Title>
          <p>查看当前和历史签到任务，以及每次签到的基础统计。</p>
        </div>
        <Button type="primary" onClick={() => navigate('/sessions/create')}>
          创建签到
        </Button>
      </div>

      {errorMessage && (
        <Alert
          className="sessions-alert"
          message="签到任务加载失败"
          description={errorMessage}
          type="error"
          showIcon
        />
      )}

      <Table
        className="sessions-table"
        rowKey="id"
        loading={loading}
        columns={columns}
        dataSource={tableRows}
        pagination={false}
        scroll={{ x: 1180 }}
      />
    </section>
  )
}
