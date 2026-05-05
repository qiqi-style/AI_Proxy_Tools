# 🤖 AI Proxy Tools - 聚合管理运维套件

[![GitHub license](https://img.shields.io/github/license/qiqi-style/AI_Proxy_Tools)](https://github.com/qiqi-style/AI_Proxy_Tools/blob/main/LICENSE)
[![Bash Shell](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Platform-Docker-2496ED.svg)](https://www.docker.com/)

**AI Proxy Tools** 是一个集成化、自动化的 AI 服务运维部署脚本套件。本项目专为服务器上的 AI 基础设施管理而设计，致力于提供极其丝滑的**一键安装、自动化更新、数据安全备份、以及 Nginx 智能反向代理配置**体验。

---

## 🌟 支持的核心 AI 项目

本套件目前无缝集成了以下三个强大的开源 AI 项目管理：

1. 🚀 **[new-api](https://github.com/QuantumNous/new-api)** - 强大的 OpenAI 兼容 API 分发与计费管理系统。
2. 🛡️ **[cli-proxy](https://github.com/router-for-me/CLIProxyAPI)** - Claude 代理系统 (CPA 反代)。
3. 🖼️ **[chatgpt2api](https://github.com/basketikun/chatgpt2api)** - ChatGPT 接口转换与多模态图像生成服务。

---

## ✨ 核心特性

- 🛡️ **安全隔离与标准化部署**：所有服务统一自动部署于系统的 `/app` 目录下，保证环境整洁与数据挂载安全。
- 🔄 **全自动 Nginx 智能引擎**：
  - 支持“四重降级容灾” Nginx 路径探测（利用 `nginx -t` 与 `nginx -V`），跨平台兼容度极高。
  - 自动识别现有配置的域名、端口和证书，支持一键回车保留旧配置。
  - 自动为 `nginx.conf` 注入 `include conf.d` 逻辑。
  - 配置写入后自动在后台执行 `nginx -t` 语法体检，通过后才进行无感重载（Reload），彻底告别改错配置导致整个网站崩溃。
- 📦 **开箱即用的 Docker 管理**：自动识别容器状态，一键更新并拉取最新镜像。
- 💾 **无痛数据备份**：更新服务前自动打包项目数据至 `/app/backup` 目录，防止意外数据丢失。
- 🌐 **内外网链路连通性自检**：实时嗅探本地端口与 Nginx 实际配置的路由，直观展示项目的内外网健康状态。

---

## 🛠️ 包含的脚本功能清单

| 脚本名称 | 功能描述 |
| --- | --- |
| `start.sh` | **主控制台入口**。负责基础环境检测（强制拦截无 Docker/Nginx 或非 Root 的运行），并统一调度其他脚本模块。 |
| `install_docker.sh` | **部署与卸载模块**。负责将本地项目架构映射至全局 `/app` 目录，并管理容器的启动与彻底销毁清理。 |
| `update_docker.sh` | **更新与状态监控模块**。一键获取最新 GitHub 版本，备份数据并重启容器；同时全景展示当前服务的内外网连通性。 |
| `nginx_conf_copy.sh` | **Nginx 部署专家**。交互式配置公网域名、监听端口、SSL 证书。支持动态更新配置和安全彻底删除，全程自动化语法自检。 |

---

## 🚀 快速上手教程

### 1. 准备环境
由于脚本涉及到 Docker 容器的启动和系统级 Nginx 配置的自动化读写，**请确保您的服务器已安装 `Docker` 和 `Nginx`**。

### 2. 一键极速安装 (推荐)
为了追求极致的运维体验，我们为您提供了一键部署指令。只需在终端执行以下任意一条即可完成安装，并**自动生成全局快捷启动命令**：

**通过 cURL 安装**：
```bash
curl -sL https://raw.githubusercontent.com/qiqi-style/AI_Proxy_Tools/main/install.sh | sudo bash
```

**通过 Wget 安装**：
```bash
wget -qO- https://raw.githubusercontent.com/qiqi-style/AI_Proxy_Tools/main/install.sh | sudo bash
```

🎉 **安装成功后，无论您身处服务器的哪个目录，随时输入 `aitool` 即可一键唤出控制台！**

---

### 3. 备用方案：手动克隆
如果您的服务器因为网络原因无法访问 GitHub 的 raw 服务，可以选择手动拉取：
```bash
git clone https://github.com/qiqi-style/AI_Proxy_Tools.git
cd AI_Proxy_Tools
sudo ./start.sh
```

进入主菜单后，您可以按照数字键盘指引：
- 输入 `1` 进入【安装与卸载管理】完成服务首次启动。
- 输入 `3` 进入【Nginx 反代配置】为刚安装的服务绑定您的公网域名、端口并配置 SSL 证书。

---

## 🔒 权限说明与安全建议
- **必须使用 root / sudo 执行**：因为脚本会自动构建全局 `/app` 工作区，并实时改写 `/etc/nginx` 文件。主脚本内部已做好防误删拦截与提权校验（非 sudo 运行将直接报错阻断）。
- **Nginx 报错自检**：如果在配置域名后由于各种原因（例如 SSL 证书绝对路径填写错误）导致 Nginx 语法异常，脚本的安全模块会**强制拦截**服务重载操作，并向您打印错误日志。只需修正输入后再次提交即可，无需担心现有服务中断。

---

## 🙋‍♂️ 关于作者与反馈
- **Author**: [qiqi-style](https://github.com/qiqi-style)
- 欢迎提 Issue 或 Pull Request！如果这个工具能够帮助到你，请给我一个 ⭐️ Star！
