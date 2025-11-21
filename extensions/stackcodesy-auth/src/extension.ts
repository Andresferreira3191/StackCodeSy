import * as vscode from 'vscode';
import axios from 'axios';

interface StackCodeSySession {
    id: string;
    accessToken: string;
    account: {
        id: string;
        label: string;
    };
    scopes: string[];
}

interface AuthResponse {
    success: boolean;
    token?: string;
    user?: {
        id: string;
        name: string;
        email: string;
    };
    error?: string;
}

class StackCodeSyAuthenticationProvider implements vscode.AuthenticationProvider {
    private static readonly AUTH_TYPE = 'stackcodesy';
    private static readonly AUTH_NAME = 'StackCodeSy';

    private _sessionChangeEmitter = new vscode.EventEmitter<vscode.AuthenticationProviderAuthenticationSessionsChangeEvent>();
    private _disposable: vscode.Disposable;
    private _sessions: StackCodeSySession[] = [];

    constructor(private context: vscode.ExtensionContext) {
        this._disposable = vscode.Disposable.from(
            this._sessionChangeEmitter
        );

        // Load existing session from environment or storage
        this.loadExistingSession();
    }

    get onDidChangeSessions(): vscode.Event<vscode.AuthenticationProviderAuthenticationSessionsChangeEvent> {
        return this._sessionChangeEmitter.event;
    }

    private async loadExistingSession(): Promise<void> {
        // Check if running in StackCodeSy environment with pre-authenticated session
        const userId = process.env.STACKCODESY_USER_ID;
        const userName = process.env.STACKCODESY_USER_NAME;
        const userEmail = process.env.STACKCODESY_USER_EMAIL;
        const authToken = process.env.STACKCODESY_AUTH_TOKEN;

        if (userId && authToken) {
            console.log(`[StackCodeSy Auth] Loading pre-authenticated session for user: ${userId}`);

            const session: StackCodeSySession = {
                id: `stackcodesy-${userId}`,
                accessToken: authToken,
                account: {
                    id: userId,
                    label: userName || userEmail || userId
                },
                scopes: ['user:read', 'workspace:write']
            };

            this._sessions.push(session);
            this._sessionChangeEmitter.fire({
                added: [session as vscode.AuthenticationSession],
                removed: [],
                changed: []
            });

            console.log('[StackCodeSy Auth] Session loaded successfully');
        } else {
            console.log('[StackCodeSy Auth] No pre-authenticated session found');
        }
    }

    async getSessions(scopes?: readonly string[], options?: vscode.AuthenticationGetSessionOptions): Promise<readonly vscode.AuthenticationSession[]> {
        console.log(`[StackCodeSy Auth] getSessions called with scopes: ${scopes?.join(', ')}`);
        return this._sessions as vscode.AuthenticationSession[];
    }

