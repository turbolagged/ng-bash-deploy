#!/bin/bash

# ── Load config ──
CONFIG_FILE="$(dirname "$0")/deploy.config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "No config found. Run: ./deploy.sh config"
    exit 1
fi

source "$CONFIG_FILE"

# ── SSH Agent ──
# eval $(ssh-agent -s) > /dev/null
# ssh-add "$SSH_KEY"
# trap 'ssh-agent -k > /dev/null 2>&1' EXIT

# ── Date ──
DATE=$(date +"%B_%d_%Y_%H-%M-%S")

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── UI Helpers ──
print_banner() {
  clear
  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║            🚀  D E P L O Y . S H            ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

print_info() {
  echo -e "  ${DIM}$1${RESET}"
}

print_step() {
  printf "  ${DIM}[%s/5]${RESET}  %-38s" "$1" "$2"
}

print_ok() {
  echo -e "${GREEN}✓ done${RESET}"
}

print_fail() {
  echo -e "${RED}✗ failed${RESET}"
}

print_pending() {
  echo -e "${DIM}-${RESET}"
}

print_success_box() {
  echo ""
  echo -e "${GREEN}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║          ✅  DEPLOYMENT SUCCESSFUL!          ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

print_fail_box() {
  echo ""
  echo -e "${RED}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║          ❌  DEPLOYMENT FAILED               ║"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

# ── Functions ──

select_options() {
  print_banner

  echo -e "  ${WHITE}Select environment:${RESET}"
  echo -e "  ${DIM}1) production${RESET}"
  echo -e "  ${DIM}2) qa${RESET}"
  echo ""
  read -p "  Enter choice [1-2]: " ENV_CHOICE

  case "$ENV_CHOICE" in
    1) ENVIRONMENT="production" ;;
    2) ENVIRONMENT="qa" ;;
    *)
      echo -e "  ${RED}Invalid choice. Stopping.${RESET}"
      exit 1
      ;;
  esac

  echo ""
  read -p "  Enter base href (e.g. /admin/, leave blank for /): " BASE_HREF
  BASE_HREF="${BASE_HREF:-/}"

  echo ""
  echo -e "  ${DIM}Environment : ${WHITE}$ENVIRONMENT${RESET}"
  echo -e "  ${DIM}Base href   : ${WHITE}$BASE_HREF${RESET}"
  echo -e "  ${DIM}Server      : ${WHITE}$SSH_HOST${RESET}"
  echo ""
  read -p "  Confirm? [y/N]: " CONFIRM

  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "  ${YELLOW}Cancelled.${RESET}"
    exit 0
  fi

  REMOTE_FOLDER="${BASE_HREF#/}"
  REMOTE_FOLDER="${REMOTE_FOLDER%/}"
  BACKUP_NAME="${REMOTE_FOLDER}_${DATE}"

  # ── Show steps header ──
  echo ""
  echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
  print_step "1" "Validating server folder..."; print_pending
  print_step "2" "Building for $ENVIRONMENT..."; print_pending
  print_step "3" "Uploading build..."; print_pending
  print_step "4" "Backing up old build..."; print_pending
  print_step "5" "Activating new build..."; print_pending
  echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
  echo ""
}

validate_remote_folder() {

  print_step "1" "Validating server folder..."
  ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
    "[[ -d '${REMOTE_PARENT}/${REMOTE_FOLDER}' ]]" 2>/dev/null

  if [[ $? -eq 0 ]]; then
    print_ok
    FOLDER_EXISTS=true
  else
    print_fail
    echo ""
    echo -e "  ${YELLOW}⚠  Folder '$REMOTE_FOLDER' not found on server!${RESET}"
    echo -e "  ${DIM}   First time deploy — will be created at:${RESET}"
    echo -e "  ${WHITE}   ${REMOTE_PARENT}/${REMOTE_FOLDER}${RESET}"
    echo ""
    read -p "  Continue anyway? [y/N]: " CONTINUE

    if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
      echo -e "  ${YELLOW}Cancelled.${RESET}"
      exit 0
    fi

    FOLDER_EXISTS=false
  fi
}

