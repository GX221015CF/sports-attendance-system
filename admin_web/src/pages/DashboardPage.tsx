import { Alert, Card, Col, Row, Spin, Statistic } from 'antd'
import { useEffect, useState } from 'react'
import { supabase } from '../api/supabase'

type DashboardStats = {
  activeMembers: number
  groups: number
  activeSessions: number
  pendingCheckins: number
}

function getCountOrThrow(count: number | null, error: Error | null) {
  if (error) {
    throw error
  }

  return count ?? 0
}

export function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [errorMessage, setErrorMessage] = useState('')

  useEffect(() => {
    let ignore = false

    async function loadStats() {
      try {
        setLoading(true)
        setErrorMessage('')

        const [membersResult, groupsResult, sessionsResult, checkinsResult] =
          await Promise.all([
            supabase
              .from('members')
              .select('*', { count: 'exact', head: true })
              .eq('is_active', true),
            supabase.from('groups').select('*', {
              count: 'exact',
              head: true,
            }),
            supabase
              .from('attendance_sessions')
              .select('*', { count: 'exact', head: true })
              .eq('status', 'active'),
            supabase
              .from('session_members')
              .select('*', { count: 'exact', head: true })
              .eq('status', 'pending'),
          ])

        if (!ignore) {
          setStats({
            activeMembers: getCountOrThrow(
              membersResult.count,
              membersResult.error,
            ),
            groups: getCountOrThrow(groupsResult.count, groupsResult.error),
            activeSessions: getCountOrThrow(
              sessionsResult.count,
              sessionsResult.error,
            ),
            pendingCheckins: getCountOrThrow(
              checkinsResult.count,
              checkinsResult.error,
            ),
          })
        }
      } catch (error) {
        if (!ignore) {
          setErrorMessage(
            error instanceof Error ? error.message : '数据看板统计加载失败。',
          )
        }
      } finally {
        if (!ignore) {
          setLoading(false)
        }
      }
    }

    loadStats()

    return () => {
      ignore = true
    }
  }, [])

  return (
    <section className="page-panel">
      <h1>数据看板</h1>
      <p>查看成员、分组和当前签到任务的基础统计。</p>

      {loading && (
        <div className="dashboard-state">
          <Spin tip="正在加载统计数据" />
        </div>
      )}

      {!loading && errorMessage && (
        <Alert
          className="dashboard-alert"
          message="统计数据加载失败"
          description={errorMessage}
          type="error"
          showIcon
        />
      )}

      {!loading && !errorMessage && stats && (
        <Row gutter={[16, 16]} className="dashboard-grid">
          <Col xs={24} sm={12} xl={6}>
            <Card>
              <Statistic title="成员总数" value={stats.activeMembers} />
            </Card>
          </Col>
          <Col xs={24} sm={12} xl={6}>
            <Card>
              <Statistic title="分组数量" value={stats.groups} />
            </Card>
          </Col>
          <Col xs={24} sm={12} xl={6}>
            <Card>
              <Statistic title="进行中签到" value={stats.activeSessions} />
            </Card>
          </Col>
          <Col xs={24} sm={12} xl={6}>
            <Card>
              <Statistic title="待签到人数" value={stats.pendingCheckins} />
            </Card>
          </Col>
        </Row>
      )}
    </section>
  )
}