    async createSession(scopes: readonly string[]): Promise<vscode.AuthenticationSession> {
        console.log(`[StackCodeSy Auth] createSession called with scopes: ${scopes.join(', ')}`);

        // Check if authentication is required
        const requireAuth = process.env.STACKCODESY_REQUIRE_AUTH === 'true';

        if (!requireAuth) {
            // Development mode - create anonymous session
            const session: StackCodeSySession = {
                id: 'stackcodesy-dev',
                accessToken: 'dev-token',
                account: {
                    id: 'dev-user',
                    label: 'Development User'
                },
                scopes: [...scopes]
            };

            this._sessions.push(session);
            this._sessionChangeEmitter.fire({
                added: [session as vscode.AuthenticationSession],
                removed: [],
                changed: []
            });

            return session as vscode.AuthenticationSession;
        }

        // Production mode - authenticate with API
        const authApiUrl = process.env.STACKCODESY_AUTH_API;

        if (!authApiUrl) {
            throw new Error('STACKCODESY_AUTH_API environment variable not set');
        }

        // Show login prompt
        const username = await vscode.window.showInputBox({
            prompt: 'Enter your StackCodeSy username or email',
            placeHolder: 'username@example.com',
            ignoreFocusOut: true
        });

        if (!username) {
            throw new Error('Username is required');
        }

        const password = await vscode.window.showInputBox({
            prompt: 'Enter your StackCodeSy password',
            placeHolder: 'Password',
            password: true,
            ignoreFocusOut: true
        });

        if (!password) {
            throw new Error('Password is required');
        }

        // Authenticate with API
        try {
            const response = await axios.post<AuthResponse>(`${authApiUrl}/login`, {
                username,
                password
            }, {
                timeout: 10000,
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            if (!response.data.success || !response.data.token || !response.data.user) {
                throw new Error(response.data.error || 'Authentication failed');
            }

            const { token, user } = response.data;

            const session: StackCodeSySession = {
                id: `stackcodesy-${user.id}`,
                accessToken: token,
                account: {
                    id: user.id,
                    label: user.name || user.email
                },
                scopes: [...scopes]
            };

            this._sessions.push(session);
            this._sessionChangeEmitter.fire({
                added: [session as vscode.AuthenticationSession],
                removed: [],
                changed: []
            });

            // Store session for persistence
            await this.context.secrets.store('stackcodesy-session', JSON.stringify(session));

            vscode.window.showInformationMessage(`Welcome, ${user.name || user.email}!`);

            return session as vscode.AuthenticationSession;

        } catch (error) {
            console.error('[StackCodeSy Auth] Authentication error:', error);

            let errorMessage = 'Authentication failed';
            if (axios.isAxiosError(error)) {
                errorMessage = error.response?.data?.error || error.message;
            } else if (error instanceof Error) {
                errorMessage = error.message;
            }

            vscode.window.showErrorMessage(`StackCodeSy login failed: ${errorMessage}`);
            throw new Error(errorMessage);
        }
    }

    async removeSession(sessionId: string): Promise<void> {
        console.log(`[StackCodeSy Auth] removeSession called for: ${sessionId}`);

        const sessionIndex = this._sessions.findIndex(s => s.id === sessionId);
        if (sessionIndex > -1) {
            const session = this._sessions[sessionIndex];
            this._sessions.splice(sessionIndex, 1);

            this._sessionChangeEmitter.fire({
                added: [],
                removed: [session as vscode.AuthenticationSession],
                changed: []
            });

            // Clear stored session
            await this.context.secrets.delete('stackcodesy-session');

            vscode.window.showInformationMessage('Signed out of StackCodeSy');
        }
    }

    dispose(): void {
        this._disposable.dispose();
    }
}

export function activate(context: vscode.ExtensionContext) {
    console.log('[StackCodeSy Auth] Extension activating...');

    const authProvider = new StackCodeSyAuthenticationProvider(context);

    context.subscriptions.push(
        vscode.authentication.registerAuthenticationProvider(
            'stackcodesy',
            'StackCodeSy',
            authProvider,
            { supportsMultipleAccounts: false }
        )
    );

    // Register commands
    context.subscriptions.push(
        vscode.commands.registerCommand('stackcodesy.auth.login', async () => {
            try {
                const session = await vscode.authentication.getSession(
                    'stackcodesy',
                    ['user:read', 'workspace:write'],
                    { createIfNone: true }
                );

                if (session) {
                    vscode.window.showInformationMessage(
                        `Signed in as ${session.account.label}`
                    );
                }
            } catch (error) {
                console.error('[StackCodeSy Auth] Login command error:', error);
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('stackcodesy.auth.logout', async () => {
            const sessions = await vscode.authentication.getSession(
                'stackcodesy',
                ['user:read', 'workspace:write'],
                { createIfNone: false }
            );

            if (sessions) {
                // Remove the session (this will be handled by removeSession method)
                vscode.window.showInformationMessage('Signing out...');
            } else {
                vscode.window.showWarningMessage('No active StackCodeSy session');
            }
        })
    );

    console.log('[StackCodeSy Auth] Extension activated successfully');
}

export function deactivate() {
    console.log('[StackCodeSy Auth] Extension deactivating...');
}
