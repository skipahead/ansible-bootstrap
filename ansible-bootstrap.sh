#!/usr/bin/env bash
set -euo pipefail

# ─── Styled Terminal Output ──────────────────────────────────────────────
info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $1"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# ─── Prompt for GitHub Credentials ───────────────────────────────────────
read -rp "GitHub Username: " GITHUB_USER
read -rsp "GitHub Token (paste from password manager): " GITHUB_TOKEN
echo ""

# ─── Config Variables ────────────────────────────────────────────────────
ANSIBLE_REPO_URL="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/ansible-setup.git"
CLONE_DIR="$HOME/ansible-setup"
PLAYBOOK_PATH="playbooks/desktop-setup.yml"
REQUIREMENTS_FILE="requirements.yml"
RESOLVED_REQUIREMENTS_FILE=".requirements.resolved.yml"
ROLES_DIR="roles"

# ─── Step 1: Ensure Ansible is Installed ─────────────────────────────────
if ! command -v ansible &>/dev/null; then
  info "Ansible not found. Installing..."
  if command -v pacman &>/dev/null; then
    sudo pacman -Sy --noconfirm ansible
  elif command -v yay &>/dev/null; then
    yay -Sy --noconfirm ansible
  else
    error "Neither pacman nor yay found. Please install Ansible manually."
    exit 1
  fi
  success "Ansible installed successfully."
else
  success "Ansible is already installed."
fi

# ─── Step 2: Clone or Update Ansible Repo ────────────────────────────────
if [ ! -d "$CLONE_DIR" ]; then
  info "Cloning private repo from GitHub..."
  git clone "$ANSIBLE_REPO_URL" "$CLONE_DIR"
  success "Repo cloned to $CLONE_DIR"
else
  info "Repo already exists. Pulling latest..."
  git -C "$CLONE_DIR" pull
  success "Repo updated."
fi

cd "$CLONE_DIR"

# ─── Step 3: Resolve and Install Galaxy Roles ────────────────────────────
if [ -f "$REQUIREMENTS_FILE" ]; then
  info "Resolving Galaxy role URLs using provided credentials..."
  sed \
    -e "s|\${GITHUB_USER}|$GITHUB_USER|g" \
    -e "s|\${GITHUB_TOKEN}|$GITHUB_TOKEN|g" \
    "$REQUIREMENTS_FILE" > "$RESOLVED_REQUIREMENTS_FILE"

  info "Installing roles from resolved file..."
  ansible-galaxy install -r "$RESOLVED_REQUIREMENTS_FILE" -p "$ROLES_DIR"
  success "Galaxy roles installed."
else
  warn "No $REQUIREMENTS_FILE found — skipping role install."
fi

# ─── Step 4: Run the Ansible Playbook ────────────────────────────────────
if [ -f "$PLAYBOOK_PATH" ]; then
  info "Running playbook: $PLAYBOOK_PATH"
  ANSIBLE_FORCE_COLOR=1 \
  ANSIBLE_NOCOWS=1 \
  ansible-playbook -i localhost, -c local "$PLAYBOOK_PATH"
  success "Playbook completed successfully."
else
  error "Playbook not found at: $PLAYBOOK_PATH"
  exit 1
fi

# ─── Step 5: Cleanup ─────────────────────────────────────────────────────
info "Cleaning up sensitive data..."
unset GITHUB_USER
unset GITHUB_TOKEN

if [ -f "$RESOLVED_REQUIREMENTS_FILE" ]; then
  rm -f "$RESOLVED_REQUIREMENTS_FILE"
  success "Temporary resolved requirements file removed."
fi

success "All done. Credentials cleared from memory."
