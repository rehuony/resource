#!/usr/bin/env bash

# opengfw_installer.sh
# Author: rehuony
# Description: Scripts for installing sing-box server agents
# GitHub: https://github.com/rehuony/resource

# Enable the following shell options:
# -E: Ensure that ERR trap is also valid in function, subshell, and command replacements
# -e: When any command exits in a non-zero state, exit the script immediately
# -u: When using undefined variables, the script will report an error and exit
# -o pipefail: When any command in the pipeline fails, the entire pipeline returns to a failed state
set -Eeuo pipefail

# Setting up temporary working directory when script runs
trap remove_temp_directory EXIT

remove_temp_directory() {
  if [[ -n "${TEMPDIRECTORY:-}" && -e "${TEMPDIRECTORY}" ]]; then
    [[ "$(pwd)" =~ ^"${TEMPDIRECTORY}" ]] && popd &>/dev/null
    rm -rf "${TEMPDIRECTORY}"
  fi
}

TEMPDIRECTORY=$(mktemp -dt rehuony_directory_XXXXXX 2>/dev/null) || {
  printf "\e[38;2;215;0;0mError: failed to create temporary directory\e[0m\n"
  exit 1
}

pushd "${TEMPDIRECTORY}" &>/dev/null || {
  printf "\e[38;2;215;0;0mError: failed to pushd temporary directory\e[0m\n"
  exit 1
}

# Check whether the execution user is root
check_permission() {
  printf "\e[2mCurrent user is: ${USER}\e[0m\n"

  if [[ "${EUID}" != 0 ]]; then
    printf "\e[38;2;215;0;0mError: please run the script with root\e[0m\n"
    exit 1
  fi
}

# Check the environment of the current script
check_environment() {
  [[ -f "/etc/os-release" ]] && source /etc/os-release

  os_name=$(echo -ne "${NAME}" | awk '{print tolower($1)}')
  os_type=$(echo -ne "$(uname -s)" | awk '{print tolower($1)}')

  case "${os_name}" in
    arch)
      os_arch=$(uname -m)
      package_suffix=".pkg.tar.zst"
      package_manager="pacman -S --noconfirm"
      package_installer="pacman -U --noconfirm"
      ;;
    openwrt)
      os_arch=$(uname -m)
      package_suffix=".ipk"
      package_manager="opkg install"
      package_installer="opkg install"
      ;;
    ubuntu | debian)
      os_arch=$(dpkg --print-architecture)
      package_suffix=".deb"
      package_manager="apt install -y"
      package_installer="dpkg -i"
      ;;
    red | centos | fedora)
      os_arch=$(uname -m)
      package_suffix=".rpm"
      package_manager="dnf install -y"
      package_installer="rpm -i"
      ;;
    *)
      printf "\e[38;2;215;0;0mError: unsupported system for ${os_name}\e[0m\n"
      exit 1
      ;;
  esac

  printf "\e[2mCurrent system is: ${os_arch}_${os_name}_${os_type}\e[0m\n"
}

