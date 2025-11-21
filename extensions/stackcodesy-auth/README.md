# StackCodeSy Authentication Extension

Custom authentication provider for StackCodeSy platform.

## Features

- **Environment-based Authentication**: Automatically loads pre-authenticated sessions from environment variables
- **API Integration**: Connects to your authentication API for user validation
- **Secure Token Management**: Uses VSCode's secret storage for token persistence
- **Development Mode**: Supports auth-free mode for local development

## Configuration

### Environment Variables

```bash
# Required for authentication
STACKCODESY_REQUIRE_AUTH=true
STACKCODESY_AUTH_API=https://api.yourplatform.com/auth

# Pre-authenticated session (optional)
STACKCODESY_USER_ID=user123
STACKCODESY_USER_NAME="John Doe"
STACKCODESY_USER_EMAIL=john@example.com
STACKCODESY_AUTH_TOKEN=your-jwt-token
```

### API Integration

Your authentication API should implement these endpoints:

#### POST /login

Request:
```json
{
  "username": "user@example.com",
  "password": "password123"
}
```

Response (success):
```json
{
  "success": true,
  "token": "jwt-token-here",
  "user": {
    "id": "user123",
    "name": "John Doe",
    "email": "user@example.com"
  }
}
```

Response (error):
```json
{
  "success": false,
  "error": "Invalid credentials"
}
```

## Development

### Build Extension

```bash
cd extensions/stackcodesy-auth
npm install
npm run compile
```

### Package Extension

```bash
npm run package
```

This creates a `.vsix` file that can be installed in VSCode.

### Install Extension

```bash
code --install-extension stackcodesy-auth-1.0.0.vsix
```

## Usage

### Automatic Authentication

When running in StackCodeSy environment, authentication happens automatically using environment variables.

### Manual Authentication

Users can also sign in manually using the command palette:

1. Open Command Palette (`Cmd+Shift+P` or `Ctrl+Shift+P`)
2. Type "Sign in to StackCodeSy"
3. Enter credentials
4. Extension will authenticate with your API

## License

MIT