build_project() {
  print_step "2" "Building for $ENVIRONMENT..."

# used for project building in the same directory as the script
#   cd "$(dirname "$0")"

	[[ -z $PROJECT_DIR ]] && { echo "PROJECT_DIR is not set in deploy.config"; exit 1; }
	cd "$PROJECT_DIR" || { echo "Cannot find project directory: $PROJECT_DIR"; exit 1; }

  [[ -d "dist" ]] && rm -rf dist/
  [[ -d ".angular" ]] && rm -rf .angular/

  ng build --configuration="$ENVIRONMENT" --base-href="$BASE_HREF" > /tmp/ng_build.log 2>&1

  if [[ $? -ne 0 ]]; then
    print_fail
    echo ""
    cat /tmp/ng_build.log
    print_fail_box
    exit 1
  fi

  print_ok
}

backup_and_upload() {
  # ── Upload ──
  print_step "3" "Uploading build..."

  ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
    "rm -rf '${REMOTE_PARENT}/${REMOTE_FOLDER}_temp' && mkdir -p '${REMOTE_PARENT}/${REMOTE_FOLDER}_temp'" 2>/dev/null || { print_fail; print_fail_box; exit 1; }

  scp -P "$SSH_PORT" -r "$LOCAL_BUILD/." \
    "$SSH_USER@$SSH_HOST:${REMOTE_PARENT}/${REMOTE_FOLDER}_temp/" || { print_fail; print_fail_box; exit 1; }
#/>dev/null 2>&1

#   if [[ $? -ne 0 ]]; then
#     print_fail
#     print_fail_box
#     exit 1
#   fi
  print_ok

  # ── Backup ──
  print_step "4" "Backing up old build..."

  if [[ "$FOLDER_EXISTS" == true ]]; then
    ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
        "mv '${REMOTE_PARENT}/${REMOTE_FOLDER}' '${REMOTE_PARENT}/${BACKUP_NAME}'" 2>/dev/null ||  { print_fail; print_fail_box; exit 1; }

    # if [[ $? -ne 0 ]]; then
    #   print_fail
    #   print_fail_box
    #   exit 1
    # fi
    print_ok
  else
    echo -e "${DIM}skipped${RESET}"
  fi

  # ── Activate ──
  print_step "5" "Activating new build..."

  ssh -p "$SSH_PORT" "$SSH_USER@$SSH_HOST" \
      "mv '${REMOTE_PARENT}/${REMOTE_FOLDER}_temp' '${REMOTE_PARENT}/${REMOTE_FOLDER}'" 2>/dev/null ||  { print_fail; print_fail_box; exit 1; }

#   if [[ $? -ne 0 ]]; then
#     print_fail
#     print_fail_box
#     exit 1
#   fi
  print_ok

  print_success_box
  echo -e "  ${DIM}Deployed : ${WHITE}$REMOTE_FOLDER${RESET}"
  echo -e "  ${DIM}Backup   : ${WHITE}$BACKUP_NAME${RESET}"
  echo -e "  ${DIM}Server   : ${WHITE}$SSH_HOST${RESET}"
  echo ""
}

# ── Routes ──
case "$1" in
  deploy)
    eval $(ssh-agent -s) > /dev/null
    ssh-add "$SSH_KEY"
    trap 'ssh-agent -k > /dev/null 2>&1' EXIT

    select_options
    validate_remote_folder
    build_project
    backup_and_upload
    ;;
  rollback)
    echo "rollback coming soon"
    ;;
  config)
    echo "config coming soon"
    ;;
  *)
    echo -e "  Usage: ./deploy.sh ${CYAN}[deploy | rollback | config]${RESET}"
    ;;
esac

# ── Kill SSH Agent ──
# ssh-agent -k > /dev/null // handled at top
