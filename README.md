# OpenCloud (OCIS) for Home Assistant

Run a fully functional **OpenCloud Infinite Scale** instance on your Home Assistant, with support for **Hybrid Storage** (NAS/NFS) and Reverse Proxies (Pangolin, Nginx, Traefik).

## Features

* 🚀 **Performance:** Runs locally on your HA instance.
* 💾 **Hybrid Storage:** Keeps metadata on fast internal storage (SSD) and large files on your NAS/NFS share.
* 🔒 **Proxy Ready:** Optimized for Reverse Proxies (handles SSL termination correctly).
* 🛠 **Auto-Config:** Automatically configures URLs and fixes permissions on startup.

## Installation

1.  Add this repository to your Home Assistant Add-on Store:
    `https://github.com/YOUR_GITHUB_USERNAME/ha-opencloud-addon`
2.  Install the **OpenCloud (OCIS)** add-on.
3.  Go to the **Configuration** tab.

## Configuration

### 1. External URL (`oc_url`)
Enter the full public domain where your cloud will be reachable.
* Example: `https://cloud.my-domain.com`
* **Important:** Do not add a trailing slash `/`.

### 2. Data Path (`data_path`)
The path to your external storage (NAS).
* In Home Assistant, mount your NAS under Settings -> System -> Storage -> Network Storage.
* Example: `/share/MyNAS/CloudData`
* **Note:** The add-on will create a `blobs` folder in this directory.

### 3. Admin Password (`admin_password`)
Set the initial password for the `admin` user.

## Reverse Proxy Setup (Pangolin / Traefik / Nginx)

This add-on runs internally on **HTTP Port 9200**.

* **Scheme:** HTTP (not HTTPS internally)
* **Port:** 9200
* **Websockets:** Enable Websocket support in your proxy.
* **Trust:** The add-on is configured to trust all internal proxies (`0.0.0.0/0`) to prevent 400 Bad Request errors.
