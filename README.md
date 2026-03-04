# Cloudflare WARP Site-to-Site Connector

This project provides a Docker-based solution for establishing site-to-site connectivity using Cloudflare WARP connectors. It enables secure routing of traffic between different private networks through Cloudflare's Zero Trust infrastructure.

## Quick Start

Get up and running in 5 minutes using pre-built images:

```bash
# 1. Clone repository
git clone --recurse-submodules https://github.com/genzj/warp-to-warp-container.git
cd warp-to-warp-container

# 2. Configure Cloudflare credentials
cp mdm.xml.example mdm.xml
# Edit mdm.xml with your Cloudflare WARP connector credentials
chmod 600 mdm.xml

# 3. Create Docker network (adjust subnet/name if needed)
docker network create --driver bridge --attachable --internal --subnet=192.168.71.0/24 vm7-warp

# 4. Start services
docker compose up -d

# 5. Verify
docker compose logs -f warp-connector
```

That's it! The containers will pull pre-built images from GitHub Container Registry and start automatically.

**Note**: If you need different network settings, edit `docker-compose.yml` to change the network name (`vm7-warp`) or IP address (`192.168.71.200`) before step 4.

## Overview

The solution consists of two main components:

1. **WARP Connector Container**: Runs Cloudflare WARP client in a Docker container to establish secure tunnels
2. **Docker Events Handler (dehandler)**: Automatically configures network routes for containers that need to communicate through the WARP tunnel

## Prerequisites

- Docker and Docker Compose installed
- Cloudflare Zero Trust account with WARP Connector access
- Basic understanding of networking concepts (routing, subnets)
- Root/sudo access on the host system

## Cloudflare WARP Connector Setup

### 1. Create a Cloudflare Zero Trust Account

1. Sign up for Cloudflare Zero Trust at https://one.dash.cloudflare.com/
2. Navigate to **Settings** → **WARP Client**
3. Enable **Gateway with WARP** for your organization

### 2. Create a WARP Connector

Follow the official Cloudflare documentation:

- **Main Guide**: https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/deployment/mdm-deployment/
- **Connector Setup**: https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/private-net/warp-connector/site-to-site/
- **Service Token Creation**: https://developers.cloudflare.com/cloudflare-one/tutorials/warp-on-headless-linux/#1-create-a-service-token

General Steps (check CF official Docs for details)

1. In Cloudflare Zero Trust dashboard, go to **Networks** → **Tunnels**
2. Create a new **WARP Connector**
3. Download the MDM configuration file (`mdm.xml`) or use the example below
4. Create service token and update the MDM accordingly to include it

### 3. Configure MDM File

The `mdm.xml` file contains your WARP connector configuration. Place it in the project root directory.

Example structure (with sensitive data removed):

```xml
<dict>
    <key>organization</key>
    <string>your-org-name</string>
    <key>auth_client_id</key>
    <string>xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.access</string>
    <key>auth_client_secret</key>
    <string>xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</string>
    <key>warp_connector_token</key>
    <string>your-warp-connector-token-here</string>
</dict>
```

You can use the provided `mdm.xml.example` file as a template.

**Important**: Never commit your actual `mdm.xml` file to version control. Add it to `.gitignore`.

### 4. Configure Private Networks

In the Cloudflare Zero Trust dashboard:

1. Go to **Networks** → **Routes**
2. Add the private network ranges that should be accessible through this connector
3. Example: `10.0.1.0/24`, `10.0.2.0/24`

## Installation

The Quick Start section above covers the basic installation. For more details:

### Using Pre-built Images (Recommended)

The default `docker-compose.yml` uses pre-built images from GitHub Container Registry. Simply run:

```bash
docker compose up -d
```

Images are automatically pulled from `ghcr.io/genzj/warp-to-warp-container`.

### Building Images Locally (Development)

For development or customization, use the development compose file:

```bash
docker compose -f dev-docker-compose.yml up -d --build
```

This builds images locally from source code.

## Configuration

### Docker Compose Configuration

The main `docker-compose.yml` defines two services:

```yaml
services:
  warp-connector:
    # WARP connector with static IP on the routing network
    networks:
      vm7-warp:
        ipv4_address: 192.168.71.200 # Static IP for routing

  dehandler:
    # Monitors Docker events and configures routes automatically
    privileged: true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

### Configuring Application Containers

To route traffic from your application containers through the WARP connector, use Docker labels:

#### Example: Application with WARP Routing

```yaml
services:
  your-app:
    image: your-app:latest
    networks:
      - default
      - vm7-warp # Connect to WARP network
    cap_add:
      - NET_ADMIN # Required for route manipulation
    labels:
      # Configure routes via docker-events handler
      - "docker-events.route=add 10.0.1.0/24 via 192.168.71.200;add 10.0.2.0/24 via 192.168.71.200"
    deploy:
      labels:
        - shepherd.autodeploy=false # Optional: disable auto-updates

networks:
  vm7-warp:
    external: true
```

### Configuring Routes with Labels

The `dehandler` service automatically configures routes when containers start by reading the `docker-events.route` label.

#### Label Format

```yaml
labels:
  - "docker-events.route=<route-command-1>;<route-command-2>;<route-command-3>"
```

- Use semicolons (`;`) to separate multiple route commands
- Each command is executed as: `ip route <command>` inside the container's network namespace
- The WARP connector IP is typically `192.168.71.200` (adjust based on your configuration)

#### Common Examples

Route a single remote network:

```yaml
labels:
  - "docker-events.route=add 10.0.1.0/24 via 192.168.71.200"
```

Route multiple remote networks:

```yaml
labels:
  - "docker-events.route=add 10.0.1.0/24 via 192.168.71.200;add 10.0.2.0/24 via 192.168.71.200;add 10.0.0.0/8 via 192.168.71.200"
