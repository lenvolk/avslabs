# AVS Nested Labs Network Configuration

## IP Addressing Scheme

The network addressing scheme in the AVS nested labs follows a specific pattern based on the group number and lab number parameters. The IP addressing is dynamically constructed using the group and lab numbers passed to the script.

### Network Pattern

For an example with **GroupNumber=3** and **lab=1**:

- The first octet is always **10**
- The second octet is the **group number** (3)
- The third octet is the **lab number** (1)
- The fourth octet varies depending on the specific resource

### Primary Network (10.3.1.0/24)

This creates a unique `10.3.1.0/24` subnet for each nested lab with the following assignments:

| Device | IP Address | Configuration Variable |
|--------|------------|------------------------|
| Gateway | 10.3.1.1 | `$VMGateway = "10.${groupNumber}.${labNumber}.1"` |
| VCSA | 10.3.1.2 | `$VCSAIPAddress = "10.${groupNumber}.${LabNumber}.2"` |
| ESXi Host | 10.3.1.3 | `"esxi-${groupNumber}-${labNumber}" = "10.${groupNumber}.${labNumber}.3"` |
| NFS Server | 10.3.1.7 | `$NFSVMIPAddress = "10.${groupNumber}.${labNumber}.7"` |
| Router VM | 10.3.1.8 | `$RouterVMIPAddress = "10.${groupNumber}.${labNumber}.8"` |

### Secondary Network for Workloads (10.3.11.128/27)

Additionally, for workload VMs, a secondary network is created:

- Network: `10.3.11.128/27` aka `255.255.255.224` (note how the third octet becomes `"1${labNumber}"` = `"11"`)
- Gateway: `10.3.11.129`
- Workload VMs: `10.3.11.130`, `10.3.11.131`, etc.

This design ensures that each lab environment has its own isolated network, with the group and lab number parameters serving as unique identifiers for the IP addressing scheme.

## DNS Configuration

In the lab setup, the DNS IP address is set to **1.1.1.1**, which is Cloudflare's public DNS service. This is configured in the `labdeploy.ps1` script:

```powershell
$VMDNS = "1.1.1.1"
```

This DNS IP address (1.1.1.1) is used for all VMs in the nested lab environment, including:
- The ESXi hosts
- The vCenter Server Appliance (VCSA)
- The NFS server
- The router VM
- The workload VMs

It's also visible in the `router-userdata.yaml` file where network configuration is set. Using a public DNS provider like Cloudflare simplifies the lab setup, as it doesn't require deploying and managing a separate DNS server within the nested lab environment.

## Network Diagram

```mermaid
graph TB
    subgraph "NSX-T Tier-1 Router"
        T1["T1 Gateway\n(10.3.1.1)"]
    end
    
    subgraph "Primary Network 10.3.1.0/24"
        VCSA["vCenter Server\n(10.3.1.2)"]
        ESXi["ESXi Host\n(10.3.1.3)"]
        NFS["NFS Server\n(10.3.1.7)"]
        Router["Router VM\n(10.3.1.8)"]
        
        T1 --- VCSA
        T1 --- ESXi
        T1 --- NFS
        T1 --- Router
    end
    
    subgraph "Secondary Network 10.3.11.128/27"
        WGW["Workload Gateway\n(10.3.11.129)"]
        VM1["Workload VM 1\n(10.3.11.130)"]
        VM2["Workload VM 2\n(10.3.11.131)"]
        
        Router --- WGW
        WGW --- VM1
        WGW --- VM2
    end
    
    subgraph "External Resources"
        DNS["Cloudflare DNS\n(1.1.1.1)"]
    end
    
    T1 -.-> DNS
    Router -.-> DNS
    
    classDef network fill:#f9f9f9,stroke:#333,stroke-width:1px;
    classDef router fill:#e6a064,stroke:#333,stroke-width:2px,color:black;
    classDef server fill:#a8c9df,stroke:#333,stroke-width:1px,color:black;
    classDef dns fill:#b5d396,stroke:#333,stroke-width:1px,color:black;
    
    class T1,Router,WGW router;
    class VCSA,ESXi,NFS,VM1,VM2 server;
    class DNS dns;
```

The diagram above illustrates the network topology of a lab deployment for Group 3, Lab 1. It shows how the primary and secondary networks are connected through the router VM, and how DNS connectivity is provided to all components.