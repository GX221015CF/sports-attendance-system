import {
  Alert,
  Button,
  Card,
  DatePicker,
  Form,
  Input,
  Select,
  Space,
  Table,
  Typography,
  message,
} from 'antd'
import type { ColumnsType } from 'antd/es/table'
import type { Dayjs } from 'dayjs'
import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../api/supabase'

type GroupOption = { id: string; name: string }

type MemberRow = {
  id: string
  name: string
  student_id: string | null
  gender: string | null
  group_id: string | null
  group_name: string
}

type RawMemberRow = {
  id: string
  name: string
  student_id: string | null
  gender: string | null
  group_id: string | null
  groups: { name: string | null } | { name: string | null }[] | null
}

type CreateSessionFormValues = {
  title: string
  required_time: Dayjs
  end_time: Dayjs
  group_ids?: string[]
}

function getGroupName(groups: RawMemberRow['groups']) {
  if (Array.isArray(groups)) return groups[0]?.name ?? '未分组'
  return groups?.name ?? '未分组'
}

const columns: ColumnsType<MemberRow> = [
  { title: '姓名', dataIndex: 'name', key: 'name' },
  { title: '学号', dataIndex: 'student_id', key: 'student_id', render: (value: string | null) => value || '-' },
  { title: '性别', dataIndex: 'gender', key: 'gender', render: (value: string | null) => value || '-' },
  { title: '分组', dataIndex: 'group_name', key: 'group_name' },
]

