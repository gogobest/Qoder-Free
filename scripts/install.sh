#!/usr/bin/env bash
# ==============================================================================
# Qoder-Free: One-Line Installer & Quick Launcher for Linux & macOS
# Repository: https://github.com/VoDaiLocz/Qoder-Free
# ==============================================================================

set -e

REPO="VoDaiLocz/Qoder-Free"
APP_NAME="QoderResetTool"
BIN_NAME="qoder-reset"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════════════════════════╗"
    echo "  ║             🔒 QODER-FREE INSTALLER 🔒                ║"
    echo "  ║   Privacy & Machine ID Management Tool for Qoder     ║"
    echo "  ╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    echo "Usage: ./install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cli              Run Qoder-Free in CLI mode immediately after install"
    echo "  --reset            Execute 1-Click reset immediately"
    echo "  --no-chat-history  Reset without preserving chat history"
    echo "  --uninstall        Remove installed Qoder-Free files and shortcuts"
    echo "  --help, -h         Show this help message"
    echo ""
}

detect_platform() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "$OS" in
        Linux*)
            PLATFORM="linux"
            ASSET_NAME="qoder-reset-tool-linux.tar.gz"
            ;;
        Darwin*)
            PLATFORM="macos"
            ASSET_NAME="qoder-reset-tool-macos.tar.gz"
            ;;
        *)
            log_error "Unsupported Operating System: $OS"
            exit 1
            ;;
    esac

    log_info "Detected platform: $PLATFORM ($ARCH)"
}

check_dependencies() {
    if command -v curl >/dev/null 2>&1; then
        HTTP_CLIENT="curl"
    elif command -v wget >/dev/null 2>&1; then
        HTTP_CLIENT="wget"
    else
        log_error "Neither 'curl' nor 'wget' was found. Please install curl or wget."
        exit 1
    fi

    if ! command -v tar >/dev/null 2>&1; then
        log_error "'tar' command not found. Please install tar."
        exit 1
    fi
}

download_file() {
    local url="$1"
    local output="$2"
    if [ "$HTTP_CLIENT" = "curl" ]; then
        curl -fsSL "$url" -o "$output"
    else
        wget -q "$url" -O "$output"
    fi
}

uninstall_qoder_free() {
    log_info "Uninstalling Qoder-Free..."
    rm -rf "$HOME/.local/share/qoder-free"
    rm -f "$HOME/.local/bin/$BIN_NAME"
    rm -f "$HOME/.local/share/applications/qoder-free.desktop"
    rm -f "/usr/local/bin/$BIN_NAME" 2>/dev/null || true
    log_success "Qoder-Free has been successfully uninstalled."
    exit 0
}

install_qoder_free() {
    local install_dir="$HOME/.local/share/qoder-free"
    local bin_dir="$HOME/.local/bin"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    mkdir -p "$install_dir" "$bin_dir"

    log_info "Fetching latest release information from GitHub..."
    local download_url="https://github.com/$REPO/releases/latest/download/$ASSET_NAME"
    local archive_path="$tmp_dir/$ASSET_NAME"

    log_info "Downloading package from: $download_url"
    if ! download_file "$download_url" "$archive_path"; then
        log_warning "Could not download prebuilt release asset ($ASSET_NAME)."
        log_info "Attempting to clone/pull source repository as fallback..."
        
        if command -v git >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
            if [ -d "$install_dir/.git" ]; then
                git -C "$install_dir" pull --quiet
            else
                git clone --depth 1 "https://github.com/$REPO.git" "$install_dir"
            fi
            
            # Create wrapper script
            cat << 'EOF' > "$bin_dir/$BIN_NAME"
#!/usr/bin/env bash
python3 "$HOME/.local/share/qoder-free/qoder_reset_gui.py" "$@"
EOF
            chmod +x "$bin_dir/$BIN_NAME"
            log_success "Source installation completed!"
        else
            log_error "Failed to download release asset and git/python3 is not available."
            rm -rf "$tmp_dir"
            exit 1
        fi
    else
        log_info "Extracting package..."
        tar -xzf "$archive_path" -C "$install_dir"

        local executable="$install_dir/$APP_NAME"
        if [ ! -f "$executable" ]; then
            # Check nested directories
            local found_exe
            found_exe="$(find "$install_dir" -type f -name "$APP_NAME" | head -n 1)"
            if [ -n "$found_exe" ]; then
                executable="$found_exe"
            fi
        fi

        if [ -f "$executable" ]; then
            chmod +x "$executable"
            ln -sf "$executable" "$bin_dir/$BIN_NAME"
        else
            # Try python source if included in tar
            if [ -f "$install_dir/qoder_reset_gui.py" ]; then
                cat << 'EOF' > "$bin_dir/$BIN_NAME"
#!/usr/bin/env bash
python3 "$HOME/.local/share/qoder-free/qoder_reset_gui.py" "$@"
EOF
                chmod +x "$bin_dir/$BIN_NAME"
            else
                log_error "Executable '$APP_NAME' not found in extracted files."
                rm -rf "$tmp_dir"
                exit 1
            fi
        fi
        log_success "Binary installation completed!"
    fi

    rm -rf "$tmp_dir"

    # Create desktop shortcut on Linux if applicable
    if [ "$PLATFORM" = "linux" ] && [ -d "$HOME/.local/share/applications" ]; then
        cat << EOF > "$HOME/.local/share/applications/qoder-free.desktop"
[Desktop Entry]
Name=Qoder Reset Tool
Comment=Privacy & Identity Reset Tool for Qoder
Exec=$bin_dir/$BIN_NAME
Icon=security-high
Terminal=false
Type=Application
Categories=Development;Utility;Security;
EOF
        chmod +x "$HOME/.local/share/applications/qoder-free.desktop"
    fi

    # Check PATH
    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        log_warning "$bin_dir is not currently in your PATH."
        log_info "Add it to your shell config (~/.bashrc or ~/.zshrc):"
        echo -e "${BOLD}    export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    fi

    log_success "Installed command: ${BOLD}$BIN_NAME${NC}"
}

# Main entry point
main() {
    print_banner
    
    ACTION="install"
    CLI_MODE=false
    RESET_MODE=false
    PRESERVE_CHAT=true

    while [ $# -gt 0 ]; do
        case "$1" in
            --cli)
                CLI_MODE=true
                shift
                ;;
            --reset)
                RESET_MODE=true
                CLI_MODE=true
                shift
                ;;
            --no-chat-history)
                PRESERVE_CHAT=false
                shift
                ;;
            --uninstall)
                ACTION="uninstall"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_warning "Unknown option: $1"
                shift
                ;;
        esac
    done

    if [ "$ACTION" = "uninstall" ]; then
        uninstall_qoder_free
    fi

    check_dependencies
    detect_platform
    install_qoder_free

    if [ "$RESET_MODE" = true ]; then
        log_info "Executing 1-Click Reset now..."
        if [ "$PRESERVE_CHAT" = true ]; then
            "$HOME/.local/bin/$BIN_NAME" --reset --preserve-chat
        else
            "$HOME/.local/bin/$BIN_NAME" --reset --no-preserve-chat
        fi
    elif [ "$CLI_MODE" = true ]; then
        "$HOME/.local/bin/$BIN_NAME" --status
    else
        log_info "You can launch Qoder-Free anytime with: ${BOLD}$BIN_NAME${NC}"
    fi
}

main "$@"
