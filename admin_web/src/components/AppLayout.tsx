import { Layout, Menu } from 'antd'
import { Outlet, useLocation, useNavigate } from 'react-router-dom'

const { Header, Sider, Content } = Layout

const menuItems = [
  { key: '/dashboard', label: '数据看板' },
  { key: '/members', label: '成员管理' },
  { key: '/groups', label: '分组管理' },
  { key: '/members/import', label: 'Excel 导入' },
  { key: '/sessions', label: '签到任务' },
  { key: '/sessions/create', label: '创建签到' },
]

function getSelectedKey(pathname: string) {
  if (pathname.startsWith('/sessions/create')) {
    return '/sessions/create'
  }

  if (pathname.startsWith('/sessions/')) {
    return '/sessions'
  }

  if (pathname.startsWith('/members/import')) {
    return '/members/import'
  }

  if (pathname.startsWith('/members')) {
    return '/members'
  }

  if (pathname.startsWith('/groups')) {
    return '/groups'
  }

  return pathname
}

export function AppLayout() {
  const location = useLocation()
  const navigate = useNavigate()
  const selectedKey = getSelectedKey(location.pathname)

  return (
    <Layout className="app-shell">
      <Sider className="app-sider" width={232}>
        <div className="app-brand">Sports Attendance</div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[selectedKey]}
          items={menuItems}
          onClick={({ key }) => navigate(key)}
        />
      </Sider>
      <Layout>
        <Header className="app-header">
          <h1 className="app-header-title">运动队签到考勤系统</h1>
        </Header>
        <Content className="app-content">
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  )
}