# Check whether the instructions used in the current script exist
check_dependencies() {
  local command_dependency package_dependency

  command_dependency=('curl' 'openssl' 'sed' 'grep' 'awk' 'mktemp' 'systemctl' 'adduser')
  package_dependency=('curl' 'openssl' 'sed' 'grep' 'gawk' 'coreutils' 'systemd' 'passwd')

  if [[ ${#command_dependency[@]} == 0 ]]; then
    return 0
  fi

  printf "\e[2mChecking command dependencies now ...\e[0m\n"

  for index in "${!command_dependency[@]}"; do
    printf "\e[4C\e[2m${command_dependency[index]} - "

    if type -t "${command_dependency[index]}" &>/dev/null; then
      printf "installed\e[0m\n"
    else
      printf "not installed\e[0m\n"
      printf "\e[8C\e[2m${package_manager} ${package_dependency[index]} ... "

      if sh -c "${package_manager} ${package_dependency[index]}" &>/dev/null; then
        printf "done\e[0m\n"
      else
        printf "error\e[0m\n"
        printf "\e[38;2;215;0;0mError: please run the command manually\e[0m\n"
        exit 1
      fi
    fi
  done
}

# Load external script resources
source_external_scripts() {
  local script_file external_script_links command_dependency package_dependency

  command_dependency=()
  package_dependency=()
  external_script_links=(
    'https://raw.githubusercontent.com/rehuony/resource/refs/heads/main/shellscript/library/message.lib.sh'
    'https://raw.githubusercontent.com/rehuony/resource/refs/heads/main/shellscript/library/utility.lib.sh'
  )

  if [[ ${#external_script_links[@]} == 0 ]]; then
    return 0
  fi

  printf "\e[2mLoading external scripts now ...\e[0m\n"

  for link in "${external_script_links[@]}"; do
    printf "\e[4C\e[2mloading ${link} - "

    script_file=$(mktemp -p "${TEMPDIRECTORY}" -t script_XXXXXX.sh 2>/dev/null) || {
      printf "error\e[0m\n"
      printf "\e[38;2;215;0;0mError: failed to create temporary file\e[0m\n"
      exit 1
    }

    curl -fsSL "${link}" -o "${script_file}" 2>/dev/null || {
      printf "error\e[0m\n"
      printf "\e[38;2;215;0;0mError: failed to download external script\e[0m\n"
      exit 1
    }

    source "${script_file}"

    for index in "${!lib_command_dependency[@]}"; do
      local is_exist="false"

      for cmd in "${command_dependency[@]}"; do
        if [[ "${cmd}" == "${lib_command_dependency[index]}" ]]; then
          is_exist="true"
          break
        fi
      done

      if [[ "${is_exist}" == "false" ]]; then
        command_dependency+=("${lib_command_dependency[index]}")
        package_dependency+=("${lib_package_dependency[index]}")
      fi
    done

    printf "done\e[0m\n"
  done

  if [[ ${#command_dependency[@]} == 0 ]]; then
    return 0
  fi

  printf "\e[2mInstalling external command dependencies ...\e[0m\n"

  for index in "${!command_dependency[@]}"; do
    printf "\e[4C\e[2m${command_dependency[index]} - "

    if type -t "${command_dependency[index]}" &>/dev/null; then
      printf "installed\e[0m\n"
    else
      printf "not installed\e[0m\n"
      printf "\e[8C\e[2m${package_manager} ${package_dependency[index]} ... "

      if sh -c "${package_manager} ${package_dependency[index]}" &>/dev/null; then
        printf "done\e[0m\n"
      else
        printf "error\e[0m\n"
        printf "\e[38;2;215;0;0mError: please run the command manually\e[0m\n"
        exit 1
      fi
    fi
  done
}

# Check whether the execution user is root
check_permission
# Check the environment of the current script
check_environment
# Check whether the instructions used in the current script exist
check_dependencies
# Source external script resources
source_external_scripts

# NOTE: Define global variables
declare user_ip
declare user_uuid
declare user_name
declare user_email
declare user_domain
declare user_password
declare cloudflare_token
declare global_config_path='/etc/letsencrypt/cloudfalre.ini'

declare certificate_path
declare certificate_key_path

# NOTE: Loading the configuration file
generate_global_config() {
  cat <<EOF
user_uuid=${user_uuid}
user_name=${user_name}
user_email=${user_email}
user_domain=${user_domain}
user_password=${user_password}
dns_cloudflare_api_token=${cloudflare_token}
EOF
}

load_global_config() {
  user_ip=$(get_global_ip)

  if [[ -f "${global_config_path}" ]]; then
    show_info "loading data from configuration: ${global_config_path}\n"

    user_uuid=$(load_ini_config 'user_uuid' "${global_config_path}")
    user_name=$(load_ini_config 'user_name' "${global_config_path}")
    user_email=$(load_ini_config 'user_email' "${global_config_path}")
    user_domain=$(load_ini_config 'user_domain' "${global_config_path}")
    user_password=$(load_ini_config 'user_password' "${global_config_path}")
    cloudflare_token=$(load_ini_config 'dns_cloudflare_api_token' "${global_config_path}")

    if [[ -z "${user_uuid}" || -z "${user_name}" || -z "${user_email}" || -z "${user_domain}" || -z "${user_password}" || -z "${cloudflare_token}" ]]; then
      show_error "there is an error in the configuration file, please repair the configuration file: ${global_config_path}\n"
      return 1
    fi
  else
    show_info "please input your personal information as prompted\n"

    user_uuid=$(
      get_input_until_success "please input your uuid: " \
        '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' \
        "please type uuid in the following format: $(generate_random_uuid)"
    )
    user_name=$(get_input_until_success "please input your name: ")
    user_email=$(get_input_until_success "please input your email: ")
    user_domain=$(get_input_until_success "please input your domain: ")
    user_password=$(
      get_input_until_success "please input your password: " \
        '^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d!@#$%^&*()_+\-=\[\]{};:"\\|,.<>\/?]{8,}$' \
        "password must be at least 8 characters, contain letters and numbers: $(generate_random_password)"
    )
    cloudflare_token=$(get_input_until_success "please input your cloudflare token: ")

    install_content_with_comment 600 "root:root" "$(generate_global_config)" "${global_config_path}" true
  fi

  certificate_path="/etc/letsencrypt/live/${user_domain}/fullchain.pem"
  certificate_key_path="/etc/letsencrypt/live/${user_domain}/privkey.pem"
}

# NOTE: Install certbot and apply for a certificate for user's domain
install_certbot_binary() {
  show_info "checking the status of certbot - "
  type -t certbot &>/dev/null && {
    show_text "installed\n"
    return 0
  }
  show_text "not installed\n"

  show_info "executing command ${package_manager} certbot python3-certbot-dns-cloudflare\n"
  if sh -c "${package_manager} certbot python3-certbot-dns-cloudflare" &>/dev/null; then
    show_success "installed certbot python3-certbot-dns-cloudflare\n"
    return 0
  else
    show_error "please run command manually: ${package_manager} certbot python3-certbot-dns-cloudflare\n"
    return 1
  fi
}

apply_certificate() {
  show_info "checking whether /etc/letsencrypt/live/${user_domain} exist\n"
  [[ -e "/etc/letsencrypt/live/${user_domain}" ]] && {
    show_warn "/etc/letsencrypt/live/${user_domain} is exist\n"
    return 0
  }
  show_info "/etc/letsencrypt/live/${user_domain} not exist\n"

  show_info "applying certificate for ${user_domain}: certbot certonly --dns-cloudflare --email ${user_email} --dns-cloudflare-credentials ${global_config_path} -d ${user_domain}\n"
  certbot certonly --dns-cloudflare --email "${user_email}" --dns-cloudflare-credentials "${global_config_path}" -d "${user_domain}" &>/dev/null <<<'Y' || {
    show_error "please run command manually: certbot certonly --dns-cloudflare --email ${user_email} --dns-cloudflare-credentials ${global_config_path} -d ${user_domain}\n"
    return 1
  }
  show_success "successfully applyed and saved at /etc/letsencrypt/live/${user_domain}\n"
}

# NOTE: Install nginx and modify default config
generate_nginx_conf() {
  cat <<EOF
user                 nginx;
pid                  /run/nginx.pid;
worker_processes     auto;
worker_rlimit_nofile 65535;

# Load modules
include              /etc/nginx/modules-enabled/*.conf;

events {
    multi_accept       on;
    worker_connections 65535;
}

http {
    charset                utf-8;
    sendfile               on;
    tcp_nopush             on;
    tcp_nodelay            on;
    server_tokens          off;
    log_not_found          off;
    types_hash_max_size    2048;
    types_hash_bucket_size 64;
    client_max_body_size   16M;

    # MIME
    include                mime.types;
    default_type           application/octet-stream;

    # Logging
    access_log             off;
    error_log              /dev/null;

    # SSL
    ssl_session_timeout    1d;
    ssl_session_cache      shared:SSL:10m;
    ssl_session_tickets    off;

    # diffie-hellman parameter for DHE ciphersuites
    ssl_dhparam            /etc/nginx/dhparam.pem;

    # Mozilla Intermediate configuration
    ssl_protocols          TLSv1.2 TLSv1.3;
    ssl_ciphers            ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

    # OCSP Stapling
    ssl_stapling           on;
    ssl_stapling_verify    on;
    resolver               1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 valid=60s;
    resolver_timeout       2s;

    # Load configs
    include                /etc/nginx/conf.d/*.conf;
    include                /etc/nginx/sites-enabled/*;
}
EOF
}

generate_domain_conf() {
  cat <<EOF
server {
    listen              443 ssl http2;
    listen              [::]:443 ssl http2;
    server_name         ${user_domain};
    root                /var/www/${user_domain}/public;

    # SSL
    ssl_certificate     ${certificate_path};
    ssl_certificate_key ${certificate_key_path};

    # security
    include             nginxconfig.io/security.conf;

    # logging
    access_log          /var/log/nginx/access.log combined buffer=512k flush=1m;
    error_log           /var/log/nginx/error.log warn;

    # additional config
    include             nginxconfig.io/general.conf;
}

# HTTP redirect
server {
    listen      80;
    listen      [::]:80;
    server_name ${user_domain};
    return      301 https://${user_domain}\$request_uri;
}
EOF
}

generate_security_conf() {
  cat <<EOF
# security headers
add_header X-XSS-Protection          "1; mode=block" always;
add_header X-Content-Type-Options    "nosniff" always;
add_header Referrer-Policy           "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy   "default-src 'self' http: https: ws: wss: data: blob: 'unsafe-inline'; frame-ancestors 'self';" always;
add_header Permissions-Policy        "interest-cohort=()" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# . files
location ~ /\.(?!well-known) {
    deny all;
}
EOF
}

generate_general_conf() {
  cat <<EOF
# favicon.ico
location = /favicon.ico {
    log_not_found off;
}

# robots.txt
location = /robots.txt {
    log_not_found off;
}

# assets, media
location ~* \.(?:css(\.map)?|js(\.map)?|jpe?g|png|gif|ico|cur|heic|webp|tiff?|mp3|m4a|aac|ogg|midi?|wav|mp4|mov|webm|mpe?g|avi|ogv|flv|wmv)$ {
    expires 7d;
}

# svg, fonts
location ~* \.(?:svgz?|ttf|ttc|otf|eot|woff2?)$ {
    add_header Access-Control-Allow-Origin "*";
    expires    7d;
}

# gzip
gzip            on;
gzip_vary       on;
gzip_proxied    any;
gzip_comp_level 6;
gzip_types      text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;
EOF
}

generate_nginxconfig_href() {
  cat <<EOF
https://www.digitalocean.com/community/tools/nginx?domains.0.server.redirectSubdomains=false&domains.0.https.certType=custom&domains.0.https.sslCertificate=%2Fetc%2Fletsencrypt%2Flive%2Fexample.com%2Ffullchain.pem&domains.0.https.sslCertificateKey=%2Fetc%2Fletsencrypt%2Flive%2Fexample.com%2Fprivkey.pem&domains.0.php.php=false&domains.0.routing.index=index.html&domains.0.routing.fallbackPhp=false&global.https.ocspOpenDns=false&global.security.referrerPolicy=strict-origin-when-cross-origin&global.nginx.user=nginx&global.app.lang=zhCN
EOF
}

generate_index_html() {
  cat <<EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Welcome to NGINX</title>
    <style>
      body {
        margin: 0;
        background-color: #0f172a;
        font-family: system-ui, sans-serif;
        color: #e2e8f0;
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: center;
        min-height: 100vh;
        text-align: center;
      }
      h1 {
        font-size: 3rem;
        margin-bottom: 0.5rem;
      }
      p {
        color: #94a3b8;
        font-size: 1.1rem;
      }
      .badge {
        margin-top: 1rem;
        display: inline-block;
        padding: 0.4rem 1rem;
        background-color: #1e293b;
        border-radius: 9999px;
        font-size: 0.9rem;
        color: #38bdf8;
      }
      a {
        color: #38bdf8;
        text-decoration: none;
      }
    </style>
  </head>
  <body>
    <h1>Welcome to NGINX</h1>
    <p>
      If you see this page, the NGINX web server is successfully installed and working.
    </p>
    <div class="badge">Server Ready</div>
    <p><a href="https://nginx.org" target="_blank">Learn more at nginx.org</a></p>
  </body>
</html>
EOF
}

install_nginx_binary() {
  show_info "checking the status of nginx - "
  type -t nginx &>/dev/null && {
    show_text "installed\n"
    return 0
  }
  show_text "not installed\n"

  show_info "executing command ${package_manager} nginx\n"
  if sh -c "${package_manager} nginx" &>/dev/null; then
    show_success "successfully installed nginx\n"
    return 0
  else
    show_error "please run command manually: ${package_manager} nginx\n"
    return 1
  fi
}

modify_nginx_default() {
  local user_id group_id nginx_name

  # Get the name of the old nginx user
  nginx_name=$(awk -F: '$1~/(nginx|www-data)/ {print $1; exit}' /etc/passwd)
  # Get old uid and gid by old name
  user_id=$(awk -F: -v name="$nginx_name" '$1==name {print $3; exit}' /etc/passwd)
  group_id=$(awk -F: -v name="$nginx_name" '$1==name {print $4; exit}' /etc/passwd)

  if [[ -z "$nginx_name" || -z "$user_id" || -z "$group_id" ]]; then
    show_error "nginx or www-data user not found in /etc/passwd\n"
    return 1
  fi

  show_info "stopping nginx.service\n"
  systemctl stop nginx.service &>/dev/null || {
    show_error "failed to stop nginx.service\n"
    return 1
  }
  show_success "successfully closed nginx.service\n"

  show_info "deleting old user named ${nginx_name}\n"
  deluser --remove-all-files ${nginx_name} &>/dev/null || {
    show_error "delete ${nginx_name} error\n"
    return 1
  }
  show_success "successfully deleted user named ${nginx_name}\n"

  show_info "creating new group named nginx\n"
  addgroup --system --gid "${group_id}" nginx &>/dev/null || {
    show_error "failed to create group named nginx\n"
    return 1
  }
  show_success "successfully created group named nginx\n"

  show_info "creating new user named nginx\n"
  adduser --system --uid "${user_id}" --gid "${group_id}" --home /var/www --shell /usr/sbin/nologin nginx &>/dev/null || {
    show_error "failed to create user named nginx\n"
    return 1
  }
  show_success "successfully created user named nginx\n"

  remove_content_with_comment "/var/www/html"
  remove_content_with_comment "/etc/nginx/sites-enabled"
  remove_content_with_comment "/etc/nginx/sites-available"

  show_info "checking for diffie-hellman key at /etc/nginx/dhparam.pem\n"
  if [[ -f "/etc/nginx/dhparam.pem" ]]; then
    if openssl dhparam -check -in /etc/nginx/dhparam.pem &>/dev/null; then
      show_success "valid diffie-hellman key already exists at /etc/nginx/dhparam.pem\n"
    else
      show_warn "existing /etc/nginx/dhparam.pem is invalid, regenerating...\n"
      if openssl dhparam -out /etc/nginx/dhparam.pem 2048 &>/dev/null; then
        show_success "successfully regenerated diffie-hellman key\n"
      else
        show_error "failed to regenerate diffie-hellman key\n"
        return 1
      fi
    fi
  else
    show_info "diffie-hellman key not found, generating...\n"
    if openssl dhparam -out /etc/nginx/dhparam.pem 2048 &>/dev/null; then
      show_success "successfully generated diffie-hellman key\n"
    else
      show_error "failed to generate diffie-hellman key\n"
      return 1
    fi
  fi

  install_content_with_comment 644 "root:root" "$(generate_nginx_conf)" "/etc/nginx/nginx.conf" true
  install_content_with_comment 644 "root:root" "$(generate_domain_conf)" "/etc/nginx/sites-available/${user_domain}.conf" true
  install_content_with_comment 644 "root:root" "$(generate_security_conf)" "/etc/nginx/nginxconfig.io/security.conf" true
  install_content_with_comment 644 "root:root" "$(generate_general_conf)" "/etc/nginx/nginxconfig.io/general.conf" true
  install_content_with_comment 644 "root:root" "$(generate_nginxconfig_href)" "/etc/nginx/nginxconfig.txt" true
  install_content_with_comment 644 "root:root" "$(generate_index_html)" "/var/www/${user_domain}/public/index.html" true

  show_info "creating directory /etc/nginx/sites-enabled\n"
  install -dm755 "/etc/nginx/sites-enabled"

  show_info "creating link /etc/nginx/sites-available/${user_domain}.conf to /etc/nginx/sites-enabled/${user_domain}.conf\n"
  ln -s "/etc/nginx/sites-available/${user_domain}.conf" "/etc/nginx/sites-enabled/${user_domain}.conf" &>/dev/null

  show_info "starting nginx.service\n"
  systemctl daemon-reload && systemctl start nginx.service &>/dev/null || {
    show_error "failed to start nginx.service\n"
    return 1
  }
  show_success "successfully started nginx.service\n"
}

# NOTE: Install sing-box and set up agent services
genetate_sing-box_config() {
  cat <<EOF
{
  "log": {
    "level": "warn",
    "output": "sing-box.log",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "trojan",
      "listen": "::",
      "listen_port": 8080,
      "users": [
        {
          "name": "${user_name}",
          "password": "${user_password}"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${user_domain}",
        "alpn": ["h3", "h2", "http/1.1"],
        "certificate_path": "${certificate_path}",
        "key_path": "${certificate_key_path}"
      },
      "multiplex": {
        "enabled": true
      }
    },
    {
      "type": "hysteria2",
      "listen": "::",
      "listen_port": 8053,
      "users": [
        {
          "name": "${user_name}",
          "password": "${user_password}"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${user_domain}",
        "alpn": ["h3", "h2", "http/1.1"],
        "certificate_path": "${certificate_path}",
        "key_path": "${certificate_key_path}"
      }
    }
  ]
}
EOF
}

install_sing-box_binary() {
  local latest_release latest_version package_name download_url

  show_info "checking the status of sing-box ... "
  type -t sing-box &>/dev/null && {
    show_text "installed\n"
    return 0
  }
  show_text "not installed\n"

  show_info "fetching the latest sing-box repository information\n"
  if ! latest_release=$(curl -fsSL https://api.github.com/repos/SagerNet/sing-box/releases/latest 2>/dev/null); then
    show_error "failed to fetch sing-box repository information\n"
    return 1
  fi
  show_success "successfully fetched sing-box repository information\n"

  show_info "parsing the latest sing-box version information\n"
  if [[ "$(echo "${latest_release}" | grep tag_name | wc -l)" == 0 ]]; then
    show_error "fetched sing-box repository information is invalid\n"
    return 1
  fi
  latest_version=$(echo "$latest_release" | grep tag_name | head -n 1 | awk -F: '{print $2}' | sed 's/[", v]//g')
  show_success "parsed latest sing-box version: ${latest_version}\n"

  show_info "constructing the url of the sing-box package installer\n"
  package_name="sing-box_${latest_version}_${os_type}_${os_arch}${package_suffix}"
  download_url="https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/${package_name}"
  show_success "target download URL: ${download_url}\n"

  show_info "downloading the latest sing-box package installer\n"
  curl -fsSL "${download_url}" -o "${package_name}" 2>/dev/null || {
    show_error "failed to download sing-box package installer\n"
    return 1
  }
  show_success "successfully saved package to ${TEMPDIRECTORY}/${package_name}\n"

  show_info "executing command: ${package_installer} ${package_name}\n"
  sh -c "${package_installer} ${package_name}" &>/dev/null || {
    show_error "failed to install sing-box\n"
    return 1
  }
  show_success "successfully installed sing-box\n"

  show_info "adding system services for sing-box and start services\n"
  systemctl enable sing-box &>/dev/null && systemctl start sing-box &>/dev/null || {
    show_error "failed to add system services for sing-box\n"
    return 1
  }
  show_success "successfully added system services for sing-box\n"
}

modify_sing-box_default() {
  install_content_with_comment 644 "root:root" "$(genetate_sing-box_config)" "/etc/sing-box/config.json" true
  # Restart sing-box system service
  show_info "restarting sing-box system service\n"
  systemctl start sing-box &>/dev/null || {
    show_error "failed to restart system services for sing-box\n"
    return 1
  }
  show_success "successfully restarted system services for sing-box\n"
}

generate_mihomo_subscription() {
  local yaml_name mihomo_dir

  yaml_name="mihomo.yaml"
  mihomo_dir="/var/www/${user_domain}/public/download"

  install_content_with_comment 644 "root:root" "" "${mihomo_dir}/${yaml_name}" true

  show_info "downloading mihomo configuration file template\n"
  curl -fsSL 'https://raw.githubusercontent.com/rehuony/resource/refs/heads/main/template/config/mihomo.yaml' -o "${mihomo_dir}/${yaml_name}" 2>/dev/null || {
    show_error "failed to download mihomo configuration file\n"
    return 1
  }
  show_success "successfully download mihomo configuration file\n"

  sed -Ei "s/<<user_ip>>/${user_ip}/Ig" "${mihomo_dir}/${yaml_name}"
  sed -Ei "s/<<user_domain>>/${user_domain}/Ig" "${mihomo_dir}/${yaml_name}"
  sed -Ei "s/<<user_password>>/${user_password}/Ig" "${mihomo_dir}/${yaml_name}"
}

# NOTE: Main program entry
# Loading the configuration file
load_global_config
# Install certbot
install_certbot_binary
# Apply for a certificate for the domain name
apply_certificate
# Install nginx
install_nginx_binary
# Modify the default configuration of nginx
modify_nginx_default
# Install sing-box
install_sing-box_binary
# Modify the default configuration file of sing-box
modify_sing-box_default
# Generate mihomo subscription file
generate_mihomo_subscription
