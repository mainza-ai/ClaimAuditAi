import { useState } from 'react';
import { useQuery, useMutation } from '@tanstack/react-query';
import { apiClient } from '../api/client';
import { useRoleStore } from '../store/roleStore';
import { PERMISSIONS } from '../utils/permissions';
import { AlertTriangle, UserPlus, Trash2 } from 'lucide-react';

const AVAILABLE_ROLES = ['Viewer', 'Auditor', 'Specialist', 'Director', 'Admin'];

interface UserEntry {
  username: string;
  fullName: string;
  roles: string[];
}

export function UserManagement() {
  const { activeRole } = useRoleStore();
  const [showCreate, setShowCreate] = useState(false);
  const [editingUser, setEditingUser] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);

  // Form state
  const [formUsername, setFormUsername] = useState('');
  const [formPassword, setFormPassword] = useState('');
  const [formFullName, setFormFullName] = useState('');
  const [formRoles, setFormRoles] = useState<string[]>([]);
  const [formError, setFormError] = useState('');

  if (!PERMISSIONS.canManageData(activeRole)) {
    return (
      <div style={{ padding: 40, textAlign: 'center' }}>
        <AlertTriangle size={32} style={{ color: 'var(--color-warning)', marginBottom: 16 }} />
        <h2 style={{ color: 'var(--text-primary)', margin: 0 }}>Access Restricted</h2>
        <p style={{ color: 'var(--text-secondary)', marginTop: 8 }}>
          User management requires Tech Owner / Admin role.
        </p>
      </div>
    );
  }

  const { data: usersResponse, refetch: refetchUsers } = useQuery<{ data: UserEntry[]; total: number }>({
    queryKey: ['system-users'],
    queryFn: () => apiClient.get('/system/users').then((r) => r.data),
  });
  const users = usersResponse?.data ?? [];

  const createUser = useMutation({
    mutationFn: (body: object) => apiClient.post('/system/users', body),
    onSuccess: () => {
      refetchUsers();
      resetForm();
    },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    onError: (err: any) => setFormError(err?.response?.data?.error || 'Failed to create user'),
  });

  const updateUser = useMutation({
    mutationFn: ({ username, ...body }: { username: string } & Record<string, unknown>) =>
      apiClient.put(`/system/users/${username}`, body),
    onSuccess: () => {
      refetchUsers();
      setEditingUser(null);
      resetForm();
    },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    onError: (err: any) => setFormError(err?.response?.data?.error || 'Failed to update user'),
  });

  const deleteUser = useMutation({
    mutationFn: (username: string) => apiClient.delete(`/system/users/${username}`),
    onSuccess: () => {
      refetchUsers();
      setConfirmDelete(null);
    },
  });

  const resetForm = () => {
    setFormUsername('');
    setFormPassword('');
    setFormFullName('');
    setFormRoles([]);
    setFormError('');
    setShowCreate(false);
    setEditingUser(null);
  };

  const toggleRole = (role: string) => {
    setFormRoles((prev) => (prev.includes(role) ? prev.filter((r) => r !== role) : [...prev, role]));
  };

  const startEdit = (user: UserEntry) => {
    setEditingUser(user.username);
    setFormUsername(user.username);
    setFormFullName(user.fullName);
    setFormRoles([...user.roles]);
    setFormPassword('');
    setShowCreate(true);
  };

  const handleSubmit = () => {
    if (!formUsername) {
      setFormError('Username is required.');
      return;
    }
    if (!editingUser && !formPassword) {
      setFormError('Password is required for new users.');
      return;
    }
    if (formRoles.length === 0) {
      setFormError('At least one role is required.');
      return;
    }

    if (editingUser) {
      updateUser.mutate({ username: editingUser, fullName: formFullName, roles: formRoles, password: formPassword });
    } else {
      createUser.mutate({ username: formUsername, password: formPassword, fullName: formFullName, roles: formRoles });
    }
  };

  return (
    <div style={{ maxWidth: 720, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 600, color: 'var(--text-primary)' }}>User Management</h1>
          <p style={{ margin: '6px 0 0', fontSize: 13, color: 'var(--text-secondary)' }}>
            Manage user accounts and role assignments. Credentials are stored as HMAC-SHA256 hashes in the INTEROP
            namespace.
          </p>
        </div>
        <button
          onClick={() => {
            resetForm();
            setShowCreate(true);
          }}
          className="btn-primary"
          style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13 }}
        >
          <UserPlus size={15} /> Add User
        </button>
      </div>

      {/* Create / Edit form modal */}
      {showCreate && (
        <div className="card" style={{ padding: 20 }}>
          <h2 style={{ margin: '0 0 16px', fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>
            {editingUser ? `Edit ${editingUser}` : 'Create New User'}
          </h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {!editingUser && (
              <div>
                <label
                  style={{
                    fontSize: 12,
                    fontWeight: 500,
                    color: 'var(--text-secondary)',
                    display: 'block',
                    marginBottom: 4,
                  }}
                >
                  Username
                </label>
                <input
                  value={formUsername}
                  onChange={(e) => setFormUsername(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 6,
                    border: '1px solid var(--border-default)',
                    backgroundColor: 'var(--bg-input)',
                    color: 'var(--text-primary)',
                    fontSize: 14,
                    fontFamily: 'var(--font-mono)',
                  }}
                />
              </div>
            )}
            <div>
              <label
                style={{
                  fontSize: 12,
                  fontWeight: 500,
                  color: 'var(--text-secondary)',
                  display: 'block',
                  marginBottom: 4,
                }}
              >
                Full Name
              </label>
              <input
                value={formFullName}
                onChange={(e) => setFormFullName(e.target.value)}
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 6,
                  border: '1px solid var(--border-default)',
                  backgroundColor: 'var(--bg-input)',
                  color: 'var(--text-primary)',
                  fontSize: 14,
                }}
              />
            </div>
            <div>
              <label
                style={{
                  fontSize: 12,
                  fontWeight: 500,
                  color: 'var(--text-secondary)',
                  display: 'block',
                  marginBottom: 4,
                }}
              >
                Password {editingUser ? '(leave blank to keep current)' : ''}
              </label>
              <input
                type="password"
                value={formPassword}
                onChange={(e) => setFormPassword(e.target.value)}
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 6,
                  border: '1px solid var(--border-default)',
                  backgroundColor: 'var(--bg-input)',
                  color: 'var(--text-primary)',
                  fontSize: 14,
                }}
              />
            </div>
            <div>
              <label
                style={{
                  fontSize: 12,
                  fontWeight: 500,
                  color: 'var(--text-secondary)',
                  display: 'block',
                  marginBottom: 6,
                }}
              >
                Roles
              </label>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                {AVAILABLE_ROLES.map((role) => (
                  <button
                    key={role}
                    onClick={() => toggleRole(role)}
                    style={{
                      padding: '4px 10px',
                      borderRadius: 4,
                      fontSize: 12,
                      cursor: 'pointer',
                      fontWeight: 500,
                      border: `1px solid ${formRoles.includes(role) ? 'var(--accent-primary)' : 'var(--border-default)'}`,
                      backgroundColor: formRoles.includes(role) ? 'var(--accent-subtle)' : 'transparent',
                      color: formRoles.includes(role) ? 'var(--accent-text)' : 'var(--text-secondary)',
                    }}
                  >
                    {role}
                  </button>
                ))}
              </div>
            </div>
            {formError && <p style={{ margin: 0, fontSize: 13, color: 'var(--color-danger)' }}>{formError}</p>}
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                onClick={handleSubmit}
                className="btn-primary"
                style={{ fontSize: 13 }}
                disabled={createUser.isPending || updateUser.isPending}
              >
                {createUser.isPending || updateUser.isPending
                  ? 'Saving...'
                  : editingUser
                    ? 'Save Changes'
                    : 'Create User'}
              </button>
              <button onClick={resetForm} className="btn-ghost" style={{ fontSize: 13 }}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* User list */}
      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
          <thead>
            <tr style={{ borderBottom: '1px solid var(--border-default)' }}>
              <th
                style={{
                  textAlign: 'left',
                  padding: '12px 16px',
                  fontWeight: 600,
                  color: 'var(--text-tertiary)',
                  fontSize: 11,
                  textTransform: 'uppercase',
                  letterSpacing: '0.06em',
                }}
              >
                Username
              </th>
              <th
                style={{
                  textAlign: 'left',
                  padding: '12px 16px',
                  fontWeight: 600,
                  color: 'var(--text-tertiary)',
                  fontSize: 11,
                  textTransform: 'uppercase',
                  letterSpacing: '0.06em',
                }}
              >
                Full Name
              </th>
              <th
                style={{
                  textAlign: 'left',
                  padding: '12px 16px',
                  fontWeight: 600,
                  color: 'var(--text-tertiary)',
                  fontSize: 11,
                  textTransform: 'uppercase',
                  letterSpacing: '0.06em',
                }}
              >
                Roles
              </th>
              <th
                style={{
                  textAlign: 'right',
                  padding: '12px 16px',
                  fontWeight: 600,
                  color: 'var(--text-tertiary)',
                  fontSize: 11,
                  textTransform: 'uppercase',
                  letterSpacing: '0.06em',
                }}
              >
                Actions
              </th>
            </tr>
          </thead>
          <tbody>
            {users.map((user) => (
              <tr key={user.username} style={{ borderBottom: '1px solid var(--border-default)' }}>
                <td
                  style={{
                    padding: '12px 16px',
                    fontFamily: 'var(--font-mono)',
                    fontWeight: 600,
                    color: 'var(--text-primary)',
                  }}
                >
                  {user.username}
                </td>
                <td style={{ padding: '12px 16px', color: 'var(--text-secondary)' }}>{user.fullName}</td>
                <td style={{ padding: '12px 16px' }}>
                  <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                    {user.roles.map((role) => (
                      <span
                        key={role}
                        style={{
                          padding: '2px 8px',
                          borderRadius: 4,
                          fontSize: 11,
                          border: '1px solid var(--border-default)',
                          color: 'var(--text-secondary)',
                          fontWeight: 500,
                        }}
                      >
                        {role}
                      </span>
                    ))}
                  </div>
                </td>
                <td style={{ padding: '12px 16px', textAlign: 'right' }}>
                  <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
                    <button
                      onClick={() => startEdit(user)}
                      className="btn-ghost"
                      style={{ fontSize: 11, padding: '4px 8px' }}
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => setConfirmDelete(user.username)}
                      className="btn-ghost"
                      style={{ fontSize: 11, padding: '4px 8px', color: 'var(--color-danger)' }}
                    >
                      <Trash2 size={12} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Delete confirmation modal */}
      {confirmDelete && (
        <div className="card" style={{ padding: 20, border: '1px solid var(--color-danger-border)' }}>
          <p style={{ margin: '0 0 12px', fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>
            Delete user "{confirmDelete}"?
          </p>
          <p style={{ margin: '0 0 12px', fontSize: 13, color: 'var(--text-secondary)' }}>
            This action cannot be undone. The user will be permanently removed from the credential store.
          </p>
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              onClick={() => deleteUser.mutate(confirmDelete)}
              disabled={deleteUser.isPending}
              style={{
                padding: '8px 16px',
                borderRadius: 6,
                border: 'none',
                backgroundColor: 'var(--color-danger)',
                color: 'white',
                fontSize: 14,
                fontWeight: 500,
                cursor: 'pointer',
              }}
            >
              {deleteUser.isPending ? 'Deleting...' : 'Delete'}
            </button>
            <button onClick={() => setConfirmDelete(null)} className="btn-ghost">
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
