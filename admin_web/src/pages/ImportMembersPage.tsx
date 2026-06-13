import {
  Alert,
  Button,
  Card,
  Col,
  Row,
  Space,
  Statistic,
  Table,
  Tag,
  Typography,
  Upload,
  message,
} from 'antd'
import type { ColumnsType } from 'antd/es/table'
import type { UploadProps } from 'antd'
import { InboxOutlined } from '@ant-design/icons'
import * as XLSX from 'xlsx'
import { useMemo, useState } from 'react'
import { supabase } from '../api/supabase'

const { Dragger } = Upload

type ValidationStatus = 'valid' | 'invalid'

type PreviewRow = {
  key: string
  rowNumber: number
  name: string
  studentId: string
  gender: string
  phone: string
  groupName: string
  status: ValidationStatus
  errors: string[]
}

type GroupRow = {
  id: string
  name: string
}

type ExcelMemberRow = {
  姓名?: unknown
  学号?: unknown
  性别?: unknown
  手机号?: unknown
  分组?: unknown
}

function normalizeCell(value: unknown) {
  if (value === null || value === undefined) {
    return ''
  }

  return String(value).trim()
}

function validateRow(row: ExcelMemberRow, index: number): PreviewRow {
  const name = normalizeCell(row.姓名)
  const studentId = normalizeCell(row.学号)
  const gender = normalizeCell(row.性别)
  const phone = normalizeCell(row.手机号)
  const groupName = normalizeCell(row.分组) || '未分组'
  const errors: string[] = []

  if (!name) {
    errors.push('姓名不能为空')
  }

  if (gender && gender !== '男' && gender !== '女') {
    errors.push('性别只能是男或女')
  }

  return {
    key: String(index + 2),
    rowNumber: index + 2,
    name,
    studentId,
    gender,
    phone,
    groupName,
    status: errors.length > 0 ? 'invalid' : 'valid',
    errors,
  }
}

const columns: ColumnsType<PreviewRow> = [
  {
    title: '行号',
    dataIndex: 'rowNumber',
    key: 'rowNumber',
    width: 80,
  },
  {
    title: '姓名',
    dataIndex: 'name',
    key: 'name',
    render: (value: string) => value || '-',
  },
  {
    title: '学号',
    dataIndex: 'studentId',
    key: 'studentId',
    render: (value: string) => value || '-',
  },
  {
    title: '性别',
    dataIndex: 'gender',
    key: 'gender',
    render: (value: string) => value || '-',
  },
  {
    title: '手机号',
    dataIndex: 'phone',
    key: 'phone',
    render: (value: string) => value || '-',
  },
  {
    title: '分组',
    dataIndex: 'groupName',
    key: 'groupName',
  },
  {
    title: '校验状态',
    dataIndex: 'status',
    key: 'status',
    render: (value: ValidationStatus) =>
      value === 'valid' ? (
        <Tag color="green">有效</Tag>
      ) : (
        <Tag color="red">错误</Tag>
      ),
  },
  {
    title: '错误信息',
    dataIndex: 'errors',
    key: 'errors',
    render: (errors: string[]) => (errors.length ? errors.join('；') : '-'),
  },
]

