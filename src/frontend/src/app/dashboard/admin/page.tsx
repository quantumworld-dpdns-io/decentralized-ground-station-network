'use client';

import { useState } from 'react';

interface User {
  id: string;
  name: string;
  email: string;
  role: 'admin' | 'operator' | 'viewer';
  status: 'active' | 'suspended' | 'pending';
  stations: number;
  joined: string;
  lastActive: string;
}

const users: User[] = [
  { id: 'usr-001', name: 'Dennis Lee', email: 'dennis@example.com', role: 'admin', status: 'active', stations: 3, joined: '2023-06-15', lastActive: 'Just now' },
  { id: 'usr-002', name: 'Alice Johnson', email: 'alice@example.com', role: 'operator', status: 'active', stations: 2, joined: '2023-08-20', lastActive: '5m ago' },
  { id: 'usr-003', name: 'Bob Smith', email: 'bob@example.com', role: 'operator', status: 'active', stations: 1, joined: '2023-09-01', lastActive: '12m ago' },
  { id: 'usr-004', name: 'Carol White', email: 'carol@example.com', role: 'viewer', status: 'pending', stations: 0, joined: '2024-01-10', lastActive: 'Never' },
  { id: 'usr-005', name: 'David Brown', email: 'david@example.com', role: 'operator', status: 'suspended', stations: 1, joined: '2023-07-05', lastActive: '2d ago' },
  { id: 'usr-006', name: 'Eve Martinez', email: 'eve@example.com', role: 'admin', status: 'active', stations: 5, joined: '2023-05-01', lastActive: '1m ago' },
];

const roleColors: Record<string, string> = {
  admin: 'bg-purple-500/10 text-purple-400',
  operator: 'bg-blue-500/10 text-blue-400',
  viewer: 'bg-surface-800 text-surface-400',
};

const statusColors: Record<string, string> = {
  active: 'text-green-400',
  suspended: 'text-red-400',
  pending: 'text-yellow-400',
};

export default function AdminPage() {
  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');

  const filtered = users.filter((u) => {
    const matchSearch =
      u.name.toLowerCase().includes(search.toLowerCase()) ||
      u.email.toLowerCase().includes(search.toLowerCase()) ||
      u.id.toLowerCase().includes(search.toLowerCase());
    const matchRole = roleFilter === 'all' || u.role === roleFilter;
    return matchSearch && matchRole;
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-white">Admin Panel</h1>
        <p className="text-surface-400 mt-1">
          User management and system administration
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { label: 'Total Users', value: '892' },
          { label: 'Active Operators', value: '234' },
          { label: 'Pending Approvals', value: '12' },
          { label: 'Suspended Accounts', value: '8' },
        ].map((stat) => (
          <div key={stat.label} className="glass rounded-xl p-4">
            <div className="text-2xl font-bold text-white">{stat.value}</div>
            <div className="text-sm text-surface-400">{stat.label}</div>
          </div>
        ))}
      </div>

      <div className="glass rounded-xl p-4">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1">
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search users by name, email, or ID..."
              className="w-full px-4 py-2 rounded-lg bg-surface-800 border border-surface-700 text-white placeholder:text-surface-500 focus:outline-none focus:ring-2 focus:ring-primary-500 transition-all text-sm"
            />
          </div>
          <select
            value={roleFilter}
            onChange={(e) => setRoleFilter(e.target.value)}
            className="px-4 py-2 rounded-lg bg-surface-800 border border-surface-700 text-white text-sm focus:outline-none focus:ring-2 focus:ring-primary-500"
          >
            <option value="all">All Roles</option>
            <option value="admin">Admin</option>
            <option value="operator">Operator</option>
            <option value="viewer">Viewer</option>
          </select>
          <button className="px-4 py-2 rounded-lg bg-primary-600 text-white text-sm hover:bg-primary-500 transition-colors">
            Invite User
          </button>
        </div>
      </div>

      <div className="glass rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-surface-800">
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">User</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Email</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Role</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Status</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Stations</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Joined</th>
                <th className="text-left px-4 py-3 text-sm font-medium text-surface-400">Active</th>
                <th className="text-right px-4 py-3 text-sm font-medium text-surface-400">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((user) => (
                <tr key={user.id} className="border-b border-surface-800/50 hover:bg-surface-800/30 transition-colors">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-full bg-surface-700 flex items-center justify-center">
                        <span className="text-sm font-medium text-surface-300">
                          {user.name.charAt(0)}
                        </span>
                      </div>
                      <div>
                        <div className="text-sm font-medium text-white">
                          {user.name}
                        </div>
                        <div className="text-xs text-surface-500 font-mono">
                          {user.id}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-sm text-surface-300">
                    {user.email}
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`px-2 py-1 text-xs rounded-full ${
                        roleColors[user.role]
                      }`}
                    >
                      {user.role.charAt(0).toUpperCase() + user.role.slice(1)}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className={`text-sm font-medium ${
                        statusColors[user.status]
                      }`}
                    >
                      {user.status.charAt(0).toUpperCase() +
                        user.status.slice(1)}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-surface-300">
                    {user.stations}
                  </td>
                  <td className="px-4 py-3 text-sm text-surface-300">
                    {user.joined}
                  </td>
                  <td className="px-4 py-3 text-sm text-surface-300">
                    {user.lastActive}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex gap-2 justify-end">
                      <button className="text-sm text-primary-400 hover:text-primary-300 transition-colors">
                        Edit
                      </button>
                      <button className="text-sm text-red-400 hover:text-red-300 transition-colors">
                        Suspend
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {filtered.length === 0 && (
          <div className="text-center py-12 text-surface-500">
            No users found.
          </div>
        )}
      </div>
    </div>
  );
}
