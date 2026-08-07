import {
  Alert,
  Button,
  Form,
  Input,
  Modal,
  Popconfirm,
  Space,
  Table,
  Typography,
  message,
} from 'antd'
import type { ColumnsType } from 'antd/es/table'
import dayjs from 'dayjs'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { supabase } from '../api/supabase'

type GroupRow = {
  id: string
  name: string
  description: string | null
  created_at: string | null
  member_count: number
}

type RawGroupRow = {
  id: string
  name: string
  description: string | null
  created_at: string | null
}

type MemberGroupRow = {
  group_id: string | null
}

type GroupFormValues = {
  name: string
  description?: string
}

function emptyToNull(value?: string) {
  const trimmed = value?.trim()
  return trimmed ? trimmed : null
}

function formatTime(value: string | null) {
  return value ? dayjs(value).format('YYYY-MM-DD HH:mm') : '-'
}

export function GroupsPage() {
  const [form] = Form.useForm<GroupFormValues>()
  const [messageApi, contextHolder] = message.useMessage()
  const [groups, setGroups] = useState<GroupRow[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [modalOpen, setModalOpen] = useState(false)
  const [editingGroup, setEditingGroup] = useState<GroupRow | null>(null)
  const [errorMessage, setErrorMessage] = useState('')
  const [keyword, setKeyword] = useState('')

  const loadGroups = useCallback(async () => {
    try {
      setLoading(true)
      setErrorMessage('')

      const [groupsResult, membersResult] = await Promise.all([
        supabase
          .from('groups')
          .select('id, name, description, created_at')
          .order('created_at', { ascending: false }),
        supabase.from('members').select('group_id'),
      ])

      if (groupsResult.error) {
        throw groupsResult.error
      }

      if (membersResult.error) {
        throw membersResult.error
      }

      const memberCountMap = new Map<string, number>()
      ;((membersResult.data ?? []) as MemberGroupRow[]).forEach((member) => {
        if (!member.group_id) {
          return
        }

        memberCountMap.set(
          member.group_id,
          (memberCountMap.get(member.group_id) ?? 0) + 1,
        )
      })

      const rows = ((groupsResult.data ?? []) as RawGroupRow[]).map(
        (group) => ({
          ...group,
          member_count: memberCountMap.get(group.id) ?? 0,
        }),
      )

      setGroups(rows)
    } catch (error) {
      setErrorMessage(
        error instanceof Error ? error.message : '分组列表加载失败。',
      )
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    // Initial data loading intentionally updates the page loading state.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadGroups()
  }, [loadGroups])

  const filteredGroups = useMemo(() => {
    const normalizedKeyword = keyword.trim().toLowerCase()

    return groups.filter((group) => {
      return (
        !normalizedKeyword ||
        group.name.toLowerCase().includes(normalizedKeyword)
      )
    })
  }, [groups, keyword])

  const columns: ColumnsType<GroupRow> = [
    {
      title: '分组名称',
      dataIndex: 'name',
      key: 'name',
    },
    {
      title: '描述',
      dataIndex: 'description',
      key: 'description',
      render: (value: string | null) => value || '-',
    },
    {
      title: '成员数量',
      dataIndex: 'member_count',
      key: 'member_count',
      width: 120,
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
      width: 160,
      render: (_, record) => (
        <Space size={4}>
          <Button type="link" onClick={() => openEditModal(record)}>
            编辑
          </Button>
          <Popconfirm
            title="确认删除该分组？"
            description="删除分组后，该分组下成员将变为未分组。"
            okText="删除"
            cancelText="取消"
            okButtonProps={{ danger: true }}
            onConfirm={() => handleDeleteGroup(record)}
          >
            <Button type="link" danger>
              删除
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ]

  function openCreateModal() {
    setEditingGroup(null)
    form.resetFields()
    setModalOpen(true)
  }

  function openEditModal(group: GroupRow) {
    setEditingGroup(group)
    form.setFieldsValue({
      name: group.name,
      description: group.description ?? undefined,
    })
    setModalOpen(true)
  }

  function closeModal() {
    setModalOpen(false)
    setEditingGroup(null)
    form.resetFields()
  }

  async function handleSubmitGroup(values: GroupFormValues) {
    try {
      setSaving(true)

      const payload = {
        name: values.name.trim(),
        description: emptyToNull(values.description),
      }

      const { error } = editingGroup
        ? await supabase.from('groups').update(payload).eq('id', editingGroup.id)
        : await supabase.from('groups').insert(payload)

      if (error) {
        throw error
      }

      messageApi.success(editingGroup ? '分组已更新' : '分组已新增')
      closeModal()
      await loadGroups()
    } catch (error) {
      messageApi.error(
        error instanceof Error
          ? error.message
          : editingGroup
            ? '更新分组失败，请稍后重试。'
            : '新增分组失败，请稍后重试。',
      )
    } finally {
      setSaving(false)
    }
  }

  async function handleDeleteGroup(group: GroupRow) {
    try {
      const { error } = await supabase.from('groups').delete().eq('id', group.id)

      if (error) {
        throw error
      }

      messageApi.success('分组已删除，该分组下成员已变为未分组')
      await loadGroups()
    } catch (error) {
      messageApi.error(
        error instanceof Error ? error.message : '删除分组失败，请稍后重试。',
      )
    }
  }

  return (
    <section className="page-panel">
      {contextHolder}
      <div className="groups-page-header">
        <div>
          <Typography.Title level={1}>分组管理</Typography.Title>
          <p>查看、新增、编辑和删除队伍分组。删除分组后，成员会自动变为未分组。</p>
        </div>
        <Button type="primary" onClick={openCreateModal}>
          新增分组
        </Button>
      </div>

      {errorMessage && (
        <Alert
          className="groups-alert"
          message="分组列表加载失败"
          description={errorMessage}
          type="error"
          showIcon
        />
      )}

      <Space className="groups-toolbar" size={12} wrap>
        <Input.Search
          allowClear
          placeholder="搜索分组名称"
          value={keyword}
          onChange={(event) => setKeyword(event.target.value)}
          style={{ width: 240 }}
        />
        <Button onClick={loadGroups} loading={loading}>
          刷新
        </Button>
      </Space>

      <Table
        rowKey="id"
        loading={loading}
        columns={columns}
        dataSource={filteredGroups}
        pagination={false}
      />

      <Modal
        title={editingGroup ? '编辑分组' : '新增分组'}
        open={modalOpen}
        confirmLoading={saving}
        okText="保存"
        cancelText="取消"
        onCancel={closeModal}
        onOk={() => form.submit()}
        destroyOnHidden
      >
        <Form<GroupFormValues>
          form={form}
          layout="vertical"
          onFinish={handleSubmitGroup}
        >
          <Form.Item
            label="分组名称"
            name="name"
            rules={[{ required: true, message: '请输入分组名称' }]}
          >
            <Input placeholder="例如：短跑组" />
          </Form.Item>

          <Form.Item label="描述" name="description">
            <Input.TextArea
              rows={4}
              placeholder="可填写该分组的训练方向、负责人或备注"
            />
          </Form.Item>
        </Form>
      </Modal>
    </section>
  )
}
