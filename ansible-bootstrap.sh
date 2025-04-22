#!/usr/bin/env bash

set -euo pipefail

# ─── Configurable Variables ──────────────────────────────────────────────
ANSIBLE_REPO_URL="https://github.com/yourname/ansible-setup.git"
CLONE_DIR="$HOME/ansible-setup"
PLAYBOOK_PATH="playbooks/desktop-setup.yml"
REQUIREMENTS_FILE="requirements.yml"
ROLES_DIR="roles"

# ─── Styled Terminal Output ──────────────────────────────────────────────
info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $1"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# ─── Step 1: Ensure Ansible is Installed ─────────────────────────────────
install_ansible() {
  if command -v pacman &>/dev/null; then
    info "Installing Ansible via pacman..."
    sudo pacman -Sy --noconfirm ansible
  elif command -v yay &>/dev/null; then
    info "Installing Ansible via yay..."
    yay -Sy --noconfirm ansible
  else
    error "Neither pacman nor yay found. Please install Ansible manually."
    exit 1
  fi
}

if ! command -v ansible &>/dev/null; then
  info "Ansible not found. Installing..."
  install_ansible
  success "Ansible installed successfully."
else
  success "Ansible is already installed."
fi

# ─── Step 2: Clone or Update Ansible Repo ────────────────────────────────
if [ ! -d "$CLONE_DIR" ]; then
  info "Cloning Ansible setup repo..."
  git clone "$ANSIBLE_REPO_URL" "$CLONE_DIR"
  success "Repo cloned to $CLONE_DIR"
else
  info "Ansible setup repo already exists. Pulling latest..."
  git -C "$CLONE_DIR" pull
  success "Repo updated."
fi

cd "$CLONE_DIR"

# ─── Step 3: Install Galaxy Roles ────────────────────────────────────────
if [ -f "$REQUIREMENTS_FILE" ]; then
  info "Installing Ansible Galaxy roles..."
  ansible-galaxy install -r "$REQUIREMENTS_FILE" -p "$ROLES_DIR"
  success "Galaxy roles installed."
else
  warn "No $REQUIREMENTS_FILE found. Skipping role install."
fi

# ─── Step 4: Run the Playbook Locally ────────────────────────────────────
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
