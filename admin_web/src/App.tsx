import { ConfigProvider } from 'antd'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import './App.css'
import { AppLayout } from './components/AppLayout'
import { CreateSessionPage } from './pages/CreateSessionPage'
import { DashboardPage } from './pages/DashboardPage'
import { ImportMembersPage } from './pages/ImportMembersPage'
import { MembersPage } from './pages/MembersPage'
import { SessionDetailPage } from './pages/SessionDetailPage'
import { SessionsPage } from './pages/SessionsPage'

function App() {
  return (
    <ConfigProvider
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
