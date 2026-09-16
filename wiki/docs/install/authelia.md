# Authelia Single Sign-On (SSO) & Two-Factor Authentication

DockServer uses **[Authelia](https://www.authelia.com/)** as an authentication and authorization server to protect your web applications with Single Sign-On (SSO) and Multi-Factor Authentication (MFA).

---

## 🌟 Key Features

- **Single Sign-On (SSO)**: Log in once at `https://authelia.yourdomain.com` and access all your secured applications seamlessly.
- **Multiple Two-Factor Authentication (2FA) Methods**:
  - **Time-based One-Time Password (TOTP)**: Compatible with Google Authenticator, Bitwarden, 1Password, Authy, and Aegis.
  - **Security Keys (FIDO2 / WebAuthn / U2F)**: Native hardware key support with Yubikey.
  - **Push Notifications**: Supported via Duo integration.
- **Fine-Grained Access Control**: Protect sensitive administrative tools with strict Two-Factor authentication while allowing public access to media client APIs (Plex, Jellyfin mobile apps).
- **Secure Password Hashing**: Passwords stored using industry-standard **Argon2id** cryptography.
- **OpenID Connect (OIDC)**: Built-in OIDC provider support.

---

## 🚀 Initial Login

During the initial gateway setup (`dockserver -i`), you configured your Authelia **Admin Username** and **Password**.

1. Navigate to:
   ```
   https://authelia.yourdomain.com
   ```
2. Log in with your admin credentials.

---

## 📱 Setting Up Two-Factor Authentication (2FA / TOTP)

Follow these steps to require an authenticator app code for your domain:

### Step 1: Edit Authelia Configuration
Open the configuration file:

```bash
sudo nano /opt/appdata/authelia/configuration.yml
```

1. Ensure the `totp` section is configured:
   ```yaml
   totp:
     issuer: authelia
     period: 30
     skew: 1
   ```

2. Scroll down to the `access_control` rules section. Change the policy for your domain from `one_factor` to `two_factor`:
   ```yaml
   access_control:
     default_policy: deny
     rules:
       - domain: "*.yourdomain.com"
         policy: two_factor
   ```

Save and exit (`Ctrl + O`, `Enter`, `Ctrl + X`).

### Step 2: Restart the Container
```bash
docker compose -f /opt/appdata/compose/docker-compose.yml restart authelia
```

### Step 3: Register Your Authenticator App
1. Visit `https://authelia.yourdomain.com` and log in with your username and password.
2. Click **"Not registered yet? Register device"**.
3. Since SMTP email is optional, Authelia writes the registration confirmation link directly to the notification file on your server:
   ```bash
   cat /opt/appdata/authelia/notification.txt
   ```
4. Copy the URL from `notification.txt` and open it in your browser.
5. Scan the displayed QR code with your authenticator app (Google Authenticator, Bitwarden, Authy, etc.).
6. Enter the 6-digit code to finalize registration.

Two-Factor Authentication is now active and enforced across your subdomains!

---

## 👥 Adding & Managing Users

Authelia stores user accounts in `/opt/appdata/authelia/users_database.yml`:

```bash
sudo nano /opt/appdata/authelia/users_database.yml
```

### Adding a New User
To add a user, generate an Argon2id password hash using the Authelia container:

```bash
docker run --rm authelia/authelia:latest authelia crypto hash-password "YourSecurePassword"
```

Add the new user entry to `users_database.yml`:

```yaml
users:
  johndoe:
    displayname: "John Doe"
    password: "$argon2id$v=19$m=65536,t=3,p=4$..."
    email: "johndoe@example.com"
    groups:
      - users
      - admin
```

Save the file and restart Authelia:
```bash
docker compose -f /opt/appdata/compose/docker-compose.yml restart authelia
```
