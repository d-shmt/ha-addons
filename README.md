# OpenCloud for Home Assistant (OCIS)

[![GitHub Release](https://img.shields.io/github/release/opencloud-eu/opencloud.svg)](https://github.com/opencloud-eu/opencloud/releases)
[![HassOS Support](https://img.shields.io/badge/home%20assistant-addon-blue.svg)](https://www.home-assistant.io/addons/)

Run a high-performance **OpenCloud Infinite Scale (OCIS)** instance directly on Home Assistant.

This add-on is optimized for **Hybrid Storage** and **Reverse Proxies** (like Pangolin, Nginx, or Traefik). It combines the speed of your local SSD for database operations with the massive capacity of your NAS for file storage.

## 🌟 Key Features

* **🚀 Hybrid Storage Architecture:**
* **🔒 Proxy Ready:** Pre-configured to work behind Reverse Proxies (Pangolin, Traefik, Nginx Proxy Manager).
* **🛠 Zero-Config Init:** Automatically initializes the server and admin user on first start.

---

## 📦 Installation

### Prerequisites
1.  **Home Assistant OS** (or Supervised).
2.  **Network Storage (NAS):** You must mount your NAS share in Home Assistant via **Settings** -> **System** -> **Storage** -> **Network Storage**.
    * *Recommendation:* Use **NFS** for better permission handling.

### Step-by-Step
1.  Add this repository to your Home Assistant Add-on Store:
    ```text
    https://github.com/d-shmt/ha-addons
    ```
2.  Install the **OpenCloud** add-on.
3.  Go to the **Configuration** tab.

---

## ⚙️ Configuration

### Basic Options

| Option | Description | Example |
| :--- | :--- | :--- |
| `oc_url` | **Required.** The public URL where your cloud is reachable. Do not add a trailing slash. | `https://cloud.your-domain.com` |
| `data_path` | **Required.** The path to your mounted NAS share in Home Assistant. | `/share/OpenCloud` |
| `admin_password` | The initial password for the `admin` user. | `ChangeMe123!` |
