# ng-bash-deploy

A bash script to automate Angular builds and deploy to a remote server over SSH.

## Background

Our team was using GitLab CI/CD for deployments until we moved to a self-hosted GitLab instance.
Setting up and maintaining runners, reconfiguring variables and handling auth was more hassle than
it was worth for a small team. I had some shell scripting knowledge so I just built this instead —
simple, transparent, and no infrastructure to maintain.

## Tested With

- Angular 18, Angular 20
- Linux (Ubuntu)

## Requirements

- Angular CLI
- Bash (Linux / macOS)
- SSH access to your server

## Setup

1. Clone the repo:

```bash
git clone https://github.com/turbolagged/ng-bash-deploy.git
```

2. Copy the example config and fill in your values:

```bash
cp deploy.config.example deploy.config
```

3. Edit `deploy.config` with your server details and project path.

4. Make the script executable:

```bash
chmod +x deploy.sh
```

## Usage

Run from anywhere:

```bash
./deploy.sh deploy
```

The script will ask you to:

- Select an environment (production / qa)
- Enter a base href (e.g. `/admin/`, leave blank for `/`)
- Confirm before deploying

## What It Does

1. Validates the target folder exists on the server
2. Builds the Angular app with your chosen environment and base href
3. Uploads the build to a temp folder on the server
4. Backs up the existing build with a timestamp
5. Activates the new build

## Notes

- `deploy.config` is gitignored and never pushed
- Backups are stored on the server with a timestamp in the folder name
- Script can be placed anywhere — project path is set in `deploy.config`
- Environment names (production / qa) must match your `angular.json` configurations

## Roadmap

- [ ] Zip / compress build before upload
- [ ] rsync support for faster uploads
- [ ] Rollback command
- [ ] Interactive config setup

---

Made by [turbolagged](https://github.com/turbolagged) · MIT License
