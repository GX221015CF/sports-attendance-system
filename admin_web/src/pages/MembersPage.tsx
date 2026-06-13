import {
  Alert,
  Button,
  Form,
  Input,
  Modal,
  Popconfirm,
  Select,
  Space,
  Switch,
  Table,
  Tag,
  Typography,
  message,
} from 'antd'
import type { ColumnsType } from 'antd/es/table'
import dayjs from 'dayjs'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { supabase } from '../api/supabase'

type MemberStatusFilter = 'all' | 'active' | 'inactive'

type GroupOption = {
  id: string
  name: string
}

type MemberRow = {
  id: string
  name: string
  student_id: string | null
  gender: string | null
  phone: string | null
  group_id: string | null
  is_active: boolean
  created_at: string | null
  group_name: string
}

type MemberFormValues = {
  name: string
  student_id?: string
  gender?: string
  phone?: string
  group_id?: string
  is_active: boolean
}

type RawMemberRow = {
  id: string
  name: string
  student_id: string | null
  gender: string | null
  phone: string | null
  group_id: string | null
  is_active: boolean | null
  created_at: string | null
  groups: { name: string | null } | { name: string | null }[] | null
}

function getGroupName(groups: RawMemberRow['groups']) {
  if (Array.isArray(groups)) {
    return groups[0]?.name ?? '未分组'
  }

  return groups?.name ?? '未分组'
}

function emptyToNull(value?: string) {
  const trimmed = value?.trim()
  return trimmed ? trimmed : null
}