```

Change the default gateway to route all traffic through WARP:

```yaml
labels:
  - "docker-events.route=delete default;add default via 192.168.71.200"
```

**Advanced Configuration**: The docker-events handler supports additional labels for IP address configuration, policy routing rules, and host-level routes. See the [docker-events documentation](./docker-events/README.md) for details.

## Verification

### Check WARP Connection Status

```bash
# View WARP connector logs
docker compose logs -f warp-connector

# Check if WARP is connected
docker exec warp-connector warp-cli --accept-tos status
```

### Verify Routes in Application Container

```bash
# Get container name or ID
docker ps

# Check routes inside container using nsenter from the host
CONTAINER_PID=$(docker inspect --format '{{.State.Pid}}' <container-name>)
sudo nsenter -n -t $CONTAINER_PID ip route show

# Test connectivity to remote network using nsenter
sudo nsenter -n -t $CONTAINER_PID ping -c 3 10.0.1.1

# Or combine into one command
sudo nsenter -n -t $(docker inspect --format '{{.State.Pid}}' <container-name>) ip route show
```

### Troubleshooting

1. **WARP connector not connecting**:
   - Verify `mdm.xml` credentials are correct
   - Check Cloudflare Zero Trust dashboard for connector status
   - Review logs: `docker compose logs warp-connector`

2. **Routes not being applied**:
   - Ensure `dehandler` is running: `docker compose ps dehandler`
   - Check dehandler logs: `docker compose logs dehandler`
   - Verify container has `NET_ADMIN` capability
   - Confirm container is connected to `vm7-warp` network

3. **Cannot reach remote networks**:
   - Verify routes in Cloudflare Zero Trust dashboard
   - Check routes inside container using nsenter: `sudo nsenter -n -t $(docker inspect --format '{{.State.Pid}}' <container>) ip route`
   - Test connectivity from WARP container: `docker exec warp-connector ping <remote-ip>`
   - Verify firewall rules on both ends

4. **Permission errors**:
   - Ensure dehandler has `privileged: true` or appropriate capabilities
   - Check host system has `/proc` mounted correctly

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Docker Host                         │
│                                                         │
│  ┌──────────────┐         ┌─────────────────┐           │
│  │  Application │◄────────┤  vm7-warp       │           │
│  │  Container   │         │  Network        │           │
│  │              │         │  192.168.71.0/24│           │
│  └──────────────┘         └─────────────────┘           │
│         │                          │                    │
│         │ Routes via               │                    │
│         │ 192.168.71.200           │                    │
│         │                          │                    │
│         ▼                          ▼                    │
│  ┌─────────────────────────────────────┐                │
│  │     WARP Connector                  │                │
│  │     IP: 192.168.71.200              │                │
│  │                                     │                │
│  │  ┌──────────────────────────────┐  │                 │
│  │  │  Cloudflare WARP Client      │  │                 │
│  │  │  (warp-svc)                  │  │                 │
│  │  └──────────────────────────────┘  │                 │
│  └─────────────────────────────────────┘                │
│                    │                                    │
└────────────────────┼────────────────────────────────────┘
                     │
                     │ Encrypted Tunnel
                     ▼
         ┌───────────────────────┐
         │  Cloudflare Network   │
         │  Zero Trust Gateway   │
         └───────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  Remote Site          │
         │  10.0.1.0/24          │
         │  10.0.2.0/24          │
         └───────────────────────┘
```

## Advanced Configuration

### Multiple WARP Connectors

To connect to multiple sites, create additional WARP connector instances with different MDM files and network configurations.

### Custom Network Configuration

Customize network settings by modifying `docker-compose.yml`:

- WARP connector static IP: Change `ipv4_address` under `networks.vm7-warp` (default: 192.168.71.200)
- Network name: Update all references to `vm7-warp` throughout the compose file
- Subnet: Recreate the Docker network with a different `--subnet` value

### Manual Image Building (Development)

If you need to manually build images (for development or customization), you have two options:

#### Option 1: Use the Development Compose File

The `dev-docker-compose.yml` file is configured to build images locally:

```bash
docker compose -f dev-docker-compose.yml build
docker compose -f dev-docker-compose.yml up -d
```

#### Option 2: Build Images Manually

Build the images directly with Docker:

```bash
# Build the WARP connector image
docker build -t warpconnectordocker:latest .

# Build the docker-events handler image
docker build -t dehandler:latest ./docker-events

# Then use the development compose file
docker compose -f dev-docker-compose.yml up -d
```

**Note**: For production deployments, use the pre-built images from GitHub Container Registry with the standard `docker-compose.yml` file.

## Security Considerations

- Keep `mdm.xml` secure and never commit to version control
- Use restrictive file permissions: `chmod 600 mdm.xml`
- Regularly rotate WARP connector credentials
- Monitor Cloudflare Zero Trust logs for unauthorized access
- Use Cloudflare Access policies to restrict network access
- Consider using Docker secrets for sensitive configuration

## Maintenance

### Updating WARP Client

```bash
# Rebuild with latest WARP client
docker compose build --no-cache warp-connector
docker compose up -d warp-connector
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f warp-connector
docker compose logs -f dehandler
```

### Restarting Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart warp-connector
```

## References

- [Cloudflare WARP Connector Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/private-net/warp-connector/)
- [Cloudflare Zero Trust](https://developers.cloudflare.com/cloudflare-one/)
- [Docker Events Handler (dehandler)](./docker-events/README.md)
- [MDM Deployment Guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/deployment/mdm-deployment/)

## License

See LICENSE file for details.

## Contributing

Contributions are welcome! Please submit pull requests or open issues for bugs and feature requests.