export function ImportMembersPage() {
  const [previewRows, setPreviewRows] = useState<PreviewRow[]>([])
  const [importing, setImporting] = useState(false)
  const [messageApi, contextHolder] = message.useMessage()

  const stats = useMemo(() => {
    const total = previewRows.length
    const invalid = previewRows.filter((row) => row.status === 'invalid').length
    return {
      total,
      valid: total - invalid,
      invalid,
    }
  }, [previewRows])

  const validRows = useMemo(
    () => previewRows.filter((row) => row.status === 'valid'),
    [previewRows],
  )

  async function parseExcelFile(file: File) {
    try {
      const buffer = await file.arrayBuffer()
      const workbook = XLSX.read(buffer, { type: 'array' })
      const firstSheetName = workbook.SheetNames[0]

      if (!firstSheetName) {
        throw new Error('Excel 文件中没有工作表')
      }

      const sheet = workbook.Sheets[firstSheetName]
      const rows = XLSX.utils.sheet_to_json<ExcelMemberRow>(sheet, {
        defval: '',
      })

      setPreviewRows(rows.map(validateRow))
      messageApi.success('Excel 解析完成')
    } catch (error) {
      setPreviewRows([])
      messageApi.error(
        error instanceof Error ? error.message : 'Excel 解析失败，请检查文件格式。',
      )
    }
  }

  const uploadProps: UploadProps = {
    accept: '.xlsx,.xls',
    maxCount: 1,
    showUploadList: false,
    beforeUpload: (file) => {
      const fileName = file.name.toLowerCase()
      const isExcel = fileName.endsWith('.xlsx') || fileName.endsWith('.xls')

      if (!isExcel) {
        messageApi.error('请上传 .xlsx 或 .xls 文件')
        return Upload.LIST_IGNORE
      }

      parseExcelFile(file)
      return false
    },
  }

  async function handleImportValidRows() {
    try {
      setImporting(true)

      const groupNames = Array.from(
        new Set(
          validRows
            .map((row) => row.groupName)
            .filter((groupName) => groupName && groupName !== '未分组'),
        ),
      )

      const { data: existingGroups, error: groupsError } = await supabase
        .from('groups')
        .select('id, name')

      if (groupsError) {
        throw groupsError
      }

      const groupMap = new Map<string, string>()
      ;((existingGroups ?? []) as GroupRow[]).forEach((group) => {
        groupMap.set(group.name, group.id)
      })

      const newGroupNames = groupNames.filter(
        (groupName) => !groupMap.has(groupName),
      )

      let createdGroupCount = 0

      if (newGroupNames.length > 0) {
        const { data: createdGroups, error: createGroupsError } = await supabase
          .from('groups')
          .insert(
            newGroupNames.map((name) => ({
              name,
              description: 'Excel 导入自动创建',
            })),
          )
          .select('id, name')

        if (createGroupsError) {
          throw createGroupsError
        }

        createdGroupCount = createdGroups?.length ?? 0
        ;((createdGroups ?? []) as GroupRow[]).forEach((group) => {
          groupMap.set(group.name, group.id)
        })
      }

      const membersPayload = validRows.map((row) => ({
        name: row.name,
        student_id: row.studentId || null,
        gender: row.gender || null,
        phone: row.phone || null,
        group_id:
          row.groupName && row.groupName !== '未分组'
            ? groupMap.get(row.groupName) ?? null
            : null,
        is_active: true,
      }))

      const { error: insertMembersError } = await supabase
        .from('members')
        .insert(membersPayload)

      if (insertMembersError) {
        throw insertMembersError
      }

      messageApi.success(
        `成功导入 ${membersPayload.length} 名成员，跳过 ${stats.invalid} 条错误行，自动创建 ${createdGroupCount} 个分组。`,
      )
    } catch (error) {
      messageApi.error(
        error instanceof Error ? error.message : '导入成员失败，请稍后重试。',
      )
    } finally {
      setImporting(false)
    }
  }

  return (
    <section className="page-panel">
      {contextHolder}
      <div className="import-page-header">
        <div>
          <Typography.Title level={1}>Excel 导入成员</Typography.Title>
          <p>支持导入字段：姓名、学号、性别、手机号、分组。</p>
        </div>
        <Button onClick={() => setPreviewRows([])} disabled={!previewRows.length}>
          清空预览
        </Button>
      </div>

      <Dragger className="import-uploader" {...uploadProps}>
        <p className="ant-upload-drag-icon">
          <InboxOutlined />
        </p>
        <p className="ant-upload-text">点击或拖拽 Excel 文件到此处</p>
        <p className="ant-upload-hint">
          第一行需要作为表头，支持 .xlsx / .xls 文件。当前仅解析预览，不会写入数据库。
        </p>
      </Dragger>

      <Row gutter={[16, 16]} className="import-stats">
        <Col xs={24} md={8}>
          <Card>
            <Statistic title="总行数" value={stats.total} />
          </Card>
        </Col>
        <Col xs={24} md={8}>
          <Card>
            <Statistic title="有效行数" value={stats.valid} />
          </Card>
        </Col>
        <Col xs={24} md={8}>
          <Card>
            <Statistic title="错误行数" value={stats.invalid} />
          </Card>
        </Col>
      </Row>

      {stats.invalid > 0 && (
        <Alert
          className="import-alert"
          message="存在错误行"
          description="仅会导入校验通过的行，错误行将被跳过。"
          type="warning"
          showIcon
        />
      )}

      <Space direction="vertical" size={12} className="import-preview">
        <div className="import-preview-header">
          <Typography.Title level={2}>预览数据</Typography.Title>
          <Button
            type="primary"
            loading={importing}
            disabled={validRows.length === 0}
            onClick={handleImportValidRows}
          >
            确认导入
          </Button>
        </div>
        <Table
          rowKey="key"
          columns={columns}
          dataSource={previewRows}
          pagination={false}
          scroll={{ x: 960 }}
        />
      </Space>
    </section>
  )
}