export function MembersPage() {
  const [form] = Form.useForm<MemberFormValues>()
  const [messageApi, contextHolder] = message.useMessage()
  const [members, setMembers] = useState<MemberRow[]>([])
  const [groups, setGroups] = useState<GroupOption[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [modalOpen, setModalOpen] = useState(false)
  const [editingMember, setEditingMember] = useState<MemberRow | null>(null)
  const [errorMessage, setErrorMessage] = useState('')
  const [nameKeyword, setNameKeyword] = useState('')
  const [groupFilter, setGroupFilter] = useState<string>('all')
  const [statusFilter, setStatusFilter] = useState<MemberStatusFilter>('all')

  const loadGroups = useCallback(async () => {
    const { data, error } = await supabase
      .from('groups')
      .select('id, name')
      .order('name', { ascending: true })

    if (error) throw error
    setGroups((data ?? []) as GroupOption[])
  }, [])

  const loadMembers = useCallback(async () => {
    try {
      setLoading(true)
      setErrorMessage('')

      const { data, error } = await supabase
        .from('members')
        .select('id, name, student_id, gender, phone, group_id, is_active, created_at, groups(name)')
        .order('student_id', { ascending: true })

      if (error) throw error

      const rows = ((data ?? []) as RawMemberRow[]).map((item) => ({
        id: item.id,
        name: item.name,
        student_id: item.student_id,
        gender: item.gender,
        phone: item.phone,
        group_id: item.group_id,
        is_active: item.is_active ?? false,
        created_at: item.created_at,
        group_name: getGroupName(item.groups),
      }))

      setMembers(rows)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : '成员列表加载失败。')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    async function loadPageData() {
      try {
        await Promise.all([loadGroups(), loadMembers()])
      } catch (error) {
        setErrorMessage(error instanceof Error ? error.message : '成员页面数据加载失败。')
        setLoading(false)
      }
    }
    loadPageData()
  }, [loadGroups, loadMembers])

  const groupOptions = useMemo(
    () => [
      { label: '全部分组', value: 'all' },
      ...groups.map((group) => ({ label: group.name, value: group.name })),
    ],
    [groups],
  )

  const filteredMembers = useMemo(() => {
    const keyword = nameKeyword.trim().toLowerCase()
    return members.filter((member) => {
      const matchesName = !keyword || member.name.toLowerCase().includes(keyword)
      const matchesGroup = groupFilter === 'all' || member.group_name === groupFilter
      const matchesStatus =
        statusFilter === 'all' ||
        (statusFilter === 'active' && member.is_active) ||
        (statusFilter === 'inactive' && !member.is_active)
      return matchesName && matchesGroup && matchesStatus
    })
  }, [groupFilter, members, nameKeyword, statusFilter])

  const columns: ColumnsType<MemberRow> = [
    { title: '姓名', dataIndex: 'name', key: 'name' },
    { title: '学号', dataIndex: 'student_id', key: 'student_id', render: (value: string | null) => value || '-' },
    { title: '性别', dataIndex: 'gender', key: 'gender', render: (value: string | null) => value || '-' },
    { title: '手机号', dataIndex: 'phone', key: 'phone', render: (value: string | null) => value || '-' },
    { title: '分组', dataIndex: 'group_name', key: 'group_name' },
    {
      title: '状态',
      dataIndex: 'is_active',
      key: 'is_active',
      render: (isActive: boolean) => isActive ? <Tag color="green">在队</Tag> : <Tag color="default">离队</Tag>,
    },
    {
      title: '创建时间',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (value: string | null) => value ? dayjs(value).format('YYYY-MM-DD HH:mm') : '-',
    },
    {
      title: '操作',
      key: 'actions',
      render: (_, record) => (
        <Space size={4}>
          <Button type="link" onClick={() => openEditModal(record)}>编辑</Button>
          <Popconfirm
            title="确认删除该成员？"
            description="删除后将无法在成员列表中看到该成员。"
            okText="删除"
            cancelText="取消"
            okButtonProps={{ danger: true }}
            onConfirm={() => handleDeleteMember(record)}
          >
            <Button type="link" danger>删除</Button>
          </Popconfirm>
        </Space>
      ),
    },
  ]

  function openCreateModal() {
    setEditingMember(null)
    form.resetFields()
    form.setFieldsValue({ is_active: true })
    setModalOpen(true)
  }

  function openEditModal(member: MemberRow) {
    setEditingMember(member)
    form.setFieldsValue({
      name: member.name,
      student_id: member.student_id ?? undefined,
      gender: member.gender ?? undefined,
      phone: member.phone ?? undefined,
      group_id: member.group_id ?? undefined,
      is_active: member.is_active,
    })
    setModalOpen(true)
  }

  function closeModal() {
    setModalOpen(false)
    setEditingMember(null)
    form.resetFields()
  }

  async function handleSubmitMember(values: MemberFormValues) {
    try {
      setSaving(true)
      const payload = {
        name: values.name.trim(),
        student_id: emptyToNull(values.student_id),
        gender: values.gender ?? null,
        phone: emptyToNull(values.phone),
        group_id: values.group_id || null,
        is_active: values.is_active ?? true,
      }
      const { error } = editingMember
        ? await supabase.from('members').update(payload).eq('id', editingMember.id)
        : await supabase.from('members').insert(payload)
      if (error) throw error
      messageApi.success(editingMember ? '成员已更新' : '成员已新增')
      closeModal()
      await loadMembers()
    } catch (error) {
      messageApi.error(error instanceof Error ? error.message : editingMember ? '更新成员失败，请稍后重试。' : '新增成员失败，请稍后重试。')
    } finally {
      setSaving(false)
    }
  }

  async function handleDeleteMember(member: MemberRow) {
    try {
      const { error } = await supabase.from('members').delete().eq('id', member.id)
      if (error) throw error
      messageApi.success('成员已删除')
      await loadMembers()
    } catch (error) {
      messageApi.error(error instanceof Error ? error.message : '删除成员失败，请稍后重试。')
    }
  }

  return (
    <section className="page-panel">
      {contextHolder}
      <div className="members-page-header">
        <div>
          <Typography.Title level={1}>成员管理</Typography.Title>
          <p>查看队员基础信息，并按姓名、分组和状态筛选。</p>
        </div>
        <Button type="primary" onClick={openCreateModal}>新增成员</Button>
      </div>

      {errorMessage && <Alert className="members-alert" message="成员列表加载失败" description={errorMessage} type="error" showIcon />}

      <Space className="members-toolbar" size={12} wrap>
        <Input.Search allowClear placeholder="搜索姓名" value={nameKeyword} onChange={(event) => setNameKeyword(event.target.value)} style={{ width: 220 }} />
        <Select value={groupFilter} options={groupOptions} onChange={setGroupFilter} style={{ width: 180 }} />
        <Select<MemberStatusFilter>
          value={statusFilter}
          options={[{ label: '全部状态', value: 'all' }, { label: '在队', value: 'active' }, { label: '离队', value: 'inactive' }]}
          onChange={setStatusFilter}
          style={{ width: 140 }}
        />
      </Space>

      <Table rowKey="id" loading={loading} columns={columns} dataSource={filteredMembers} pagination={false} />

      <Modal title={editingMember ? '编辑成员' : '新增成员'} open={modalOpen} confirmLoading={saving} okText="保存" cancelText="取消" onCancel={closeModal} onOk={() => form.submit()} destroyOnHidden>
        <Form<MemberFormValues> form={form} layout="vertical" initialValues={{ is_active: true }} onFinish={handleSubmitMember}>
          <Form.Item label="姓名" name="name" rules={[{ required: true, message: '请输入姓名' }]}>
            <Input placeholder="请输入姓名" />
          </Form.Item>
          <Form.Item label="学号" name="student_id"><Input placeholder="请输入学号" /></Form.Item>
          <Form.Item label="性别" name="gender">
            <Select allowClear placeholder="请选择性别" options={[{ label: '男', value: '男' }, { label: '女', value: '女' }]} />
          </Form.Item>
          <Form.Item label="手机号" name="phone"><Input placeholder="请输入手机号" /></Form.Item>
          <Form.Item label="分组" name="group_id">
            <Select allowClear placeholder="请选择分组" options={groups.map((group) => ({ label: group.name, value: group.id }))} />
          </Form.Item>
          <Form.Item label="是否在队" name="is_active" valuePropName="checked">
            <Switch checkedChildren="在队" unCheckedChildren="离队" />
          </Form.Item>
        </Form>
      </Modal>
    </section>
  )
}