export function CreateSessionPage() {
  const [form] = Form.useForm<CreateSessionFormValues>()
  const [messageApi, contextHolder] = message.useMessage()
  const navigate = useNavigate()
  const [groups, setGroups] = useState<GroupOption[]>([])
  const [members, setMembers] = useState<MemberRow[]>([])
  const [selectedMemberIds, setSelectedMemberIds] = useState<React.Key[]>([])
  const [selectedGroupIds, setSelectedGroupIds] = useState<string[]>([])
  const [nameKeyword, setNameKeyword] = useState('')
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')

  useEffect(() => {
    let ignore = false

    async function loadPageData() {
      try {
        setLoading(true)
        setErrorMessage('')

        const [groupsResult, membersResult] = await Promise.all([
          supabase.from('groups').select('id, name').order('name'),
          supabase
            .from('members')
            .select('id, name, student_id, gender, group_id, groups(name)')
            .eq('is_active', true)
            .order('student_id', { ascending: true }),
        ])

        if (groupsResult.error) throw groupsResult.error
        if (membersResult.error) throw membersResult.error

        if (!ignore) {
          setGroups((groupsResult.data ?? []) as GroupOption[])
          setMembers(
            ((membersResult.data ?? []) as RawMemberRow[]).map((item) => ({
              id: item.id,
              name: item.name,
              student_id: item.student_id,
              gender: item.gender,
              group_id: item.group_id,
              group_name: getGroupName(item.groups),
            })),
          )
        }
      } catch (error) {
        if (!ignore) setErrorMessage(error instanceof Error ? error.message : '创建签到页面数据加载失败。')
      } finally {
        if (!ignore) setLoading(false)
      }
    }

    loadPageData()
    return () => { ignore = true }
  }, [])

  const requiredTime = Form.useWatch('required_time', form)

  const filteredMembers = useMemo(() => {
    const keyword = nameKeyword.trim().toLowerCase()
    return members.filter((member) => {
      const matchesGroup = selectedGroupIds.length === 0 || (member.group_id !== null && selectedGroupIds.includes(member.group_id))
      const matchesName = !keyword || member.name.toLowerCase().includes(keyword)
      return matchesGroup && matchesName
    })
  }, [members, nameKeyword, selectedGroupIds])

  async function handleSubmit(values: CreateSessionFormValues) {
    if (!values.end_time.isAfter(values.required_time)) {
      messageApi.error('签到结束时间必须晚于规定签到时间')
      return
    }
    if (selectedMemberIds.length === 0) {
      messageApi.error('请至少选择 1 名成员')
      return
    }

    try {
      setSubmitting(true)
      const { data: sessionData, error: sessionError } = await supabase
        .from('attendance_sessions')
        .insert({ title: values.title.trim(), required_time: values.required_time.toISOString(), end_time: values.end_time.toISOString(), status: 'active' })
        .select('id')
        .single()
      if (sessionError) throw sessionError

      const sessionId = sessionData.id as string
      const rows = selectedMemberIds.map((memberId) => ({ session_id: sessionId, member_id: String(memberId), status: 'pending', late_minutes: 0 }))
      const { error: membersError } = await supabase.from('session_members').insert(rows)
      if (membersError) throw membersError

      messageApi.success('签到任务已发布')
      navigate('/sessions/' + sessionId)
    } catch (error) {
      messageApi.error(error instanceof Error ? error.message : '创建签到失败，请稍后重试。')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <section className="page-panel">
      {contextHolder}
      <div className="create-session-header">
        <div>
          <Typography.Title level={1}>创建签到</Typography.Title>
          <p>设置规定签到时间和结束时间，并选择参与本次签到的在队成员。</p>
        </div>
        <Button onClick={() => navigate('/sessions')}>返回列表</Button>
      </div>

      {errorMessage && <Alert className="create-session-alert" message="页面数据加载失败" description={errorMessage} type="error" showIcon />}
      {members.length === 0 && !loading && !errorMessage && <Alert className="create-session-alert" message="暂无可选成员" description="请先在成员管理中添加在队成员。" type="info" showIcon />}

      <Card className="create-session-card">
        <Form<CreateSessionFormValues> form={form} layout="vertical" onFinish={handleSubmit}>
          <Form.Item label="签到标题" name="title" rules={[{ required: true, message: '请输入签到标题' }]}>
            <Input placeholder="例如：6月晚训签到" />
          </Form.Item>

          <div className="create-session-time-grid">
            <Form.Item label="规定签到时间" name="required_time" rules={[{ required: true, message: '请选择规定签到时间' }]}>
              <DatePicker showTime={{ format: 'HH:mm' }} format="YYYY-MM-DD HH:mm" placeholder="选择规定签到时间" needConfirm style={{ width: '100%' }} />
            </Form.Item>
            <Form.Item
              label="签到结束时间"
              name="end_time"
              dependencies={['required_time']}
              rules={[
                { required: true, message: '请选择签到结束时间' },
                ({ getFieldValue }) => ({
                  validator(_, value: Dayjs | undefined) {
                    const start = getFieldValue('required_time') as Dayjs | undefined
                    if (!value || !start || value.isAfter(start)) return Promise.resolve()
                    return Promise.reject(new Error('结束时间必须晚于规定签到时间'))
                  },
                }),
              ]}
            >
              <DatePicker
                showTime={{ format: 'HH:mm' }}
                format="YYYY-MM-DD HH:mm"
                placeholder="选择签到结束时间"
                needConfirm
                disabledDate={(current) => {
                  if (!requiredTime || !current) return false
                  return current.endOf('day').isBefore(requiredTime.startOf('day'))
                }}
                style={{ width: '100%' }}
              />
            </Form.Item>
          </div>

          <Form.Item label="选择分组" name="group_ids">
            <Select mode="multiple" allowClear placeholder="选择分组后快速筛选成员" options={groups.map((group) => ({ label: group.name, value: group.id }))} onChange={(value) => setSelectedGroupIds(value)} />
          </Form.Item>

          <Space className="create-session-toolbar" size={12} wrap>
            <Input.Search allowClear placeholder="搜索成员姓名" value={nameKeyword} onChange={(event) => setNameKeyword(event.target.value)} style={{ width: 220 }} />
            <Typography.Text type="secondary">已选择 {selectedMemberIds.length} 名成员</Typography.Text>
          </Space>

          <Table rowKey="id" loading={loading} columns={columns} dataSource={filteredMembers} pagination={false} rowSelection={{ selectedRowKeys: selectedMemberIds, onChange: setSelectedMemberIds, preserveSelectedRowKeys: true }} />

          <Form.Item className="create-session-actions">
            <Button type="primary" htmlType="submit" loading={submitting} disabled={loading}>发布签到</Button>
          </Form.Item>
        </Form>
      </Card>
    </section>
  )
}
