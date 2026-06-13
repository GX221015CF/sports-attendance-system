import { ConfigProvider } from 'antd'
import zhCN from 'antd/locale/zh_CN'
import dayjs from 'dayjs'
import 'dayjs/locale/zh-cn'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import './App.css'
import { AppLayout } from './components/AppLayout'
import { CreateSessionPage } from './pages/CreateSessionPage'
import { DashboardPage } from './pages/DashboardPage'
import { GroupsPage } from './pages/GroupsPage'
import { ImportMembersPage } from './pages/ImportMembersPage'
import { MembersPage } from './pages/MembersPage'
import { SessionDetailPage } from './pages/SessionDetailPage'
import { SessionsPage } from './pages/SessionsPage'

dayjs.locale('zh-cn')

function App() {
  return (
    <ConfigProvider
      locale={zhCN}
      theme={{
        token: {
          colorPrimary: '#1E40AF',
          borderRadius: 8,
        },
      }}
    >
      <BrowserRouter>
        <Routes>
          <Route element={<AppLayout />}>
            <Route path="/" element={<Navigate to="/dashboard" replace />} />
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/members" element={<MembersPage />} />
            <Route path="/groups" element={<GroupsPage />} />
            <Route path="/members/import" element={<ImportMembersPage />} />
            <Route path="/sessions" element={<SessionsPage />} />
            <Route path="/sessions/create" element={<CreateSessionPage />} />
            <Route path="/sessions/:id" element={<SessionDetailPage />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </ConfigProvider>
  )
}

export default App
