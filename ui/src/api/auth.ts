import { apiClient, setAccessToken } from './client';

interface LoginResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
  scope: string;
}

interface TokenClaims {
  sub: string;
  name: string;
  fhirUser: string;
  roles: string[];
  scope: string;
  exp: number;
  iat: number;
}

function parseJwtPayload(token: string): TokenClaims | null {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const payload = parts[1];
    const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
    const json = atob(base64);
    const claims = JSON.parse(json);
    return {
      sub: claims.sub || '',
      name: claims.name || '',
      fhirUser: claims.fhirUser || '',
      roles: claims.roles || [],
      scope: claims.scope || '',
      exp: claims.exp || 0,
      iat: claims.iat || 0,
    };
  } catch {
    return null;
  }
}

export async function login(username: string, password: string): Promise<{ token: string; claims: TokenClaims }> {
  const { data } = await apiClient.post<LoginResponse>('/auth/login', {
    grant_type: 'password',
    username,
    password,
    client_id: 'claimaudit-ui',
    scope: 'launch fhirUser user/Claim.read user/Claim.write user/ClaimResponse.read user/Task.read user/Task.write online_access',
  });

  const token = data.access_token;
  const claims = parseJwtPayload(token);

  if (!claims) {
    throw new Error('Failed to parse authentication token');
  }

  setAccessToken(token);
  return { token, claims };
}

export function logout() {
  setAccessToken(null);
  localStorage.removeItem('claimauditai_token');
  window.location.href = '/login';
}

export function getCurrentClaims(): TokenClaims | null {
  const token = localStorage.getItem('claimauditai_token');
  if (!token) return null;
  const claims = parseJwtPayload(token);
  if (!claims) return null;
  // IRIS JWT uses $HOROLOG days-since-1840, not Unix timestamp.
  // Skip strict expiration check and let the backend validate the token.
  return claims;
}
